-- ============================================================
-- 01_cockroachdb_schema.sql — Schema bancario en CockroachDB
-- Compatible con PostgreSQL wire protocol
-- Proyecto 2 SI3009 — Sección 4.2
-- ============================================================

USE banco_db;

-- ── TABLAS BASE ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS clientes (
    cliente_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     STRING(120) NOT NULL,
    email      STRING(200) NOT NULL UNIQUE,
    pais       STRING(2)   NOT NULL DEFAULT 'CO',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    activo     BOOL        NOT NULL DEFAULT TRUE
);

-- Mismas columnas que PG excepto shard_key (no tiene sentido en CRDB,
-- que distribuye automáticamente). El generador de datos omite shard_key
-- para ambas BDs y en PG se llena con DEFAULT 0.
CREATE TABLE IF NOT EXISTS cuentas (
    cuenta_id  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID          NOT NULL REFERENCES clientes(cliente_id),
    tipo_cuenta STRING(20)   NOT NULL CHECK (tipo_cuenta IN ('ahorros', 'corriente', 'credito')),
    saldo      DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    moneda     STRING(3)     NOT NULL DEFAULT 'COP',
    created_at TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ   NOT NULL DEFAULT now(),
    activo     BOOL          NOT NULL DEFAULT TRUE,

    INDEX idx_cuentas_cliente (cliente_id)
);

-- ── TABLA PRINCIPAL: transacciones_log ───────────────────────
-- CRDB hace auto-sharding por rangos de PK automáticamente

CREATE TABLE IF NOT EXISTS transacciones_log (
    tx_id         UUID          NOT NULL DEFAULT gen_random_uuid(),
    cuenta_origen UUID          NOT NULL,
    cuenta_dest   UUID,
    tipo_tx       STRING(20)    NOT NULL CHECK (tipo_tx IN ('deposito','retiro','transferencia','pago')),
    monto         DECIMAL(18,2) NOT NULL,
    estado        STRING(15)    NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente','completado','fallido','revertido')),
    nodo_origen   STRING(20),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),

    PRIMARY KEY (tx_id),
    INDEX idx_tx_origen (cuenta_origen, created_at DESC),
    INDEX idx_tx_dest   (cuenta_dest,   created_at DESC),
    INDEX idx_tx_estado (estado,        created_at DESC)
);

-- ── PARTICIONAMIENTO EXPLÍCITO ────────────────────────────────
-- CRDB ya hace auto-sharding, pero esto fuerza distribución por semestres
-- y permite asignar preferencia de leaseholder por nodo (geodistribución simulada)

ALTER TABLE transacciones_log PARTITION BY RANGE (created_at) (
    PARTITION tx_2024_h1 VALUES FROM ('2024-01-01') TO ('2024-07-01'),
    PARTITION tx_2024_h2 VALUES FROM ('2024-07-01') TO ('2025-01-01'),
    PARTITION tx_2025    VALUES FROM ('2025-01-01') TO (MAXVALUE)
);

ALTER PARTITION tx_2024_h1 OF INDEX transacciones_log@primary
    CONFIGURE ZONE USING num_replicas = 3, lease_preferences = '[[+node=1]]';

ALTER PARTITION tx_2024_h2 OF INDEX transacciones_log@primary
    CONFIGURE ZONE USING num_replicas = 3, lease_preferences = '[[+node=2]]';

ALTER PARTITION tx_2025 OF INDEX transacciones_log@primary
    CONFIGURE ZONE USING num_replicas = 3, lease_preferences = '[[+node=3]]';

-- ── PROCEDIMIENTO: transferencia atómica ─────────────────────
-- En CRDB no hace falta 2PC manual — SSI (Serializable Snapshot Isolation)
-- garantiza atomicidad distributed nativa con un solo BEGIN/COMMIT

CREATE OR REPLACE PROCEDURE transferencia_atomica(
    p_origen  UUID,
    p_destino UUID,
    p_monto   DECIMAL
)
LANGUAGE SQL AS $$
    UPDATE cuentas
       SET saldo = saldo - p_monto, updated_at = now()
     WHERE cuenta_id = p_origen AND saldo >= p_monto;

    UPDATE cuentas
       SET saldo = saldo + p_monto, updated_at = now()
     WHERE cuenta_id = p_destino;

    INSERT INTO transacciones_log (cuenta_origen, cuenta_dest, tipo_tx, monto, estado)
    VALUES (p_origen, p_destino, 'transferencia', p_monto, 'completado');
$$;

-- ── CONSULTAS PARA EXPERIMENTOS ───────────────────────────────

-- Ver distribución de ranges (auto-sharding de CRDB):
-- SHOW RANGES FROM TABLE transacciones_log;
-- SHOW RANGES FROM DATABASE banco_db;

-- Ver leaseholders por range:
-- SELECT range_id, start_key, end_key, lease_holder, replicas
-- FROM [SHOW RANGES FROM TABLE transacciones_log WITH DETAILS];

-- EXPLAIN distribuido (equivalente al EXPLAIN ANALYZE de PG):
-- EXPLAIN (DISTSQL)
-- SELECT c.nombre, COUNT(t.tx_id), SUM(t.monto)
-- FROM transacciones_log t
-- JOIN cuentas cu ON cu.cuenta_id = t.cuenta_origen
-- JOIN clientes c  ON c.cliente_id = cu.cliente_id
-- WHERE t.created_at BETWEEN '2024-01-01' AND '2024-06-30'
--   AND t.tipo_tx = 'transferencia'
-- GROUP BY c.cliente_id, c.nombre
-- ORDER BY SUM(t.monto) DESC LIMIT 20;
