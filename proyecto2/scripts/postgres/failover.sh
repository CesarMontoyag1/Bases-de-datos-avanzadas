#!/bin/bash
# =============================================================================
# failover.sh — Script de failover completo para el cluster PostgreSQL
# Proyecto 2 - SI3009 BDD Avanzadas
#
# Uso:
#   ./failover.sh status              → Ver estado actual del cluster
#   ./failover.sh monitor             → Monitor continuo con failover automático
#   ./failover.sh promote             → Promover replica1 (o replica2) a primary
#   ./failover.sh simulate-failure    → Simular caída del primary
#   ./failover.sh failback            → Restaurar el primary original al cluster
#   ./failover.sh help                → Ver todos los comandos disponibles
#
# =============================================================================

set -euo pipefail

# ── Configuración del cluster ────────────────────────────────────────────────
PRIMARY_CONTAINER="pg-primary"
REPLICA1_CONTAINER="pg-replica1"
REPLICA2_CONTAINER="pg-replica2"
PGBOUNCER_CONTAINER="pgbouncer"
PGBOUNCER_IMAGE="edoburu/pgbouncer:latest"

PRIMARY_HOST="localhost"
PRIMARY_PORT=5432
REPLICA1_HOST="localhost"
REPLICA1_PORT=5433
REPLICA2_HOST="localhost"
REPLICA2_PORT=5434

PG_USER="banco_admin"
PG_PASS="banco_pass"
PG_DB="banco_db"
REPL_USER="replicator"
REPL_PASS="repl_pass"

export PGPASSWORD="$PG_PASS"

# ── Colores para output ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log()     { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
log_ok()  { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}✓${NC} $*"; }
log_err() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}✗ ERROR:${NC} $*"; }
log_warn(){ echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}⚠${NC} $*"; }
log_info(){ echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}→${NC} $*"; }

# =============================================================================
# UTILIDADES
# =============================================================================

# Verificar si un contenedor está corriendo
container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$1$"
}

# Verificar si PostgreSQL dentro del contenedor acepta conexiones
pg_ready() {
    local container=$1 port=$2
    container_running "$container" && \
    docker exec "$container" pg_isready -U "$PG_USER" -d "$PG_DB" -p "$port" -q 2>/dev/null
}

# Obtener el rol de un nodo (PRIMARY / REPLICA / DOWN)
node_role() {
    local container=$1 port=$2
    if ! container_running "$container"; then
        echo "DOWN"
        return
    fi
    local result
    result=$(docker exec "$container" psql -U "$PG_USER" -d "$PG_DB" -p "$port" -tAc \
        "SELECT CASE WHEN pg_is_in_recovery() THEN 'REPLICA' ELSE 'PRIMARY' END;" 2>/dev/null) || true
    echo "${result:-DOWN}"
}

# Obtener la red Docker del cluster (detecta el prefijo de compose automáticamente)
get_pg_network() {
    docker inspect "$REPLICA1_CONTAINER" \
        --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null \
        | head -1
}

