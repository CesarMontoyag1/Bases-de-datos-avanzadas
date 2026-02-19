#!/usr/bin/env python3
"""
experiments.py — Suite de experimentos automatizados
Proyecto 2 SI3009 BDD Avanzadas - Dominio: Banca
"""

import argparse
import json
import statistics
import time
import uuid
from datetime import datetime

import psycopg2

CONNECTIONS = {
    "pg_primary":  {"host": "localhost", "port": 5432,  "dbname": "banco_db", "user": "banco_admin", "password": "banco_pass"},
    "pg_replica1": {"host": "localhost", "port": 5433,  "dbname": "banco_db", "user": "banco_admin", "password": "banco_pass"},
    "pg_replica2": {"host": "localhost", "port": 5434,  "dbname": "banco_db", "user": "banco_admin", "password": "banco_pass"},
    "crdb_node1":  {"host": "localhost", "port": 26257, "dbname": "banco_db", "user": "banco_admin", "password": "banco_pass", "sslmode": "disable"},
}

RESULTS_FILE = "../docs/experiment_results.json"

INSERT_SQL = """
    INSERT INTO transacciones_log
        (tx_id, cuenta_origen, tipo_tx, monto, estado, nodo_origen)
    VALUES (%s, %s, 'deposito', %s, 'completado', %s)
"""

READ_SQL = """
    SELECT COUNT(*), SUM(monto), AVG(monto)
    FROM transacciones_log
    WHERE tipo_tx = 'transferencia'
"""


def measure_latency(conn, fn, n=200):
    latencies = []
    errors = 0
    for _ in range(n):
        try:
            t0 = time.perf_counter()
            fn(conn)
            latencies.append((time.perf_counter() - t0) * 1000)
        except Exception as e:
            errors += 1
    if not latencies:
        return {"error": "all_failed", "errors": errors}
    s = sorted(latencies)
    return {
        "n":        n,
        "errors":   errors,
        "mean_ms":  round(statistics.mean(latencies), 2),
        "median_ms":round(statistics.median(latencies), 2),
        "p95_ms":   round(s[int(len(s) * 0.95)], 2),
        "p99_ms":   round(s[int(len(s) * 0.99)], 2),
        "min_ms":   round(min(latencies), 2),
        "max_ms":   round(max(latencies), 2),
        "stdev_ms": round(statistics.stdev(latencies), 2) if len(s) > 1 else 0,
    }


def write_fn(conn):
    with conn.cursor() as cur:
        cur.execute(INSERT_SQL, (
            str(uuid.uuid4()),
            str(uuid.uuid4()),
            round(1000 + 4000 * (time.perf_counter() % 1), 2),
            "exp-write",
        ))
    conn.commit()


def read_fn(conn):
    with conn.cursor() as cur:
        cur.execute(READ_SQL)
        cur.fetchone()


# ── EXPERIMENTO 1: Latencia escritura vs lectura ──────────────

def exp_latency_write_read():
    print("\n[1/4] Experimento: Latencia escritura/lectura")
    results = {}

    # Escritura en primary
    for label, cfg, fn in [
        ("pg_primary_write",  CONNECTIONS["pg_primary"],  write_fn),
        ("pg_replica1_read",  CONNECTIONS["pg_replica1"], read_fn),
        ("pg_replica2_read",  CONNECTIONS["pg_replica2"], read_fn),
        ("pg_primary_read",   CONNECTIONS["pg_primary"],  read_fn),
    ]:
        try:
            conn = psycopg2.connect(**cfg)
            conn.autocommit = False
            print(f"  Midiendo {label}...", end=" ", flush=True)
            r = measure_latency(conn, fn, n=200)
            results[label] = r
            print(f"median={r.get('median_ms')} ms")
            conn.close()
        except Exception as e:
            results[label] = {"error": str(e)}
            print(f"ERROR: {e}")

    return results


# ── EXPERIMENTO 2: synchronous_commit ────────────────────────

