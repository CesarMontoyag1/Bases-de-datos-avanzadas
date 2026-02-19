#!/bin/bash
# aws_setup.sh — Setup completo en EC2 de AWS Academy
# Ejecutar UNA VEZ después de conectarse a la instancia:
#   chmod +x aws_setup.sh && ./aws_setup.sh
#
# Instancia recomendada: t3.medium (2 vCPU, 4GB RAM) — Ubuntu 22.04/24.04
# Costo estimado: ~$0.04/h — APAGAR cuando no se use con:
#   sudo shutdown -h now

set -euo pipefail

log()  { echo -e "\n\033[1;32m[$(date '+%H:%M:%S')] $*\033[0m"; }
warn() { echo -e "\033[1;33m[WARN] $*\033[0m"; }
sep()  { echo -e "\033[1;34m\n══════════════════════════════════════════\033[0m"; }

sep
log "Instalando dependencias del sistema..."

# Actualizar repositorios
sudo apt-get update -qq

# Instalar dependencias base
sudo apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    wget \
    unzip \
    python3 \
    python3-pip \
    postgresql-client \
    iproute2 \
    net-tools \
    htop

# ─────────────────────────────────────────────────────────────
# Instalación de Docker desde el repositorio oficial
# ─────────────────────────────────────────────────────────────
if ! command -v docker &> /dev/null; then
    log "Configurando repositorio oficial de Docker..."

    sudo install -m 0755 -d /etc/apt/keyrings

    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi

    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    UBUNTU_CODENAME=$(lsb_release -cs)
    ARCH=$(dpkg --print-architecture)

    echo \
      "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq

    log "Instalando Docker CE y Docker Compose Plugin..."
    sudo apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
else
    warn "Docker ya está instalado. Omitiendo instalación."
fi

# Configurar Docker para uso sin sudo
sudo usermod -aG docker "$USER"
sudo systemctl enable docker
sudo systemctl start docker

log "Docker instalado: $(docker --version)"
log "Docker Compose: $(docker compose version)"

# ─────────────────────────────────────────────────────────────
# Configuración del repositorio del proyecto
# ─────────────────────────────────────────────────────────────
sep
log "Configurando el repositorio del proyecto..."

# URL del repositorio (solo se usará si es necesario clonar)
REPO_URL="${REPO_URL:-https://github.com/tu-equipo/proyecto2-bdd.git}"

# Caso 1: El directorio actual ya es un repositorio Git
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "El repositorio ya está clonado en el directorio actual."
    PROJECT_DIR="$(pwd)"

# Caso 2: Existe el directorio proyecto2-bdd
elif [ -d "proyecto2-bdd/.git" ]; then
    log "Repositorio existente encontrado en ./proyecto2-bdd"
    cd proyecto2-bdd
    PROJECT_DIR="$(pwd)"

    # Intentar actualizar el repositorio sin interrumpir el script
    if git remote get-url origin &>/dev/null; then
        warn "Intentando actualizar el repositorio (git pull)..."
        git pull --ff-only || warn "No fue posible actualizar el repositorio. Continuando..."
    fi

# Caso 3: No existe el repositorio, entonces se clona
else
    log "Repositorio no encontrado. Clonando desde GitHub..."
    git clone "$REPO_URL" proyecto2-bdd
    cd proyecto2-bdd
    PROJECT_DIR="$(pwd)"
fi

log "Directorio del proyecto: $PROJECT_DIR"

# ─────────────────────────────────────────────────────────────
# Instalación de dependencias Python
# ─────────────────────────────────────────────────────────────
sep
log "Instalando dependencias Python..."
pip3 install -q faker psycopg2-binary tqdm python-dotenv 2>/dev/null || \
    pip3 install --break-system-packages -q faker psycopg2-binary tqdm python-dotenv 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# Levantando cluster PostgreSQL
# ─────────────────────────────────────────────────────────────
sep
log "Levantando cluster PostgreSQL..."
cd "$PROJECT_DIR/infra"

# Aplicar el grupo docker sin cerrar sesión
sg docker -c "docker compose -f docker-compose.postgres.yml up -d"

log "Esperando que PostgreSQL esté listo (30s)..."
sleep 10

# Verificar que el primary está funcionando
for i in {1..10}; do
    if docker exec pg-primary pg_isready -U banco_admin -q 2>/dev/null; then
        log "PostgreSQL Primary: OK"
        break
    fi
    echo "  Intento $i/10..."
    sleep 5
done

# ─────────────────────────────────────────────────────────────
# Levantando cluster CockroachDB
# ─────────────────────────────────────────────────────────────
sep
log "Levantando cluster CockroachDB..."
sg docker -c "docker compose -f docker-compose.cockroach.yml up -d"

log "Esperando que CockroachDB inicialice (45s)..."
sleep 10

# Verificar nodos CRDB
if docker exec crdb-node1 cockroach node status --insecure --host=localhost:26257 &>/dev/null; then
    log "CockroachDB: OK"
    docker exec crdb-node1 cockroach node status --insecure --host=localhost:26257
