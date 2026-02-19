-- ============================================================
-- 02_2pc_transactions.sql — Two-Phase Commit (2PC)
-- Simula transferencia entre cuentas en nodos diferentes
-- Proyecto 2 SI3009 — Sección 4.1
--
-- NOTA TECNICA:
-- PREPARE TRANSACTION no puede ejecutarse con EXECUTE dinamico
-- dentro de PL/pgSQL. Por eso el nodo local opera con DML directo
-- y el nodo remoto usa dblink enviando el comando como string.
-- El nodo remoto apunta al mismo primary para simular un segundo
-- nodo (en produccion apuntaria a otra instancia PostgreSQL).
-- ============================================================

CREATE EXTENSION IF NOT EXISTS dblink;

-- ── FUNCIÓN COORDINADORA DEL 2PC ─────────────────────────────
CREATE OR REPLACE FUNCTION transferencia_2pc(
    p_cuenta_origen  UUID,
    p_cuenta_dest    UUID,
    p_monto          NUMERIC,
    p_tx_id          TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $func$
DECLARE
    v_tx_id        TEXT;        -- nombre del PREPARE TRANSACTION
    v_tx_uuid      UUID;        -- UUID real para transacciones_log
    v_saldo_origen NUMERIC;
    v_conn_destino TEXT;
    v_cmd_remoto   TEXT;
    v_ts_inicio    TIMESTAMPTZ;
BEGIN
    v_ts_inicio    := clock_timestamp();
    v_tx_uuid      := gen_random_uuid();
    v_tx_id        := COALESCE(
                        p_tx_id,
                        'tx_' || to_char(now(), 'YYYYMMDD_HH24MISS')
                               || '_' || substring(v_tx_uuid::text, 1, 8)
                      );
    -- En produccion: apuntaria a una segunda instancia PostgreSQL independiente
    -- Para el experimento: apunta al mismo primary simulando el nodo B
    v_conn_destino := 'host=pg-primary port=5432 dbname=banco_db user=banco_admin password=banco_pass';

    -- FASE 0: Validacion
    SELECT saldo INTO v_saldo_origen
    FROM cuentas WHERE cuenta_id = p_cuenta_origen FOR UPDATE;

    IF v_saldo_origen IS NULL THEN
        RAISE EXCEPTION 'Cuenta origen % no existe', p_cuenta_origen;
    END IF;
    IF v_saldo_origen < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente: disponible=%, requerido=%', v_saldo_origen, p_monto;
    END IF;

    -- FASE 1a: Operacion en nodo local (debito)
    UPDATE cuentas
    SET saldo = saldo - p_monto, updated_at = now()
    WHERE cuenta_id = p_cuenta_origen;

    INSERT INTO transacciones_log(
        tx_id, cuenta_origen, cuenta_dest,
        tipo_tx, monto, estado, nodo_origen
    )
    VALUES (
        v_tx_uuid, p_cuenta_origen, p_cuenta_dest,
        'transferencia', p_monto, 'pendiente', 'pg-primary'
    );

    -- FASE 1b: PREPARE en nodo remoto via dblink
    -- El comando se construye como string para poder incluir
    -- BEGIN y PREPARE TRANSACTION (no permitidos con EXECUTE dinamico)
    v_cmd_remoto :=
        'BEGIN' ||
        '; UPDATE cuentas SET saldo = saldo + ' || p_monto ||
        ', updated_at = now() WHERE cuenta_id = ' || quote_literal(p_cuenta_dest) ||
        '; INSERT INTO transacciones_log(tx_id, cuenta_origen, cuenta_dest, tipo_tx, monto, estado, nodo_origen)' ||
        ' VALUES (' || quote_literal(v_tx_uuid) || '::uuid, ' ||
        quote_literal(p_cuenta_origen) || ', ' ||
        quote_literal(p_cuenta_dest) || ', ' ||
        '''transferencia'', ' || p_monto || ', ''pendiente'', ''pg-nodo-b'')' ||
        '; PREPARE TRANSACTION ' || quote_literal(v_tx_id || '_remote');

    BEGIN
        PERFORM dblink_exec(v_conn_destino, v_cmd_remoto);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'FASE 1 fallo en nodo remoto: %', SQLERRM;
    END;

    -- FASE 2: COMMIT PREPARED en nodo remoto
    -- Si el coordinador cae aqui, la tx remota queda en estado incierto
    -- y debe resolverse manualmente via: COMMIT/ROLLBACK PREPARED
    BEGIN
        PERFORM dblink_exec(
            v_conn_destino,
            format('COMMIT PREPARED %L', v_tx_id || '_remote')
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'FASE 2 fallo — tx en estado incierto: %', v_tx_id;
        RAISE;
    END;

    -- Marcar como completada en nodo local
    UPDATE transacciones_log
    SET estado = 'completado', updated_at = now()
    WHERE tx_id = v_tx_uuid;

    RETURN jsonb_build_object(
        'tx_id',       v_tx_id,
        'tx_uuid',     v_tx_uuid,
        'estado',      'completado',
        'monto',       p_monto,
        'duracion_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - v_ts_inicio)
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'tx_id',  v_tx_id,
        'estado', 'fallido',
        'error',  SQLERRM
    );
END;
$func$;


-- ── VISTA: transacciones 2PC pendientes ──────────────────────
-- Si el coordinador cae entre PREPARE y COMMIT, estas quedan
-- bloqueadas indefinidamente hasta resolucion manual.
-- Ejecutar: SELECT * FROM v_prepared_transactions;
CREATE OR REPLACE VIEW v_prepared_transactions AS
SELECT
    gid          AS transaction_id,
    prepared     AS prepared_at,
    owner,
    database,
    EXTRACT(EPOCH FROM (now() - prepared)) AS segundos_pendiente
FROM pg_prepared_xacts
ORDER BY prepared DESC;


-- ============================================================
-- EXPERIMENTO A: Transferencia exitosa con 2PC
-- ============================================================

-- Crear cuentas de prueba
INSERT INTO clientes(nombre, email, pais)
VALUES
    ('Nodo A Corp', 'nodoa@test.com', 'CO'),
    ('Nodo B Corp', 'nodob@test.com', 'CO')
ON CONFLICT DO NOTHING;

INSERT INTO cuentas(cliente_id, tipo_cuenta, saldo, shard_key)
SELECT cliente_id, 'ahorros', 10000000.00, 0
FROM clientes
WHERE email IN ('nodoa@test.com', 'nodob@test.com')
ON CONFLICT DO NOTHING;

-- Ver UUIDs de las cuentas de prueba
SELECT cuenta_id, email, saldo
FROM cuentas
JOIN clientes USING(cliente_id)
WHERE email IN ('nodoa@test.com', 'nodob@test.com');

-- Ejecutar transferencia 2PC (reemplazar UUIDs con los del SELECT anterior)
-- SELECT transferencia_2pc(
--     '<uuid_cuenta_origen>'::uuid,
--     '<uuid_cuenta_dest>'::uuid,
--     500000.00
-- );

-- Verificar saldos (origen -500k, destino +500k)
-- SELECT email, saldo FROM cuentas
-- JOIN clientes USING(cliente_id)
-- WHERE email IN ('nodoa@test.com', 'nodob@test.com');

-- Ver registro en transacciones_log
-- SELECT tx_id, tipo_tx, monto, estado, nodo_origen, created_at
-- FROM transacciones_log
-- WHERE tipo_tx = 'transferencia'
-- ORDER BY created_at DESC LIMIT 5;


-- ============================================================
-- EXPERIMENTO B: Simular fallo del coordinador
-- Demuestra bloqueo de recursos en 2PC cuando el coordinador
-- cae despues del PREPARE pero antes del COMMIT
-- ============================================================

-- Ejecutar en psql interactivo:
-- BEGIN;
-- UPDATE cuentas SET saldo = saldo - 1000000
-- WHERE cuenta_id = '<uuid_cuenta>'::uuid;
-- PREPARE TRANSACTION 'experimento_fallo_coordinador';
--
-- En OTRA conexion, verificar que la tx esta bloqueada:
-- SELECT * FROM v_prepared_transactions;
-- Los recursos permanecen bloqueados hasta resolucion manual.
--
-- Resolucion manual (elegir una opcion):
-- COMMIT PREPARED 'experimento_fallo_coordinador';
-- ROLLBACK PREPARED 'experimento_fallo_coordinador';


-- ============================================================
-- EXPERIMENTO C: 2PC manual paso a paso con timing
-- Ejecutar en psql interactivo para documentar tiempos
-- ============================================================

-- \timing on
--
-- FASE 1: PREPARE (recursos quedan bloqueados desde aqui)
-- BEGIN;
-- UPDATE cuentas SET saldo = saldo - 1000000
-- WHERE cuenta_id = '<uuid_origen>'::uuid;
-- INSERT INTO transacciones_log(
--     tx_id, cuenta_origen, tipo_tx, monto, estado, nodo_origen
-- ) VALUES (
--     gen_random_uuid(), '<uuid_origen>'::uuid,
--     'transferencia', 1000000, 'pendiente', 'pg-primary'
-- );
-- PREPARE TRANSACTION 'manual_2pc_demo_001';
--
-- Ver estado intermedio (recursos bloqueados):
-- SELECT * FROM v_prepared_transactions;
--
-- FASE 2: COMMIT
-- COMMIT PREPARED 'manual_2pc_demo_001';
--
-- \timing off
