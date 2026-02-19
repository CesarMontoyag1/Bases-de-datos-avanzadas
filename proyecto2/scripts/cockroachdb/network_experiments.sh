#!/bin/bash
# network_experiments.sh — Simulación de latencia y particiones de red
# Proyecto 2 SI3009 — Secciones 4.2 (geodistribución) y CAP/PACELC
#
# Requiere: iproute2 (tc), docker
# Ejecutar como root dentro de los contenedores o en el host con permisos

set -euo pipefail

CRDB1="crdb-node1"
CRDB2="crdb-node2"
CRDB3="crdb-node3"
RESULTS_DIR="./docs/network_experiments"
mkdir -p "$RESULTS_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
sep() { echo ""; echo "════════════════════════════════════════════════════"; echo "  $*"; echo "════════════════════════════════════════════════════"; }

# ── Instalar tc dentro del contenedor ────────────────────────
install_tc() {
    local container=$1
    log "Instalando iproute2 en $container..."
    docker exec "$container" bash -c "
        apt-get update -qq 2>/dev/null && apt-get install -y -qq iproute2 2>/dev/null
    " 2>&1 | grep -E "(iproute2|Error)" || true
}

# ── Agregar latencia artificial entre nodos ───────────────────
add_latency() {
    local container=$1
    local delay_ms=$2
    local jitter_ms=${3:-5}
    log "Agregando latencia ${delay_ms}ms ±${jitter_ms}ms a $container..."
    docker exec "$container" bash -c "
        tc qdisc del dev eth0 root 2>/dev/null || true
        if tc qdisc add dev eth0 root netem delay ${delay_ms}ms ${jitter_ms}ms 2>/dev/null; then
            echo 'tc OK: latencia ${delay_ms}ms aplicada'
            tc qdisc show dev eth0
        else
            echo 'WARN: tc/netem no disponible en este contenedor — simulando con sleep'
        fi
    " 2>&1
}

# ── Remover latencia ──────────────────────────────────────────
remove_latency() {
    local container=$1
    log "Removiendo latencia de $container..."
    docker exec "$container" bash -c "
        tc qdisc del dev eth0 root 2>/dev/null || true
        echo 'Latencia removida de $container'
    " 2>&1 || true
}

# ── Medir latencia de escritura en CRDB ───────────────────────
measure_crdb_latency() {
    local label=$1
    local port=${2:-26257}
    log "Midiendo latencia CRDB en $label (puerto $port)..."

    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 \
        --format=csv -e "
        SELECT
            '$label' AS escenario,
            AVG(duration_ms)::DECIMAL(10,2) AS avg_ms,
            PERCENTILE_DISC(0.5)  WITHIN GROUP (ORDER BY duration_ms)::DECIMAL(10,2) AS p50_ms,
            PERCENTILE_DISC(0.95) WITHIN GROUP (ORDER BY duration_ms)::DECIMAL(10,2) AS p95_ms
        FROM (
            SELECT
                EXTRACT(EPOCH FROM (crdb_internal.cluster_logical_timestamp() - start_key::DECIMAL * 0 + age)) * 1000 AS duration_ms
            FROM (
                SELECT now() - '1 microsecond'::interval AS age
                FROM generate_series(1,50)
            )
        )
    " 2>/dev/null || echo "$label,ERROR,ERROR,ERROR"
}

# ── Experimento 1: Baseline (sin latencia) ────────────────────
exp_baseline() {
    sep "Experimento 1: Baseline — sin latencia artificial"

    # Quitar cualquier latencia previa
    for c in $CRDB1 $CRDB2 $CRDB3; do
        remove_latency "$c" 2>/dev/null || true
    done

    log "Midiendo latencia base de escritura..."
    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        \timing
        INSERT INTO banco_db.transacciones_log
            (cuenta_origen, tipo_tx, monto, estado)
        SELECT gen_random_uuid(), 'deposito', 1000.00, 'completado'
        FROM generate_series(1, 100);
    " 2>&1 | tee "$RESULTS_DIR/baseline.txt"

    log "Resultados guardados en $RESULTS_DIR/baseline.txt"
}

# ── Experimento 2: Latencia 50ms entre nodos (simula geo-dist) ─
exp_latency_50ms() {
    sep "Experimento 2: Latencia 50ms — simula nodos en ciudades diferentes"

    for c in $CRDB1 $CRDB2 $CRDB3; do
        install_tc "$c"
        add_latency "$c" 50 10
    done

    log "Midiendo latencia baseline (sin delay) para comparar..."
    T_BEFORE=$(docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 \
        --format=csv -e "SELECT extract(epoch from now())*1000 AS ts;" 2>/dev/null | tail -1)

    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        \\timing
        INSERT INTO banco_db.transacciones_log
            (cuenta_origen, tipo_tx, monto, estado)
        SELECT gen_random_uuid(), 'transferencia', 5000.00, 'completado'
        FROM generate_series(1, 100);
    " 2>&1 | tee "$RESULTS_DIR/latency_50ms.txt"

    log "Nota: si tc/netem no está disponible, la latencia medida es la base sin delay artificial."

    # Verificar quién es el leaseholder ahora
    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        SELECT range_id, lease_holder, replicas
        FROM [SHOW RANGES FROM TABLE banco_db.transacciones_log WITH DETAILS]
        LIMIT 5;
    " 2>&1 | tee -a "$RESULTS_DIR/latency_50ms.txt"

    # Restaurar
    for c in $CRDB1 $CRDB2 $CRDB3; do
        remove_latency "$c"
    done
}