else
    warn "CockroachDB aún inicializando, esperando 30s más..."
    sleep 30
fi

cd "$PROJECT_DIR"

# ─────────────────────────────────────────────────────────────
# Creación de esquemas
# ─────────────────────────────────────────────────────────────
sep
log "Creando esquemas en PostgreSQL..."
docker exec -i pg-primary psql -U banco_admin -d banco_db < scripts/postgres/01_schema.sql
log "Esquema PostgreSQL creado."

sep
log "Creando esquemas en CockroachDB..."
docker exec -i crdb-node1 cockroach sql --insecure --host=localhost:26257 \
    --database=banco_db < scripts/cockroachdb/01_cockroachdb_schema.sql
log "Esquema CockroachDB creado."

# ─────────────────────────────────────────────────────────────
# Generación de datos sintéticos
# ─────────────────────────────────────────────────────────────
sep
log "Generando datos sintéticos (500K transacciones por BD)..."
log "Esto puede tardar 5-10 minutos..."
cd "$PROJECT_DIR/data"
python3 generate_data.py --target both --rows 500000 --clientes 10000
cd "$PROJECT_DIR"

# ─────────────────────────────────────────────────────────────
# Verificación de carga de datos
# ─────────────────────────────────────────────────────────────
sep
log "Verificando carga de datos..."

echo ""
echo "PostgreSQL — conteo por tabla:"
docker exec pg-primary psql -U banco_admin -d banco_db -c "
    SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
    UNION ALL
    SELECT 'cuentas', COUNT(*) FROM cuentas
    UNION ALL
    SELECT 'transacciones_log', COUNT(*) FROM transacciones_log;
"

echo ""
echo "CockroachDB — conteo por tabla:"
docker exec crdb-node1 cockroach sql --insecure --host=localhost:26257 \
    --database=banco_db -e "
    SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
    UNION ALL
    SELECT 'cuentas', COUNT(*) FROM cuentas
    UNION ALL
    SELECT 'transacciones_log', COUNT(*) FROM transacciones_log;
"

# ─────────────────────────────────────────────────────────────
# Verificación de particiones PostgreSQL
# ─────────────────────────────────────────────────────────────
sep
log "Verificando particiones PostgreSQL..."
docker exec pg-primary psql -U banco_admin -d banco_db -c "
    SELECT tablename AS particion,
           pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS tamaño
    FROM pg_tables
    WHERE tablename LIKE 'tx_log_%'
       OR tablename LIKE 'tx_tipo_%'
       OR tablename LIKE 'cuentas_shard_%'
    ORDER BY tablename;
"

# ─────────────────────────────────────────────────────────────
# Verificación de distribución en CockroachDB
# ─────────────────────────────────────────────────────────────
sep
log "Verificando distribución CockroachDB..."
docker exec crdb-node1 cockroach sql --insecure --host=localhost:26257 \
    --database=banco_db -e "
    SELECT range_id, start_key, end_key, lease_holder, replicas
    FROM [SHOW RANGES FROM TABLE transacciones_log WITH DETAILS]
    LIMIT 10;
"

# ─────────────────────────────────────────────────────────────
# Ejecución de experimentos
# ─────────────────────────────────────────────────────────────
sep
log "Ejecutando experimentos de latencia base..."
mkdir -p "$PROJECT_DIR/docs"
cd "$PROJECT_DIR/data"
python3 experiments.py --experiment all 2>&1 | tee "$PROJECT_DIR/docs/experiment_results_raw.txt"
cd "$PROJECT_DIR"

# ─────────────────────────────────────────────────────────────
# Resumen final
# ─────────────────────────────────────────────────────────────
sep
cat << 'SUMMARY'
══════════════════════════════════════════════════════════
  SETUP COMPLETADO EXITOSAMENTE
══════════════════════════════════════════════════════════

  Accesos:
    PostgreSQL Primary:   localhost:5432  (banco_admin/banco_pass)
    PostgreSQL Replica1:  localhost:5433
    PostgreSQL Replica2:  localhost:5434
    CockroachDB Node1:    localhost:26257
    CockroachDB Admin UI: http://localhost:8080

  Próximos pasos:
    1. Ejecutar experimentos de replicación:
       psql -h localhost -p 5432 -U banco_admin -d banco_db \
            -f scripts/postgres/03_replication_experiments.sql

    2. Ejecutar experimentos 2PC:
       psql -h localhost -p 5432 -U banco_admin -d banco_db \
            -f scripts/postgres/02_2pc_transactions.sql

    3. Experimentos de red CockroachDB:
       bash scripts/cockroachdb/network_experiments.sh all

    4. Failover PostgreSQL:
       bash scripts/postgres/failover.sh monitor

    5. Ver resultados:
       cat docs/experiment_results.json

  IMPORTANTE (AWS Academy):
    Apagar instancia cuando no se use:
       sudo shutdown -h now

SUMMARY
