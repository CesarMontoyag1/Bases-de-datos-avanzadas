-- ============================================================
-- 01_schema.sql — Modelo de datos bancario con particionamiento
-- PostgreSQL 16 — Proyecto 2 SI3009
-- ============================================================

-- ── 1. TABLAS BASE ──────────────────────────────────────────

CREATE TABLE IF NOT EXISTS clientes (
    cliente_id    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre        VARCHAR(120) NOT NULL,
    email         VARCHAR(200) NOT NULL UNIQUE,
    pais          CHAR(2)      NOT NULL DEFAULT 'CO',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    activo        BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS cuentas (
    cuenta_id     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id    UUID         NOT NULL REFERENCES clientes(cliente_id),
    tipo_cuenta   VARCHAR(20)  NOT NULL CHECK (tipo_cuenta IN ('ahorros', 'corriente', 'credito')),
    saldo         NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    moneda        CHAR(3)      NOT NULL DEFAULT 'COP',
    shard_key     INT          NOT NULL DEFAULT 0,  -- routing manual entre nodos PG (0,1,2)
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),  -- requerido por transferencia_2pc()
    activo        BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ── 2. TABLA PARTICIONADA: transacciones_log ────────────────
-- Particionamiento por RANGO (fecha) — cubre req. 4.1

CREATE TABLE IF NOT EXISTS transacciones_log (
    tx_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    cuenta_origen UUID         NOT NULL,
    cuenta_dest   UUID,
    tipo_tx       VARCHAR(20)  NOT NULL CHECK (tipo_tx IN ('deposito','retiro','transferencia','pago')),
    monto         NUMERIC(18,2) NOT NULL,
    estado        VARCHAR(15)  NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente','completado','fallido','revertido')),
    nodo_origen   VARCHAR(20),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);

-- Particiones trimestrales 2024–2025
CREATE TABLE tx_log_2024_q1 PARTITION OF transacciones_log
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE tx_log_2024_q2 PARTITION OF transacciones_log
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
CREATE TABLE tx_log_2024_q3 PARTITION OF transacciones_log
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');
CREATE TABLE tx_log_2024_q4 PARTITION OF transacciones_log
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');
CREATE TABLE tx_log_2025_q1 PARTITION OF transacciones_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');
CREATE TABLE tx_log_2025_q2 PARTITION OF transacciones_log
    FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');

-- ── 3. TABLA PARTICIONADA POR HASH (cliente_id) ──────────────
-- Cubre req. de particionamiento por Hash

CREATE TABLE IF NOT EXISTS cuentas_shard (
    cuenta_id  UUID         NOT NULL DEFAULT gen_random_uuid(),
    cliente_id UUID         NOT NULL,
    saldo      NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
) PARTITION BY HASH (cliente_id);

CREATE TABLE cuentas_shard_0 PARTITION OF cuentas_shard FOR VALUES WITH (MODULUS 3, REMAINDER 0);
CREATE TABLE cuentas_shard_1 PARTITION OF cuentas_shard FOR VALUES WITH (MODULUS 3, REMAINDER 1);
CREATE TABLE cuentas_shard_2 PARTITION OF cuentas_shard FOR VALUES WITH (MODULUS 3, REMAINDER 2);

-- ── 4. TABLA PARTICIONADA POR LISTA (tipo de transacción) ────
-- Cubre req. de particionamiento por List

CREATE TABLE IF NOT EXISTS transacciones_tipo (
    tx_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    cuenta_id  UUID         NOT NULL,
    tipo_tx    VARCHAR(20)  NOT NULL,
    monto      NUMERIC(18,2) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
) PARTITION BY LIST (tipo_tx);

CREATE TABLE tx_tipo_deposito  PARTITION OF transacciones_tipo FOR VALUES IN ('deposito');
CREATE TABLE tx_tipo_retiro    PARTITION OF transacciones_tipo FOR VALUES IN ('retiro');
CREATE TABLE tx_tipo_transfer  PARTITION OF transacciones_tipo FOR VALUES IN ('transferencia');
CREATE TABLE tx_tipo_pago      PARTITION OF transacciones_tipo FOR VALUES IN ('pago');

-- ── 5. ÍNDICES ────────────────────────────────────────────────
CREATE INDEX idx_tx_cuenta_origen  ON transacciones_log (cuenta_origen, created_at DESC);
CREATE INDEX idx_tx_cuenta_dest    ON transacciones_log (cuenta_dest,   created_at DESC);
CREATE INDEX idx_tx_estado         ON transacciones_log (estado,        created_at DESC);
CREATE INDEX idx_cuentas_cliente   ON cuentas (cliente_id);
CREATE INDEX idx_cuentas_shard_key ON cuentas (shard_key);

-- ── 6. USUARIO REPLICADOR ─────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_pass';
    END IF;
END
$$;

-- ── 7. VISTAS PARA EXPERIMENTOS ───────────────────────────────
CREATE OR REPLACE VIEW v_resumen_particiones AS
SELECT
    schemaname,
    tablename AS particion,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS tamaño,
    (SELECT count(*) FROM pg_inherits
     WHERE inhrelid = (schemaname||'.'||tablename)::regclass) AS sub_particiones
FROM pg_tables
WHERE tablename LIKE 'tx_log_%'
   OR tablename LIKE 'tx_tipo_%'
   OR tablename LIKE 'cuentas_shard_%'
ORDER BY tablename;

COMMENT ON TABLE transacciones_log IS
    'Tabla maestra particionada por rango de fecha — experimento escalamiento horizontal';