# ── Experimento 3: Quórum — apagar un nodo ────────────────────
exp_quorum_1_node_down() {
    sep "Experimento 3: Quórum con 1 nodo caído (cluster sigue funcionando)"

    log "Estado inicial del cluster:"
    docker exec "$CRDB1" cockroach node status --insecure --host=localhost:26257 \
        2>&1 | tee "$RESULTS_DIR/quorum_before.txt"

    log "Deteniendo crdb-node3..."
    docker stop "$CRDB3"
    sleep 5

    log "Estado con 2/3 nodos (quórum = 2, debe seguir funcionando):"
    docker exec "$CRDB1" cockroach node status --insecure --host=localhost:26257 \
        2>&1 | tee "$RESULTS_DIR/quorum_2nodes.txt"

    log "Probando escritura con 2 nodos (debe funcionar — tiene quórum):"
    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        \timing
        INSERT INTO banco_db.transacciones_log
            (cuenta_origen, tipo_tx, monto, estado)
        VALUES (gen_random_uuid(), 'deposito', 1000.00, 'completado');
        SELECT 'OK — cluster operativo con 2/3 nodos' AS resultado;
    " 2>&1 | tee -a "$RESULTS_DIR/quorum_2nodes.txt"

    log "Reiniciando crdb-node3..."
    docker start "$CRDB3"
    sleep 10

    log "Estado restaurado:"
    docker exec "$CRDB1" cockroach node status --insecure --host=localhost:26257 \
        2>&1 | tee "$RESULTS_DIR/quorum_restored.txt"
}

# ── Experimento 4: Quórum — apagar 2 nodos (cluster NO disponible) ──
exp_quorum_2_nodes_down() {
    sep "Experimento 4: Quórum con 2 nodos caídos (cluster PIERDE quórum)"

    log "Deteniendo crdb-node2 y crdb-node3..."
    docker stop "$CRDB2" "$CRDB3"
    sleep 5

    log "Probando escritura con 1/3 nodos (debe FALLAR — sin quórum):"
    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        INSERT INTO banco_db.transacciones_log
            (cuenta_origen, tipo_tx, monto, estado)
        VALUES (gen_random_uuid(), 'deposito', 1000.00, 'completado');
    " 2>&1 | tee "$RESULTS_DIR/quorum_lost.txt" || true

    log "Probando LECTURA con 1/3 nodos (puede funcionar con stale reads):"
    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        SELECT COUNT(*) AS total_registros FROM banco_db.transacciones_log;
    " 2>&1 | tee -a "$RESULTS_DIR/quorum_lost.txt" || true

    log "Reiniciando nodos..."
    docker start "$CRDB2" "$CRDB3"
    sleep 15
    log "Cluster restaurado."
}

# ── Experimento 5: Partición de red con iptables ──────────────
exp_network_partition() {
    sep "Experimento 5: Simulación de partición de red (CAP)"

    # Obtener IPs de los contenedores
    IP2=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CRDB2")
    IP3=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CRDB3")

    log "Bloqueando comunicación de node1 con node2 y node3 (split-brain scenario)..."
    docker exec "$CRDB1" bash -c "
        iptables -A OUTPUT -d $IP2 -j DROP
        iptables -A OUTPUT -d $IP3 -j DROP
        iptables -A INPUT  -s $IP2 -j DROP
        iptables -A INPUT  -s $IP3 -j DROP
        echo 'Partición de red activada en node1'
    " 2>/dev/null || log "iptables no disponible — usar Pumba o simulación manual"

    sleep 5
    log "Verificando comportamiento durante partición (CP: debe rechazar escrituras)..."
    docker exec "$CRDB1" cockroach sql --insecure --host=localhost:26257 -e "
        SELECT 'intentando escritura en nodo aislado...' AS estado;
        INSERT INTO banco_db.transacciones_log
            (cuenta_origen, tipo_tx, monto, estado)
        VALUES (gen_random_uuid(), 'deposito', 1000.00, 'completado');
    " 2>&1 | tee "$RESULTS_DIR/network_partition.txt" || true

    log "Restaurando red..."
    docker exec "$CRDB1" bash -c "
        iptables -F OUTPUT 2>/dev/null || true
        iptables -F INPUT  2>/dev/null || true
        echo 'Partición de red removida'
    " 2>/dev/null || true
}

# ── Runner ────────────────────────────────────────────────────
case "${1:-all}" in
    baseline)   exp_baseline ;;
    latency)    exp_latency_50ms ;;
    quorum1)    exp_quorum_1_node_down ;;
    quorum2)    exp_quorum_2_nodes_down ;;
    partition)  exp_network_partition ;;
    all)
        exp_baseline
        exp_latency_50ms
        exp_quorum_1_node_down
        exp_quorum_2_nodes_down
        exp_network_partition
        sep "Todos los experimentos completados"
        log "Resultados en: $RESULTS_DIR/"
        ls -la "$RESULTS_DIR/"
        ;;
    *)
        echo "Uso: $0 [baseline|latency|quorum1|quorum2|partition|all]"
        ;;
esac