def exp_replication_impact():
    print("\n[2/4] Experimento: Impacto synchronous_commit")
    results = {}
    modes = ["off", "local", "remote_write", "remote_apply"]

    try:
        conn = psycopg2.connect(**CONNECTIONS["pg_primary"])
        conn.autocommit = False

        for mode in modes:
            # Aplicar el modo en una transaccion separada
            conn.rollback()
            with conn.cursor() as cur:
                cur.execute(f"SET LOCAL synchronous_commit = '{mode}'")

            def fn_mode(c, m=mode):
                with c.cursor() as cur:
                    cur.execute(f"SET LOCAL synchronous_commit = '{m}'")
                    cur.execute(INSERT_SQL, (
                        str(uuid.uuid4()), str(uuid.uuid4()),
                        1000.00, f"sync-{m}"
                    ))
                c.commit()

            print(f"  synchronous_commit={mode}...", end=" ", flush=True)
            r = measure_latency(conn, lambda c, m=mode: fn_mode(c, m), n=100)
            results[f"pg_sync_{mode}"] = r
            print(f"median={r.get('median_ms')} ms")

        conn.close()
    except Exception as e:
        results["error"] = str(e)
        print(f"  ERROR: {e}")

    return results


# ── EXPERIMENTO 3: Lag de replicacion ────────────────────────

def exp_replication_lag():
    print("\n[3/4] Experimento: Lag de replicacion")
    results = {}
    try:
        conn = psycopg2.connect(**CONNECTIONS["pg_primary"])
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    client_addr,
                    sync_state,
                    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS replay_lag,
                    replay_lag AS replay_lag_time
                FROM pg_stat_replication
            """)
            rows = cur.fetchall()
            results["pg_replication_status"] = [
                {"client": str(r[0]), "sync_state": r[1],
                 "lag_size": r[2], "lag_time": str(r[3])}
                for r in rows
            ]
            print(f"  Replicas activas: {len(rows)}")
            for r in rows:
                print(f"    {r[0]} | sync={r[1]} | lag={r[2]}")
        conn.close()
    except Exception as e:
        results["error"] = str(e)
        print(f"  ERROR: {e}")
    return results


# ── EXPERIMENTO 4: Join distribuido ──────────────────────────

def exp_distributed_join():
    print("\n[4/4] Experimento: Join distribuido (EXPLAIN ANALYZE)")
    results = {}

    query = """
        SELECT c.nombre, COUNT(t.tx_id) AS num_tx, SUM(t.monto) AS total
        FROM transacciones_log t
        JOIN cuentas cu ON cu.cuenta_id = t.cuenta_origen
        JOIN clientes c  ON c.cliente_id = cu.cliente_id
        WHERE t.created_at BETWEEN '2024-01-01' AND '2024-06-30'
        GROUP BY c.cliente_id, c.nombre
        ORDER BY total DESC
        LIMIT 10
    """

    for db_label, cfg in [("postgres", CONNECTIONS["pg_primary"])]:
        try:
            conn = psycopg2.connect(**cfg)
            conn.autocommit = True
            t0 = time.perf_counter()
            with conn.cursor() as cur:
                cur.execute(f"EXPLAIN (ANALYZE, BUFFERS) {query}")
                plan = "\n".join(r[0] for r in cur.fetchall())
            elapsed = (time.perf_counter() - t0) * 1000
            results[db_label] = {"elapsed_ms": round(elapsed, 2), "plan": plan[:3000]}
            print(f"  {db_label}: {elapsed:.1f} ms")
            print(f"\n--- PLAN ---\n{plan}\n--- FIN ---")
            conn.close()
        except Exception as e:
            results[db_label] = {"error": str(e)}
            print(f"  {db_label} ERROR: {e}")

    return results


# ── RUNNER ────────────────────────────────────────────────────

def run_all():
    all_results = {
        "timestamp":        datetime.now().isoformat(),
        "latency":          exp_latency_write_read(),
        "replication":      exp_replication_impact(),
        "lag":              exp_replication_lag(),
        "distributed_join": exp_distributed_join(),
    }
    import os
    os.makedirs("../docs", exist_ok=True)
    with open(RESULTS_FILE, "w") as f:
        json.dump(all_results, f, indent=2, default=str)
    print(f"\n[OK] Resultados guardados en {RESULTS_FILE}")
    return all_results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--experiment",
        choices=["all", "latency", "replication", "lag", "join"], default="all")
    args = parser.parse_args()

    if args.experiment == "all":
        run_all()
    elif args.experiment == "latency":
        print(json.dumps(exp_latency_write_read(), indent=2, default=str))
    elif args.experiment == "replication":
        print(json.dumps(exp_replication_impact(), indent=2, default=str))
    elif args.experiment == "lag":
        print(json.dumps(exp_replication_lag(), indent=2, default=str))
    elif args.experiment == "join":
        print(json.dumps(exp_distributed_join(), indent=2, default=str))
