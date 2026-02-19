# Guía AWS Academy — Paso a Paso
## Proyecto 2 SI3009 — Desde cero hasta experimentos corriendo

---

## Parte 1: Crear la instancia EC2

### 1.1 En la consola de AWS Academy

1. Ir a **AWS Academy** → **Learner Lab** → **Start Lab**
2. Esperar que el indicador cambie a verde (AWS listo)
3. Clic en **AWS** para abrir la consola

### 1.2 Lanzar la instancia EC2

En EC2 → **Launch Instance**:

| Campo | Valor |
|---|---|
| Name | `proyecto2-bdd` |
| AMI | **Ubuntu Server 22.04 LTS** (gratis) |
| Instance type | **t3.medium** (2 vCPU, 4GB RAM) |
| Key pair | Crear nuevo: `proyecto2-key` → descargar .pem |
| Storage | **20 GB** gp3 (suficiente) |

**Security Group** — agregar estas reglas:

| Type | Port | Source |
|---|---|---|
| SSH | 22 | My IP |
| Custom TCP | 5432 | My IP |
| Custom TCP | 26257 | My IP |
| Custom TCP | 8080 | My IP |

Clic **Launch Instance**.

---

## Parte 2: Conectarse a la instancia

### 2.1 Desde Mac/Linux

```bash
chmod 400 proyecto2-key.pem
ssh -i proyecto2-key.pem ubuntu@<IP_PUBLICA_EC2>
```

### 2.2 Desde Windows (PowerShell)

```powershell
ssh -i proyecto2-key.pem ubuntu@<IP_PUBLICA_EC2>
```

### 2.3 Obtener la IP pública

En la consola EC2 → Instances → tu instancia → **Public IPv4 address**

---

## Parte 3: Setup automático

```bash
# Una vez conectado a la EC2:

# Descargar el proyecto (opción A: desde GitHub)
git clone https://github.com/TU_USUARIO/proyecto2-bdd.git
cd proyecto2-bdd

# O descomprimir el ZIP si lo subiste por SCP:
# scp -i proyecto2-key.pem proyecto2_bdd.zip ubuntu@<IP>:~
# unzip proyecto2_bdd.zip && cd proyecto2

# Dar permisos y ejecutar setup
chmod +x aws_setup.sh
./aws_setup.sh
```

El script instala todo y tarda ~15 minutos. Al finalizar verás el resumen de accesos.

---

## Parte 4: Verificar que todo funciona

```bash
# Ver todos los contenedores corriendo
docker ps

# Debe mostrar:
# pg-primary, pg-replica1, pg-replica2, pgbouncer
# crdb-node1, crdb-node2, crdb-node3, crdb-init (exited)

# Conectarse a PostgreSQL Primary
psql -h localhost -p 5432 -U banco_admin -d banco_db -c "\dt"

# Conectarse a CockroachDB
docker exec -it crdb-node1 cockroach sql --insecure --host=localhost:26257 \
    --database=banco_db -e "\dt"

# Ver Admin UI de CockroachDB (desde tu máquina con SSH tunnel):
ssh -i proyecto2-key.pem -L 8080:localhost:8080 ubuntu@<IP_EC2> -N &
# Luego abrir: http://localhost:8080
```

---

## Parte 5: Ejecutar los experimentos en orden

### Experimento 1: Verificar particionamiento PostgreSQL

```bash
psql -h localhost -p 5432 -U banco_admin -d banco_db << 'EOF'
-- Ver particiones y tamaños
SELECT tablename AS particion,
       pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS tamaño,
       (SELECT COUNT(*) FROM pg_inherits
        WHERE inhrelid = ('public.'||tablename)::regclass) AS sub_partes
FROM pg_tables
WHERE tablename LIKE 'tx_log_%'
ORDER BY tablename;

-- Verificar partition pruning (solo debe acceder a Q1)
EXPLAIN SELECT COUNT(*) FROM transacciones_log
WHERE created_at BETWEEN '2024-01-01' AND '2024-03-31';
EOF
```

**Guardar salida:** `... | tee docs/exp1_particionamiento_pg.txt`

### Experimento 2: Replicación y synchronous_commit

```bash
# Ejecutar script completo de replicación
psql -h localhost -p 5432 -U banco_admin -d banco_db \
    -f scripts/postgres/03_replication_experiments.sql \
    2>&1 | tee docs/exp2_replicacion.txt

# Ver estado de réplicas en tiempo real
watch -n 2 'psql -h localhost -p 5432 -U banco_admin -d banco_db -c \
    "SELECT client_addr, sync_state, replay_lag FROM pg_stat_replication;"'
```

### Experimento 3: 2PC — transacciones distribuidas

