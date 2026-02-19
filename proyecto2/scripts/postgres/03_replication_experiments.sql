-- ============================================================
-- 03_replication_experiments.sql — Replicación y Failover
-- Proyecto 2 SI3009 — Sección 4.1
-- ============================================================

-- ── EXPERIMENTO A: Monitoreo de replicación ──────────────────
-- Ejecutar en el PRIMARY

-- Estado general de replicación
SELECT
    client_addr,
    usename,
    application_name,
    state,
    sync_state,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn))  AS sent_lag,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn)) AS write_lag,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn)) AS flush_lag,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS replay_lag,
    write_lag   AS write_lag_time,
    flush_lag   AS flush_lag_time,
    replay_lag  AS replay_lag_time
FROM pg_stat_replication
ORDER BY client_addr;


-- ── EXPERIMENTO B: Latencia sincrónica vs asincrónica ─────────
-- Medir tiempo de INSERT con diferentes synchronous_commit

-- Test 1: synchronous_commit = 'off' (asíncrono, más rápido)
SET synchronous_commit = 'off';
\timing on
INSERT INTO transacciones_log (cuenta_origen, tipo_tx, monto, nodo_origen)
VALUES (gen_random_uuid(), 'deposito', 1000.00, 'experimento-async');
\timing off

-- Test 2: synchronous_commit = 'on' (local WAL flush)
SET synchronous_commit = 'on';
\timing on
INSERT INTO transacciones_log (cuenta_origen, tipo_tx, monto, nodo_origen)
VALUES (gen_random_uuid(), 'deposito', 1000.00, 'experimento-sync-local');
\timing off

-- Test 3: synchronous_commit = 'remote_write' (réplica recibe pero no aplica)
-- Primero configurar en postgresql.conf: synchronous_standby_names = 'FIRST 1 (pg-replica1)'
SET synchronous_commit = 'remote_write';
\timing on
INSERT INTO transacciones_log (cuenta_origen, tipo_tx, monto, nodo_origen)
VALUES (gen_random_uuid(), 'deposito', 1000.00, 'experimento-sync-remote-write');
\timing off

-- Test 4: synchronous_commit = 'remote_apply' (máxima consistencia)
SET synchronous_commit = 'remote_apply';
\timing on
INSERT INTO transacciones_log (cuenta_origen, tipo_tx, monto, nodo_origen)
VALUES (gen_random_uuid(), 'deposito', 1000.00, 'experimento-sync-remote-apply');
\timing off


-- ── EXPERIMENTO C: EXPLAIN en join distribuido ───────────────
-- Query que cruza dos particiones diferentes (Q1 y Q2 de 2024)
-- Este es el "join distribuido" más costoso en PG sin native sharding

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.nombre                              AS cliente,
    COUNT(t.tx_id)                        AS num_transacciones,
    SUM(t.monto)                          AS total_monto,
    AVG(t.monto)                          AS promedio_monto,
    MIN(t.created_at)                     AS primera_tx,
    MAX(t.created_at)                     AS ultima_tx
FROM transacciones_log t
JOIN cuentas cu ON cu.cuenta_id = t.cuenta_origen
JOIN clientes c  ON c.cliente_id = cu.cliente_id
WHERE t.created_at BETWEEN '2024-01-01' AND '2024-06-30'   -- cruza Q1 y Q2
  AND t.tipo_tx = 'transferencia'
  AND t.estado  = 'completado'
GROUP BY c.cliente_id, c.nombre
HAVING SUM(t.monto) > 5000
ORDER BY total_monto DESC
LIMIT 20;


-- ── EXPERIMENTO D: Failover manual ───────────────────────────
-- Pasos para promover pg-replica1 a Primary cuando pg-primary cae

-- 1. Verificar que la réplica esté al día (ejecutar en replica1):
/*
SELECT pg_is_in_recovery();                          -- debe ser TRUE
SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();
*/

-- 2. Simular caída del primary (desde Docker):
--    docker stop pg-primary

-- 3. Promover la réplica (ejecutar dentro del contenedor):
--    docker exec -it pg-replica1 bash
--    su postgres -c "pg_ctl promote -D /var/lib/postgresql/data"

-- 4. Verificar que ahora es primary:
/*
SELECT pg_is_in_recovery();   -- debe ser FALSE (ya es primary)
\conninfo
*/

-- 5. Reconectar replica2 al nuevo primary:
--    Editar /var/lib/postgresql/data/postgresql.auto.conf en replica2:
--    primary_conninfo = 'host=pg-replica1 port=5432 user=replicator password=repl_pass'
--    pg_ctl reload -D /var/lib/postgresql/data

-- ── EXPERIMENTO E: Detección de Split-Brain ───────────────────
-- Vista para monitorear cuántos primaries existen (debe ser exactamente 1)
CREATE OR REPLACE VIEW v_topology AS
SELECT
    inet_server_addr()    AS nodo_ip,
    pg_is_in_recovery()   AS es_replica,
    CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END AS rol,
    pg_postmaster_start_time() AS inicio,
    current_setting('synchronous_commit') AS sync_commit_mode;


-- ── EXPERIMENTO F: Carga con pgbench ─────────────────────────
-- Desde la terminal (NO desde psql):
/*
pgbench -i -s 50 -h localhost -p 5432 -U banco_admin banco_db
# -s 50 = ~500K filas (~100MB de datos de prueba)

# Test de latencia escritura (solo primario):
pgbench -c 10 -j 2 -T 60 -h localhost -p 5432 -U banco_admin banco_db

# Test de latencia lectura (réplica):
pgbench -c 10 -j 2 -T 60 -h localhost -p 5433 -U banco_admin banco_db --select-only

# Guardar resultados:
pgbench -c 10 -j 2 -T 60 -h localhost -p 5432 -U banco_admin banco_db 2>&1 | tee ../docs/pgbench_primary.txt
pgbench -c 10 -j 2 -T 60 -h localhost -p 5433 -U banco_admin banco_db --select-only 2>&1 | tee ../docs/pgbench_replica.txt
*/
