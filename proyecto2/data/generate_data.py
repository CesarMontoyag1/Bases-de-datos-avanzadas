#!/usr/bin/env python3
"""
generate_data.py — Generador de datos sintéticos bancarios
Proyecto 2 SI3009 BDD Avanzadas

Genera clientes, cuentas y transacciones para PostgreSQL y/o CockroachDB.
El schema de ambas BDs es idéntico salvo shard_key (solo PG, con DEFAULT 0).

Uso:
    pip install faker psycopg2-binary tqdm
    python generate_data.py --target postgres  --clientes 5000 --rows 200000
    python generate_data.py --target cockroach --clientes 5000 --rows 200000
    python generate_data.py --target both      --clientes 5000 --rows 200000
"""

import argparse
import random
import re
import uuid
from datetime import datetime, timedelta

import time
import psycopg2
from psycopg2.extras import execute_batch
from faker import Faker
from tqdm import tqdm

# ── Conexiones ────────────────────────────────────────────────
PG_CONFIG = {
    "host": "localhost", "port": 5432,
    "dbname": "banco_db", "user": "banco_admin", "password": "banco_pass",
}
CRDB_CONFIG = {
    "host": "localhost", "port": 26257,
    "dbname": "banco_db", "user": "banco_admin",
    "sslmode": "disable",
}

TIPOS_TX    = ["deposito", "retiro", "transferencia", "pago"]
TIPOS_PESOS = [0.25, 0.20, 0.40, 0.15]
TIPOS_CUENTA = ["ahorros", "corriente", "credito"]
ESTADOS = ["completado", "completado", "completado", "fallido", "revertido"]
PAISES  = ["CO", "MX", "PE", "AR", "CL"]

fake = Faker("es_CO")
Faker.seed(42)
random.seed(42)


def ascii_safe(text: str) -> str:
    """Elimina caracteres no-ASCII que pueden romper psycopg2 en algunos locales."""
    return re.sub(r"[^\x00-\x7F]+", " ", text).strip()


# ── Generadores ───────────────────────────────────────────────

def generate_clientes(n: int) -> list:
    clientes = []
    emails = set()
    for _ in range(n):
        email = fake.unique.email()
        while email in emails:
            email = fake.unique.email()
        emails.add(email)
        clientes.append({
            "cliente_id": str(uuid.uuid4()),
            "nombre":     ascii_safe(fake.name()),
            "email":      email,
            "pais":       random.choice(PAISES),
            "created_at": fake.date_time_between(start_date="-3y", end_date="-1y"),
            "activo":     random.random() > 0.05,
        })
    return clientes


def generate_cuentas(clientes: list) -> list:
    """
    Genera cuentas SIN shard_key — esa columna tiene DEFAULT 0 en PG
    y no existe en CRDB. insert_batch la omite automáticamente.
    """
    cuentas = []
    for c in clientes:
        n_cuentas = random.choices([1, 2, 3], weights=[0.6, 0.3, 0.1])[0]
        for _ in range(n_cuentas):
            cuentas.append({
                "cuenta_id":   str(uuid.uuid4()),
                "cliente_id":  c["cliente_id"],
                "tipo_cuenta": random.choice(TIPOS_CUENTA),
                "saldo":       round(random.uniform(0, 50_000_000), 2),
                "moneda":      "COP",
                "created_at":  fake.date_time_between(start_date="-2y", end_date="-6M"),
                "activo":      random.random() > 0.03,
                # updated_at se omite — DEFAULT now() lo llena en ambas BDs
            })
    return cuentas


def generate_transacciones(cuentas: list, n: int) -> list:
    cuenta_ids  = [c["cuenta_id"] for c in cuentas]
    start_date  = datetime(2024, 1, 1)
    end_date    = datetime(2025, 6, 30)
    delta_days  = (end_date - start_date).days
    txs = []
    for _ in range(n):
        tipo    = random.choices(TIPOS_TX, weights=TIPOS_PESOS)[0]
        origen  = random.choice(cuenta_ids)
        destino = random.choice(cuenta_ids) if tipo == "transferencia" else None
        if destino == origen:
            destino = None
        ts = start_date + timedelta(
            days=random.randint(0, delta_days),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59),
            seconds=random.randint(0, 59),
        )
        txs.append({
            "tx_id":         str(uuid.uuid4()),
            "cuenta_origen": origen,
            "cuenta_dest":   destino,
            "tipo_tx":       tipo,
            "monto":         round(random.uniform(1_000, 5_000_000), 2),
            "estado":        random.choice(ESTADOS),
            "nodo_origen":   f"node-{random.randint(1, 3)}",
            "created_at":    ts,
            "updated_at":    ts,
        })
    return txs


# ── Inserción por lotes ───────────────────────────────────────

def insert_batch(db_config: dict, table: str, rows: list, batch_size: int = 50):
    """
    Reconecta en cada batch para evitar que CRDB cierre conexiones largas.
    batch_size=50 es conservador pero estable para CRDB en modo insecure.
    """
    if not rows:
        return
    cols         = list(rows[0].keys())
    placeholders = ", ".join([f"%({c})s" for c in cols])
    sql = (
        f"INSERT INTO {table} ({', '.join(cols)}) "
        f"VALUES ({placeholders}) ON CONFLICT DO NOTHING"
    )
    for i in tqdm(range(0, len(rows), batch_size),
                  desc=f"  → {table}", unit="batch"):
        retries = 0
        while retries < 5:
            try:
                conn = psycopg2.connect(**db_config)
                conn.autocommit = False
                with conn.cursor() as cur:
                    execute_batch(cur, sql, rows[i:i + batch_size], page_size=batch_size)
                conn.commit()
                conn.close()
                break
            except Exception:
                try:
                    conn.close()
                except Exception:
                    pass
                retries += 1
                if retries == 5:
                    raise
                time.sleep(2 ** retries)


# ── Carga principal ───────────────────────────────────────────

def load_data(db_config: dict, n_clientes: int, n_txs: int, label: str):
    print(f"\n{'='*60}")
    print(f"  Cargando datos en {label}")
    print(f"  Clientes: {n_clientes:,}  |  Transacciones: {n_txs:,}")
    print(f"{'='*60}")

    print("Generando clientes...")
    clientes = generate_clientes(n_clientes)

    print("Generando cuentas...")
    cuentas = generate_cuentas(clientes)
    print(f"  → {len(cuentas):,} cuentas generadas")

    print("Generando transacciones...")
    txs = generate_transacciones(cuentas, n_txs)
    print(f"  → {len(txs):,} transacciones generadas")

    print("\nInsertando en BD...")
    insert_batch(db_config, "clientes",          clientes)
    insert_batch(db_config, "cuentas",           cuentas)
    insert_batch(db_config, "transacciones_log", txs)
    print(f"\n✓ {label}: carga completada")


# ── Entry point ───────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generador de datos bancarios")
    parser.add_argument(
        "--target", choices=["postgres", "cockroach", "both"], default="both"
    )
    parser.add_argument("--rows",     type=int, default=500_000,
                        help="Número de transacciones a generar")
    parser.add_argument("--clientes", type=int, default=10_000,
                        help="Número de clientes a generar")
    args = parser.parse_args()

    if args.target in ("postgres", "both"):
        load_data(PG_CONFIG, args.clientes, args.rows, "PostgreSQL")

    if args.target in ("cockroach", "both"):
        load_data(CRDB_CONFIG, args.clientes, args.rows, "CockroachDB")

    print("\n✓ Generación completada.")
