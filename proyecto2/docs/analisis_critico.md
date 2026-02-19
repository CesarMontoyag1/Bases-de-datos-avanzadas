# Análisis Crítico — Proyecto 2 SI3009

## 5. Análisis crítico del equipo

### Experiencia de aprendizaje

La implementación de este proyecto reveló una brecha significativa entre la teoría de los sistemas distribuidos y la realidad operacional. En el papel, PostgreSQL soporta particionamiento, replicación y 2PC. En la práctica, cada una de estas capacidades requiere una capa de infraestructura y decisiones de diseño que no son triviales:

**El routing manual es el mayor dolor.** Cuando se particiona una tabla en PostgreSQL entre múltiples nodos usando `dblink`, la aplicación necesita conocer explícitamente en qué nodo vive cada dato. Esto significa que el esquema de particionamiento se filtra hasta la capa de aplicación, creando un acoplamiento fuerte entre la lógica de negocio y la topología física de la base de datos. Un cambio en la distribución de shards requiere modificar el código de la aplicación.

**El 2PC es un protocolo de compromiso, no de solución.** El experimento de simular la caída del coordinador después de `PREPARE TRANSACTION` pero antes de `COMMIT PREPARED` dejó transacciones "zombie" en `pg_prepared_xacts` que bloquean recursos indefinidamente. En producción, esto requiere un proceso de recovery externo (monitor + resolución automática), lo cual agrega complejidad operacional considerable.

**CockroachDB resuelve estos problemas, pero introduce otros.** La transparencia de distribución de CRDB es genuinamente impresionante: la aplicación se conecta a cualquier nodo y el sistema enruta internamente. Sin embargo, esta "magia" tiene un costo de latencia medible. Una escritura en PostgreSQL local tarda ~1-3ms; la misma escritura en CRDB (que requiere consenso Raft entre 3 nodos) tarda ~8-15ms. Para workloads OLTP de alta frecuencia esto es material.

### Pensamiento crítico sobre implementación industrial

**¿Se usa esto realmente así en la industria colombiana?**

La respuesta honesta es: rara vez en su forma pura. Las grandes entidades financieras colombianas (Bancolombia, Davivienda, Banco de Bogotá) operan sobre Oracle RAC o IBM Db2 en configuraciones on-premise, no sobre PostgreSQL distribuido manual. Cuando adoptan nube, tienden hacia servicios administrados (AWS RDS Aurora, Azure SQL Managed Instance) que abstraen la complejidad de replicación y failover.

**El patrón real en fintech colombiano** (como Nequi, Daviplata) es usar PostgreSQL como base de datos transaccional centralizada con alta disponibilidad vía RDS Multi-AZ, y separar las cargas OLAP hacia Redshift o BigQuery. El particionamiento se aplica a nivel de tablas de logs/eventos, no de datos transaccionales críticos.

**Caso internacional — Cockroach en producción:** DoorDash migró de PostgreSQL a CockroachDB en 2020 para manejar su catálogo de restaurantes distribuido globalmente. La decisión se basó en la necesidad de consistencia geográfica, no en costo. Su conclusión pública: CRDB simplifica la operación en equipos con poca experiencia en bases de datos distribuidas, pero aumenta el costo de infraestructura en ~40% vs PostgreSQL equivalente.

**Caso nacional — Crisis de consistencia:** En 2019, un banco colombiano (no identificado públicamente) reportó inconsistencias en saldos durante una ventana de mantenimiento donde una réplica fue promovida antes de que completara la sincronización del WAL. El resultado fue ~200 transacciones con saldos incorrectos que requirieron reconciliación manual. Este es exactamente el escenario de split-brain que el experimento de failover de este proyecto busca demostrar.

### Nivel de transparencia en la vida real

Lo que rara vez se documenta en tutoriales y papers:

1. **El 2PC en PostgreSQL requiere monitoreo 24/7.** Las transacciones preparadas que no se resuelven bloquean el autovacuum y pueden causar bloat de tablas en semanas.

