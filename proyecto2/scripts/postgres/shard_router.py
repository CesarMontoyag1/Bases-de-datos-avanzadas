#!/usr/bin/env python3
"""
shard_router.py — Capa de enrutamiento manual para PostgreSQL multi-shard
Demuestra cómo la aplicación decide en qué nodo físico vive cada dato.
Proyecto 2 SI3009 — Sección 4.1 (reto de enrutamiento)

La pregunta que responde: ¿Cómo sabe la aplicación en qué nodo está el dato?
"""

import hashlib
import uuid
from datetime import datetime
from typing import Optional
import psycopg2
from psycopg2.extras import RealDictCursor

# ── Mapa de nodos físicos ──────────────────────────────────────
# En producción esto vendría de un servicio de configuración o ZooKeeper
SHARD_NODES = {
    0: {"host": "localhost", "port": 5432,  "role": "primary",  "label": "pg-node-1"},
    1: {"host": "localhost", "port": 5433,  "role": "replica",  "label": "pg-node-2"},
    2: {"host": "localhost", "port": 5434,  "role": "replica",  "label": "pg-node-3"},
}

# Nodo primario (siempre acepta escrituras)
PRIMARY_SHARD = 0

DB_COMMON = {"dbname": "banco_db", "user": "banco_admin", "password": "banco_pass"}