```bash
# Abrir 2 terminales SSH simultáneas (Terminal A y Terminal B)

# Terminal A: ejecutar PREPARE
psql -h localhost -p 5432 -U banco_admin -d banco_db << 'EOF'
BEGIN;
UPDATE cuentas SET saldo = saldo - 10000
WHERE cuenta_id = (SELECT cuenta_id FROM cuentas LIMIT 1);
PREPARE TRANSACTION 'experimento_2pc_demo';
-- NO ejecutar COMMIT todavía
EOF

# Terminal B: ver la transacción bloqueada
psql -h localhost -p 5432 -U banco_admin -d banco_db -c \
    "SELECT gid, prepared, owner, database FROM pg_prepared_xacts;"

# Terminal A: completar el commit
psql -h localhost -p 5432 -U banco_admin -d banco_db -c \
    "COMMIT PREPARED 'experimento_2pc_demo';"

# Simular caída del coordinador:
psql -h localhost -p 5432 -U banco_admin -d banco_db << 'EOF'
BEGIN;
UPDATE cuentas SET saldo = saldo - 5000
WHERE cuenta_id = (SELECT cuenta_id FROM cuentas LIMIT 1);
PREPARE TRANSACTION 'tx_coordinador_muerto';
-- Ahora simular que el coordinador "murió" — NO hacer commit
-- Ver el bloqueo:
-- SELECT * FROM pg_prepared_xacts;
-- Resolución manual:
-- ROLLBACK PREPARED 'tx_coordinador_muerto';
EOF
```

### Experimento 4: Failover PostgreSQL

```bash
# Terminal 1: monitoreo continuo
watch -n 1 'docker exec pg-primary psql -U banco_admin -d banco_db \
    -c "SELECT pg_is_in_recovery(), inet_server_addr();" 2>/dev/null || echo "PRIMARY CAIDO"'

# Terminal 2: matar el primary
docker stop pg-primary
sleep 5

# Promover replica1
bash scripts/postgres/failover.sh promote

# Verificar nuevo primary
psql -h localhost -p 5433 -U banco_admin -d banco_db \
    -c "SELECT pg_is_in_recovery();"  # debe ser FALSE

# Guardar
docker logs pg-replica1 2>&1 | tail -20 | tee docs/exp4_failover.txt
```

### Experimento 5: CockroachDB auto-sharding y Raft

```bash
# Ver distribución de ranges
docker exec crdb-node1 cockroach sql --insecure --host=localhost:26257 \
    --database=banco_db -e "
    SELECT range_id, start_key, end_key, lease_holder, replicas
    FROM [SHOW RANGES FROM TABLE transacciones_log WITH DETAILS];" \
    2>&1 | tee docs/exp5_crdb_ranges.txt

# Ver quién es el leaseholder de cada range
docker exec crdb-node1 cockroach sql --insecure --host=localhost:26257 \
    --database=banco_db -e "
    SELECT node_id, SUM(range_count) AS ranges
    FROM crdb_internal.kv_node_status GROUP BY node_id;" \
    2>&1 | tee -a docs/exp5_crdb_ranges.txt
```

### Experimento 6: Quórum CockroachDB

```bash
bash scripts/cockroachdb/network_experiments.sh quorum1
bash scripts/cockroachdb/network_experiments.sh quorum2
# Resultados en: docs/network_experiments/
```

### Experimento 7: Latencia comparativa (script automático)

```bash
cd data
python3 experiments.py --experiment all
cat ../docs/experiment_results.json | python3 -m json.tool
```

---

## Parte 6: Capturar evidencias para el README

```bash
# Crear directorio de evidencias
mkdir -p docs/evidencias

# Screenshots que debes tomar:
# 1. CockroachDB Admin UI mostrando los 3 nodos (http://localhost:8080)
# 2. Partition pruning en EXPLAIN (solo accede a la partición correcta)
# 3. pg_stat_replication con lag cercano a 0
# 4. pg_prepared_xacts con transacción zombie
# 5. CRDB SHOW RANGES mostrando distribución entre nodos

# Generar resumen de todos los experimentos
cat docs/exp*.txt docs/network_experiments/*.txt > docs/EVIDENCIAS_COMPLETAS.txt
wc -l docs/EVIDENCIAS_COMPLETAS.txt
```

---

## Parte 7: Apagar la instancia (IMPORTANTE para ahorrar créditos)

```bash
# Apagar contenedores
docker compose -f infra/docker-compose.postgres.yml down
docker compose -f infra/docker-compose.cockroach.yml down

# Apagar la instancia EC2
sudo shutdown -h now
```

En la consola AWS: EC2 → Instance State → **Stop** (no Terminate — para no perder datos).

**Presupuesto estimado AWS Academy:**
- t3.medium: $0.04/h × 8 horas de trabajo = ~$0.32 por sesión
- Con 10 sesiones de trabajo: ~$3.20 total (muy dentro del límite de $50-100 de Academy)

---

## Checklist final antes de entregar

- [ ] `docker ps` muestra los 6 contenedores (3 PG + 3 CRDB)
- [ ] `SELECT COUNT(*) FROM transacciones_log` retorna ~500K en ambas BDs
- [ ] `SELECT * FROM pg_prepared_xacts` funciona (para el experimento 2PC)
- [ ] `SHOW RANGES FROM TABLE transacciones_log` muestra distribución en CRDB
- [ ] `docs/experiment_results.json` tiene latencias reales medidas
- [ ] Capturas de pantalla del Admin UI de CockroachDB
- [ ] Resultados de EXPLAIN ANALYZE guardados en docs/
- [ ] `docs/analisis_critico.md` completo con los resultados reales