# =============================================================================
# COMANDO: status
# =============================================================================
cmd_status() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}         Estado del Cluster PostgreSQL                  ${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"

    local nodes=(
    "$PRIMARY_CONTAINER:$PRIMARY_HOST:5432"
    "$REPLICA1_CONTAINER:$REPLICA1_HOST:5432"
    "$REPLICA2_CONTAINER:$REPLICA2_HOST:5432"
    )

    local active_primary=""
    for entry in "${nodes[@]}"; do
        IFS=: read -r name host port <<< "$entry"
        local role
        role=$(node_role "$name" "$port")
        if [ "$role" = "PRIMARY" ]; then
            echo -e "  ${GREEN}✓${NC} ${BOLD}$name${NC} ($host:$port) → ${GREEN}PRIMARY${NC}"
            active_primary="$name:$host:$port"
        elif [ "$role" = "REPLICA" ]; then
            echo -e "  ${BLUE}✓${NC} $name ($host:$port) → ${BLUE}REPLICA${NC}"
        else
            echo -e "  ${RED}✗${NC} $name ($host:$port) → ${RED}DOWN${NC}"
        fi
    done

    echo ""
    echo -e "${BOLD}  PgBouncer:${NC}"
    if container_running "$PGBOUNCER_CONTAINER"; then
        local pb_target
        pb_target=$(docker inspect "$PGBOUNCER_CONTAINER" \
            --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
            | grep "^DB_HOST=" | cut -d= -f2 || echo "desconocido")
        echo -e "  ${GREEN}✓${NC} $PGBOUNCER_CONTAINER → apunta a ${BOLD}$pb_target${NC}"
    else
        echo -e "  ${RED}✗${NC} $PGBOUNCER_CONTAINER → DOWN"
    fi

    # Lag de replicación (solo si hay primary activo)
    echo ""
    if [ -n "$active_primary" ]; then
        IFS=: read -r _name _host ap <<< "$active_primary"
        echo -e "${BOLD}  Lag de replicación (desde el primary):${NC}"
        docker exec "$_name" psql -U "$PG_USER" -d "$PG_DB" -p "$ap" \
            --no-align --field-separator=' | ' -c \
            "SELECT application_name,
                    state,
                    sync_state,
                    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS replay_lag,
                    replay_lag AS replay_lag_time
             FROM pg_stat_replication
             ORDER BY application_name;" 2>/dev/null \
            || echo "  (sin réplicas conectadas)"
    else
        echo -e "  ${YELLOW}No hay primary disponible para consultar lag.${NC}"
    fi

    echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# =============================================================================
# COMANDO: promote
# Promueve replica1 (o replica2 si replica1 no está) a primary y reconfigura todo
# =============================================================================
cmd_promote() {
    log_info "Iniciando proceso de failover..."

    # ── Elegir qué réplica promover ──────────────────────────────────────────
    local promote_container promote_port other_container other_port
    if pg_ready "$REPLICA1_CONTAINER" 5432; then
        promote_container="$REPLICA1_CONTAINER"
        promote_port="$REPLICA1_PORT"
        other_container="$REPLICA2_CONTAINER"
        other_port="$REPLICA2_PORT"
        log_info "Replica seleccionada para promoción: $promote_container"
    elif pg_ready "$REPLICA2_CONTAINER" 5432; then
        promote_container="$REPLICA2_CONTAINER"
        promote_port="$REPLICA2_PORT"
        other_container="$REPLICA1_CONTAINER"
        other_port="$REPLICA1_PORT"
        log_warn "replica1 no disponible. Usando $promote_container como fallback."
    else
        log_err "Ninguna réplica disponible. El cluster está en estado crítico."
        exit 1
    fi

    # ── Verificar que realmente es una réplica (no ya un primary) ───────────
    local current_role
    current_role=$(node_role "$promote_container" 5432)
    if [ "$current_role" = "PRIMARY" ]; then
        log_warn "$promote_container ya es PRIMARY. No se necesita promoción."
        return 0
    fi

    # ── PASO 1: Promover la réplica ──────────────────────────────────────────
    log_info "Promoviendo $promote_container a PRIMARY (pg_ctl promote)..."
    docker exec "$promote_container" bash -c \
        "gosu postgres pg_ctl promote -D /var/lib/postgresql/data" 2>&1

    # Esperar a que la promoción sea efectiva
    log_info "Esperando a que la promoción sea efectiva..."
    local retries=0
    while [ $retries -lt 15 ]; do
        sleep 2
        local role
        role=$(node_role "$promote_container" 5432)
        if [ "$role" = "PRIMARY" ]; then
            log_ok "$promote_container es ahora PRIMARY."
            break
        fi
        retries=$((retries + 1))
        log_info "  Intento $retries/15 — rol actual: $role"
    done

    if [ "$(node_role "$promote_container" 5432)" != "PRIMARY" ]; then
        log_err "La promoción falló. Rol final: $(node_role "$promote_container" 5432)"
        exit 1
    fi

    # ── PASO 2: Limpiar default_transaction_read_only ────────────────────────
    # FIX CRÍTICO: postgres-replica.conf está montado :ro (read-only en Docker),
    # por lo que sed falla. ALTER SYSTEM escribe en postgresql.auto.conf dentro
    # del volumen de datos, que SÍ es escribible.
    log_info "Eliminando default_transaction_read_only en el nuevo primary..."
    docker exec "$promote_container" psql -U "$PG_USER" -d "$PG_DB" -p 5432 -c \
        "ALTER SYSTEM SET default_transaction_read_only = off;" 2>/dev/null
    docker exec "$promote_container" psql -U "$PG_USER" -d "$PG_DB" -p 5432 -c \
        "SELECT pg_reload_conf();" 2>/dev/null

    # Verificar
    local read_only_val
    read_only_val=$(docker exec "$promote_container" psql -U "$PG_USER" -d "$PG_DB" -p 5432 -tAc \
        "SHOW default_transaction_read_only;" 2>/dev/null | tr -d '[:space:]')
    if [ "$read_only_val" = "off" ]; then
        log_ok "default_transaction_read_only = off. El nuevo primary acepta escrituras."
    else
        log_warn "default_transaction_read_only sigue en '$read_only_val'. Reintentando con pg_reload_conf..."
        sleep 2
        docker exec "$promote_container" psql -U "$PG_USER" -d "$PG_DB" -p 5432 -c \
            "SELECT pg_reload_conf();" 2>/dev/null
    fi

    # ── PASO 3: Reconectar la otra réplica al nuevo primary ──────────────────
    log_info "Reconectando $other_container al nuevo primary ($promote_container)..."
    if container_running "$other_container"; then
        # Actualizar primary_conninfo en postgresql.auto.conf (escribible)
        docker exec "$other_container" psql -U "$PG_USER" -d "$PG_DB" -p 5432 \
            -tAc "ALTER SYSTEM SET primary_conninfo = \
                'host=$promote_container port=5432 user=$REPL_USER password=$REPL_PASS \
                 application_name=$other_container';" 2>/dev/null || true

        docker exec "$other_container" bash -c \
            "gosu postgres pg_ctl reload -D /var/lib/postgresql/data" 2>/dev/null || true

        sleep 3
        local other_role
        other_role=$(node_role "$other_container" 5432)
        if [ "$other_role" = "REPLICA" ]; then
            log_ok "$other_container reconectado correctamente como REPLICA del nuevo primary."
        else
            log_warn "$other_container no pudo reconectarse automáticamente (rol: $other_role)."
            log_warn "Puede que necesite un reinicio manual: docker restart $other_container"
        fi
    else
        log_warn "$other_container no está corriendo. Se omite la reconexión."
    fi

    # ── PASO 4: Reapuntar PgBouncer al nuevo primary ─────────────────────────
    log_info "Reconfigurando PgBouncer para apuntar a $promote_container..."
    local pg_network
    pg_network=$(get_pg_network)

    if [ -z "$pg_network" ]; then
        log_warn "No se pudo detectar la red Docker. PgBouncer no se reconfigurará automáticamente."
    else
        docker rm -f "$PGBOUNCER_CONTAINER" 2>/dev/null || true
        sleep 1

        docker run -d \
            --name "$PGBOUNCER_CONTAINER" \
            --network "$pg_network" \
            -p 6432:6432 \
            -e DB_HOST="$promote_container" \
            -e DB_PORT=5432 \
            -e DB_USER="$PG_USER" \
            -e DB_PASSWORD="$PG_PASS" \
            -e DB_NAME="$PG_DB" \
            -e POOL_MODE=transaction \
            -e MAX_CLIENT_CONN=100 \
            -e DEFAULT_POOL_SIZE=20 \
            "$PGBOUNCER_IMAGE" > /dev/null

        sleep 2
        if container_running "$PGBOUNCER_CONTAINER"; then
            log_ok "PgBouncer ahora apunta a $promote_container:5432 (externo: puerto $promote_port)."
        else
            log_warn "PgBouncer no pudo reiniciarse. Revisa manualmente."
        fi
    fi

    # ── PASO 5: Prueba de escritura para confirmar el failover ───────────────
    log_info "Ejecutando prueba de escritura en el nuevo primary..."
    local test_result
    test_result=$(docker exec "$promote_container" psql -U "$PG_USER" -d "$PG_DB" -p 5432 -tAc \
        "INSERT INTO clientes(nombre, email, pais)
         VALUES('failover_test_$(date +%s)', 'failover@test.com', 'CO')
         RETURNING cliente_id;" 2>/dev/null) || true

    if [ -n "$test_result" ]; then
        log_ok "Prueba de escritura exitosa. cliente_id insertado: $test_result"
    else
        log_warn "La prueba de escritura no retornó resultado. Verifica manualmente."
    fi

    # ── Resumen final ─────────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}════════════════════════════ FAILOVER COMPLETADO ═══════════════════════════${NC}"
    echo -e "  ${GREEN}Nuevo PRIMARY:${NC}  $promote_container  (puerto externo: $promote_port)"
    echo -e "  ${BLUE}Réplica:${NC}        $other_container  (si se reconectó)"
    echo -e "  ${BLUE}PgBouncer:${NC}      apunta a $promote_container:5432"
    echo ""
    echo -e "  ${YELLOW}→ Para prevenir Split-Brain:${NC}"
    echo -e "    NO reinicies $PRIMARY_CONTAINER hasta ejecutar './failover.sh failback'"
    echo -e "    El antiguo primary al reiniciarse intentará ser primary de nuevo."
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# =============================================================================
# COMANDO: monitor (loop continuo, failover automático)
# =============================================================================
cmd_monitor() {
    log_info "Monitor iniciado. Detecta caída del primary y ejecuta failover automático."
    log_info "Presiona Ctrl+C para detener."
    echo ""

    local failover_done=false

    while true; do
        if ! pg_ready "$PRIMARY_CONTAINER" 5432; then
            if [ "$failover_done" = false ]; then
                log_warn "PRIMARY ($PRIMARY_CONTAINER) no responde. Iniciando failover automático..."
                cmd_promote
                failover_done=true
                log_ok "Failover completado. Monitor detenido (cluster estabilizado)."
                break
            fi
        else
            local role
            role=$(node_role "$PRIMARY_CONTAINER" 5432)
            log "Primary OK (rol: $role). Próxima verificación en 5s..."
        fi
        sleep 5
    done
}

# =============================================================================
# COMANDO: simulate-failure
# =============================================================================
cmd_simulate_failure() {
    if ! container_running "$PRIMARY_CONTAINER"; then
        log_warn "$PRIMARY_CONTAINER ya está detenido."
        return 0
    fi

    log_info "Simulando caída del primary..."
    log_warn "docker stop $PRIMARY_CONTAINER"
    docker stop "$PRIMARY_CONTAINER"

    log_ok "Primary detenido."
    echo ""
    echo -e "  Opciones para continuar:"
    echo -e "  ${BOLD}./failover.sh promote${NC}   → Failover manual inmediato"
    echo -e "  ${BOLD}./failover.sh monitor${NC}   → Failover automático al detectar la caída"
    echo -e "  ${BOLD}./failover.sh status${NC}    → Ver estado del cluster"
    echo ""
}

# =============================================================================
# COMANDO: failback
# Reintegra el antiguo primary como RÉPLICA del nuevo primary (previene split-brain)
# =============================================================================
cmd_failback() {
    echo ""
    log_info "Iniciando proceso de failback (reintegrar antiguo primary como réplica)..."
    echo ""

    # Detectar el primary actual
    local current_primary="" current_primary_int_port=5432
    for entry in \
        "$PRIMARY_CONTAINER:$PRIMARY_PORT" \
        "$REPLICA1_CONTAINER:$REPLICA1_PORT" \
        "$REPLICA2_CONTAINER:$REPLICA2_PORT"
    do
        IFS=: read -r cname cport <<< "$entry"
        if [ "$(node_role "$cname" 5432)" = "PRIMARY" ]; then
            current_primary="$cname"
            break
        fi
    done

    if [ -z "$current_primary" ]; then
        log_err "No se encontró un primary activo. Verifica el estado del cluster."
        exit 1
    fi

    log_info "Primary activo detectado: $current_primary"

    # El contenedor a reintegrar es el que NO es el primary actual
    local old_primary="$PRIMARY_CONTAINER"
    if [ "$current_primary" = "$PRIMARY_CONTAINER" ]; then
        log_warn "El primary original sigue siendo el primary activo. No es necesario el failback."
        return 0
    fi

    # Si el antiguo primary está corriendo, debe detenerse primero
    if container_running "$old_primary"; then
        log_info "Deteniendo el antiguo primary ($old_primary) para evitar split-brain..."
        docker stop "$old_primary"
        sleep 2
    fi

    log_info "Recreando $old_primary como réplica del nuevo primary ($current_primary)..."

    # Obtener el volumen de datos del antiguo primary
    local vol_name
    vol_name=$(docker inspect "$old_primary" \
        --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' \
        2>/dev/null || echo "")

    if [ -z "$vol_name" ]; then
        # Intentar inferir el nombre del volumen por convención de compose
        vol_name=$(docker volume ls --format '{{.Name}}' | grep "pg_primary_data" | head -1)
    fi

    local pg_network
    pg_network=$(get_pg_network)

    if [ -z "$pg_network" ]; then
        log_err "No se pudo detectar la red Docker del cluster."
        exit 1
    fi

    log_info "Limpiando datos del antiguo primary y haciendo pg_basebackup desde $current_primary..."
    docker run --rm \
        --network "$pg_network" \
        -v "${vol_name}:/var/lib/postgresql/data" \
        postgres:16 bash -c "
            rm -rf /var/lib/postgresql/data/* &&
            PGPASSWORD=$REPL_PASS pg_basebackup \
                -h $current_primary -U $REPL_USER -p 5432 \
                -D /var/lib/postgresql/data \
                -Fp -Xs -P -R --checkpoint=fast &&
            chown -R postgres:postgres /var/lib/postgresql/data &&
            chmod 700 /var/lib/postgresql/data
        " 2>&1

    log_ok "pg_basebackup completado. Reiniciando $old_primary como réplica..."
    docker start "$old_primary" || true

    sleep 5
    local new_role
    new_role=$(node_role "$old_primary" 5432)
    if [ "$new_role" = "REPLICA" ]; then
        log_ok "Failback exitoso: $old_primary reintegrado como REPLICA de $current_primary."
    else
        log_warn "Estado de $old_primary: $new_role. Puede necesitar tiempo para sincronizarse."
    fi

    echo ""
    cmd_status
}

# =============================================================================
# COMANDO: help
# =============================================================================
cmd_help() {
    echo ""
    echo -e "${BOLD}Uso: $0 [comando]${NC}"
    echo ""
    echo -e "  ${BOLD}status${NC}             Ver estado actual del cluster (nodos, roles, lag)"
    echo -e "  ${BOLD}monitor${NC}            Loop continuo — ejecuta failover automático si primary cae"
    echo -e "  ${BOLD}promote${NC}            Failover manual: promueve replica1 a primary y reconfigura todo"
    echo -e "  ${BOLD}simulate-failure${NC}   Detiene pg-primary (para pruebas de failover)"
    echo -e "  ${BOLD}failback${NC}           Reintegra el antiguo primary como réplica del nuevo primary"
    echo -e "  ${BOLD}help${NC}               Este mensaje"
    echo ""
    echo -e "${BOLD}Flujo típico de prueba 4.1 (Escenario de Failover):${NC}"
    echo -e "  1. ./failover.sh status"
    echo -e "  2. ./failover.sh simulate-failure   # baja pg-primary"
    echo -e "  3. ./failover.sh promote             # promueve replica1 + reconfigura todo"
    echo -e "  4. ./failover.sh status              # verificar nuevo estado"
    echo -e "  5. ./failover.sh failback            # reintegrar antiguo primary como réplica"
    echo ""
    echo -e "${BOLD}Variables de entorno que puedes sobreescribir:${NC}"
    echo -e "  PG_USER, PG_PASS, PG_DB, REPL_USER, REPL_PASS"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
case "${1:-status}" in
    status)           cmd_status           ;;
    monitor)          cmd_monitor          ;;
    promote)          cmd_promote          ;;
    simulate-failure) cmd_simulate_failure ;;
    failback)         cmd_failback         ;;
    help|--help|-h)   cmd_help             ;;
    *)
        echo -e "${RED}Comando desconocido: $1${NC}"
        cmd_help
        exit 1
        ;;
esac