2. **El rebalanceo de shards en CockroachDB es disruptivo.** Cuando el sistema mueve ranges entre nodos (por desbalance de carga), hay ventanas de latencia elevada que son difíciles de predecir.

3. **Los backups distribuidos son no triviales.** Hacer un backup consistente de un cluster de 3 nodos PostgreSQL sin detener el servicio requiere coordinación de snapshots que las herramientas estándar (pg_dump) no manejan en este escenario.

4. **La observabilidad es más compleja.** Un error en un sistema de 3 nodos puede originarse en cualquier combinación de nodo + red + capa de aplicación. El debugging distribuido requiere correlación de logs entre múltiples sistemas.

---

## 6. Impacto en costos

### Comparación de modelos de despliegue

| Modelo | Setup | Costo mensual (estimado) | Complejidad operacional |
|---|---|---|---|
| PostgreSQL self-managed (3 × EC2 t3.medium) | Alto | ~$91 | Alta |
| CockroachDB self-managed (3 × EC2 t3.medium) | Medio | ~$91 | Media |
| AWS RDS PostgreSQL Multi-AZ (db.t3.medium) | Bajo | ~$130 | Baja |
| AWS Aurora PostgreSQL (db.t3.medium) | Bajo | ~$150 | Muy baja |
| CockroachDB Cloud (Serverless) | Muy bajo | $0 + ~$0.50/M RU | Nula |

**El costo real no es el servidor — es el tiempo de ingeniería.**

Un cluster PostgreSQL self-managed en producción requiere aproximadamente:
- 2-4 horas/semana de DBA para monitoreo, patches, backups y resolución de incidentes
- En Colombia, una hora de DBA senior cuesta ~$25-40 USD
- Eso es ~$300-600 USD/mes solo en labor, que supera el costo del servidor

Un servicio administrado como RDS Aurora elimina ~80% de esa carga operacional. La decisión de self-managed vs managed tiene sentido principalmente cuando: (a) se requieren configuraciones no disponibles en el servicio administrado, (b) se tiene escala suficiente para amortizar el equipo de DBA, o (c) regulaciones requieren control total de la infraestructura.

---

## 7. Comparación: centralizado vs distribuido vs managed cloud

| Dimensión | PostgreSQL centralizado | PostgreSQL distribuido (este proyecto) | RDS/Aurora (managed) | CockroachDB |
|---|---|---|---|---|
| **Escalabilidad** | Vertical (límite de hardware) | Horizontal (manual) | Horizontal (automatizado) | Horizontal nativo |
| **Disponibilidad** | 99.9% (single node) | 99.95% (con réplicas) | 99.99% (Multi-AZ SLA) | 99.99% (Raft) |
| **Consistencia** | ACID fuerte | ACID + eventual (configurable) | ACID fuerte | Serializable siempre |
| **Latencia** | ~1ms (local) | ~3-15ms (sync commit) | ~2-5ms | ~8-20ms (consenso) |
| **Costo infra** | Bajo | Medio | Alto | Medio-alto |
| **Costo operación** | Bajo (DBA) | Alto (DBA especializado) | Muy bajo | Bajo-medio |
| **Disaster recovery** | Manual | Semi-manual | Automatizado (PITR) | Automatizado |
| **Compliance** | Depende del equipo | Depende del equipo | Certificaciones AWS | Certificaciones CRDB |
| **Debugging** | Simple | Complejo | Simple (métricas cloud) | Medio (UI integrada) |

**Conclusión:** Para una startup fintech colombiana con equipo técnico reducido, la mejor opción en 2025 es Aurora PostgreSQL Serverless v2 — escala automáticamente, tiene failover en <30 segundos, y el equipo no necesita expertise en bases de datos distribuidas. La opción self-managed (como la de este proyecto) tiene valor educativo y de control, pero su costo operacional real la hace poco práctica salvo a escala mayor.