class ShardRouter:
    """
    Enrutador de shards para PostgreSQL.

    Estrategias implementadas:
      - HASH: distribución por hash del cliente_id → shard 0, 1 o 2
      - RANGE: distribución por rango de fecha → partición correcta en PG
      - LIST: distribución por tipo de transacción

    IMPORTANTE: En PostgreSQL el particionamiento es LÓGICO dentro del nodo,
    no distribuye datos entre máquinas automáticamente. Este router simula
    lo que un middleware (Citus, pgBouncer con routing, o la misma app) debe hacer.
    """

    def __init__(self):
        self._connections: dict[int, psycopg2.extensions.connection] = {}

    def _get_conn(self, shard_id: int) -> psycopg2.extensions.connection:
        """Obtiene (o crea) conexión al nodo del shard indicado."""
        if shard_id not in self._connections or self._connections[shard_id].closed:
            node = SHARD_NODES[shard_id]
            self._connections[shard_id] = psycopg2.connect(
                host=node["host"], port=node["port"], **DB_COMMON,
                cursor_factory=RealDictCursor
            )
            self._connections[shard_id].autocommit = True
        return self._connections[shard_id]

    # ── Estrategia 1: HASH routing ────────────────────────────
    def hash_shard(self, cliente_id: str) -> int:
        """
        Determina el shard por hash del cliente_id.
        Mismo algoritmo que el PARTITION BY HASH de PostgreSQL con MODULUS 3.
        """
        h = int(hashlib.md5(cliente_id.encode()).hexdigest(), 16)
        return h % len(SHARD_NODES)

    # ── Estrategia 2: RANGE routing (por fecha) ───────────────
    def range_shard_by_date(self, fecha: datetime) -> str:
        """Determina qué partición de rango contiene la fecha dada."""
        year = fecha.year
        quarter = (fecha.month - 1) // 3 + 1
        partition = f"tx_log_{year}_q{quarter}"
        return partition

    # ── Estrategia 3: LIST routing (por tipo de tx) ───────────
    def list_shard_by_tipo(self, tipo_tx: str) -> str:
        """Determina la partición LIST para un tipo de transacción."""
        mapping = {
            "deposito":       "tx_tipo_deposito",
            "retiro":         "tx_tipo_retiro",
            "transferencia":  "tx_tipo_transfer",
            "pago":           "tx_tipo_pago",
        }
        return mapping.get(tipo_tx, "transacciones_log")  # fallback a tabla maestra

    # ── Operaciones con routing ───────────────────────────────

    def get_cuenta(self, cuenta_id: str, cliente_id: str) -> Optional[dict]:
        """
        Busca una cuenta enrutando al shard correcto por hash del cliente_id.
        Muestra en pantalla la decisión de routing.
        """
        shard_id = self.hash_shard(cliente_id)
        node = SHARD_NODES[shard_id]
        print(f"  [ROUTER] cliente_id={cliente_id[:8]}... → shard={shard_id} ({node['label']}:{node['port']})")

        conn = self._get_conn(shard_id)
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM cuentas WHERE cuenta_id = %s AND cliente_id = %s",
                        (cuenta_id, cliente_id))
            return cur.fetchone()

    def insert_transaccion(self, cuenta_origen: str, tipo_tx: str, monto: float,
                           cuenta_dest: Optional[str] = None) -> dict:
        """
        Inserta una transacción en el nodo primario.
        Muestra a qué partición física irá el dato.
        """
        fecha = datetime.now()
        particion_range = self.range_shard_by_date(fecha)
        particion_list  = self.list_shard_by_tipo(tipo_tx)

        print(f"  [ROUTER] INSERT transaccion tipo={tipo_tx}")
        print(f"    → partición RANGE (fecha): {particion_range}")
        print(f"    → partición LIST  (tipo):  {particion_list}")
        print(f"    → nodo físico: PRIMARY shard={PRIMARY_SHARD} ({SHARD_NODES[PRIMARY_SHARD]['label']})")

        # En PostgreSQL el INSERT va al Primary; PG decide la partición internamente
        conn = self._get_conn(PRIMARY_SHARD)
        with conn.cursor() as cur:
            tx_id = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO transacciones_log
                    (tx_id, cuenta_origen, cuenta_dest, tipo_tx, monto, estado, nodo_origen)
                VALUES (%s, %s, %s, %s, %s, 'completado', %s)
                RETURNING tx_id, created_at
            """, (tx_id, cuenta_origen, cuenta_dest, tipo_tx, monto,
                  SHARD_NODES[PRIMARY_SHARD]["label"]))
            row = cur.fetchone()

        return {
            "tx_id":      row["tx_id"],
            "created_at": row["created_at"],
            "shard":      PRIMARY_SHARD,
            "particion":  particion_range,
        }

    def cross_shard_query(self, fecha_inicio: str, fecha_fin: str) -> list:
        """
        Query que cruza particiones. En PG esto sucede en el mismo nodo (Primary).
        Documenta el costo de un join distribuido.
        """
        print(f"  [ROUTER] Cross-partition query: {fecha_inicio} → {fecha_fin}")
        rango_inicio = self.range_shard_by_date(datetime.fromisoformat(fecha_inicio))
        rango_fin    = self.range_shard_by_date(datetime.fromisoformat(fecha_fin))
        print(f"    → cruza particiones: {rango_inicio} ... {rango_fin}")
        print(f"    → nodo físico: shard={PRIMARY_SHARD} (todo en un solo nodo)")
        print(f"    → DIFERENCIA vs CRDB: en CockroachDB esto cruza nodos reales vía Raft")

        conn = self._get_conn(PRIMARY_SHARD)
        with conn.cursor() as cur:
            cur.execute("""
                EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
                SELECT DATE_TRUNC('month', created_at) AS mes,
                       tipo_tx,
                       COUNT(*)       AS num_tx,
                       SUM(monto)     AS total
                FROM transacciones_log
                WHERE created_at BETWEEN %s AND %s
                GROUP BY 1, 2
                ORDER BY 1, 2
            """, (fecha_inicio, fecha_fin))
            plan = [r[0] for r in cur.fetchall()]
        return plan

    def show_routing_table(self):
        """Muestra la tabla de routing completa para documentación."""
        print("\n" + "="*60)
        print("  TABLA DE ROUTING — PostgreSQL Manual Sharding")
        print("="*60)
        print(f"  {'Shard':>5}  {'Nodo':<12}  {'Puerto':>6}  {'Rol':<10}")
        print("  " + "-"*44)
        for shard_id, node in SHARD_NODES.items():
            print(f"  {shard_id:>5}  {node['label']:<12}  {node['port']:>6}  {node['role']:<10}")

        print("\n  Estrategias:")
        print("  - HASH(cliente_id) % 3  → shard 0, 1 o 2")
        print("  - RANGE(created_at)     → tx_log_2024_q1 ... tx_log_2025_q2")
        print("  - LIST(tipo_tx)         → tx_tipo_deposito, _retiro, etc.")
        print("\n  CONTRASTE con CockroachDB:")
        print("  - En CRDB esta tabla NO existe: el routing es transparente")
        print("  - La app se conecta a cualquier nodo y CRDB enruta internamente")
        print("="*60 + "\n")

    def close(self):
        for conn in self._connections.values():
            if not conn.closed:
                conn.close()


# ── Demo de uso ────────────────────────────────────────────────
if __name__ == "__main__":
    router = ShardRouter()
    router.show_routing_table()

    # Simular decisiones de routing
    print("\n--- Simulación de routing (sin conexión BD) ---")

    test_clientes = [str(uuid.uuid4()) for _ in range(5)]
    for cid in test_clientes:
        shard = router.hash_shard(cid)
        node  = SHARD_NODES[shard]
        print(f"  cliente {cid[:8]}... → shard {shard} ({node['label']}:{node['port']})")

    print("\n--- Routing por fecha ---")
    fechas = ["2024-01-15", "2024-05-01", "2024-09-20", "2025-03-10"]
    for f in fechas:
        particion = router.range_shard_by_date(datetime.fromisoformat(f))
        print(f"  fecha {f} → {particion}")

    print("\n--- Routing por tipo de transacción ---")
    for tipo in ["deposito", "retiro", "transferencia", "pago"]:
        particion = router.list_shard_by_tipo(tipo)
        print(f"  tipo={tipo:15} → {particion}")

    router.close()
