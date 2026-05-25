# Bases de Datos Avanzadas - Universidad EAFIT

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![CockroachDB](https://img.shields.io/badge/CockroachDB-6933FF?style=for-the-badge&logo=cockroachdb&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

Bienvenido al repositorio oficial del curso **Bases de Datos Avanzadas** (2026) de la Universidad EAFIT.  
Este espacio documenta y almacena todos los proyectos prácticos, scripts y análisis desarrollados a lo largo del semestre académico en la trayectoria de Ingeniería de Sistemas.

## Equipo de Trabajo

* **Cesar Montoya Giraldo** - [CesarMontoyag1](https://github.com/CesarMontoyag1)
* **Juan Pablo Corena** - [JP-2112](https://github.com/JP-2112)

**Docente:** Edwin Montoya Múnera

---

## Proyectos del Curso

A continuación, se presenta el listado de proyectos desarrollados. Cada carpeta contiene su propia documentación detallada para la replicación de los entornos y los informes técnicos correspondientes.

| Proyecto | Descripción | Estado | Enlace |
| :--- | :--- | :---: | :--- |
| **Proyecto 1** | Caso de estudio: Optimización, Performance Tuning y manejo de Big Data (30M+ registros). | ✅ Completado | [Ir al Proyecto 1](./proyecto1/) |
| **Proyecto 2** | Arquitecturas Distribuidas: Escalabilidad, Replicación, Consistencia y Transacciones Distribuidas sobre dominio bancario. Comparativa PostgreSQL 16 vs CockroachDB v23.2. | ✅ Completado | [Ir al Proyecto 2](./proyecto2/) |
| **Proyecto 3** | Sistema de Business Intelligence completo: OLTP normalizado, pipeline ETL en T-SQL, Data Warehouse dimensional (estrella) y dashboard Power BI desplegados en Azure. | ✅ Completado | [Ir al Proyecto 3](./proyecto3/) |

---

## Proyecto 2 — Resumen ejecutivo

El Proyecto 2 aborda los grandes retos de las bases de datos distribuidas modernas en un contexto bancario real: **¿cómo mantener la integridad ACID cuando los datos están físicamente distribuidos en múltiples nodos?**

Se diseñó e implementó una plataforma de banca digital con transferencias entre cuentas, particionamiento horizontal y replicación activa, comparando el esfuerzo manual requerido en **PostgreSQL 16** (motor clásico) contra la distribución nativa de **CockroachDB v23.2** (NewSQL).

### Tecnologías utilizadas

| Componente | Tecnología |
| :--- | :--- |
| Motor SQL clásico | PostgreSQL 16 |
| Motor NewSQL | CockroachDB v23.2 |
| Infraestructura | Docker Compose sobre EC2 t3.medium (AWS Academy) |
| Generación de datos | Python 3 + Faker (500K transacciones sintéticas) |
| Connection pooling | PgBouncer |

### Resultados clave obtenidos

| Métrica | PostgreSQL | CockroachDB |
| :--- | :--- | :--- |
| Latencia escritura (median) | **1.9 ms** | ~10-15 ms (consenso Raft) |
| Latencia lectura réplica (median) | **4.37 ms** | ~4-8 ms |
| Lag de replicación | **0 bytes / ~1 ms** | Implícito en quórum |
| Join distribuido (2 particiones) | **81.5 ms** | Distribuido en paralelo |
| Failover | Manual (~15-30s) | **Automático (~4s)** |
| Escrituras con sync_commit=off | **0.86 ms** | N/A |
| Escrituras con sync_commit=local | **2.22 ms** | N/A |

---

## Proyecto 3 — Resumen ejecutivo
 
El Proyecto 3 implementa un sistema completo de Business Intelligence para **RetailCO**, una cadena de retail colombiana ficticia con 10 tiendas a nivel nacional: **¿cómo transformar datos transaccionales dispersos en información estratégica accionable para la gerencia?**
 
Se construyó una arquitectura de tres capas sobre una VM en Azure: base OLTP normalizada en 3FN, un pipeline ETL en T-SQL con validación de calidad, y un Data Warehouse en esquema estrella. El resultado es un dashboard interactivo en Power BI con 6 páginas y 37 medidas DAX publicado en la nube.
 
### Tecnologías utilizadas
 
| Componente | Tecnología |
| :--- | :--- |
| Motor de base de datos | SQL Server 2022 Developer Edition |
| Infraestructura | Azure VM Standard_D2als_v7 (West US 2) |
| ETL | T-SQL Stored Procedures (13 procedimientos) |
| Visualización | Power BI Desktop + Power BI Service |
 
### Acceso al servidor
 
| Parámetro | Valor |
| :--- | :--- |
| Servidor (SSMS) | `20.83.224.24,1433` |
| Usuario | `proyectoprof` |
| Contraseña | `ProyectoBIProf2026!` |
| Autenticación | SQL Server Authentication |
 
### Resultados clave obtenidos
 
| Entregable | Detalle |
| :--- | :--- |
| [Dashboard Power BI](https://app.powerbi.com/view?r=eyJrIjoiZGZjMmRjZTUtNjk0OS00ZDdkLThiNjEtNGIyNTQ3MDA2M2ViIiwidCI6Ijk5ZjdiNTVlLTljYmUtNDY3Yi04MTQzLTkxOTc4MjkxOGFmYiIsImMiOjR9) | 6 páginas · 37 medidas DAX |
| [Video de sustentación](https://youtu.be/JJIgKqyDjDE) | Demostración completa del sistema |
| FactVentas | 174.814 filas cargadas vía ETL |
| FactInventarioDiario | 718.000 filas (365 días × 200 prod × 10 tiendas) |
| FactMetasComerciales | 1.200 filas — 12 meses × 10 tiendas |
| Staging extraído | 895.651 registros procesados |
 
---

> **Nota:** Este repositorio está diseñado bajo prácticas de DevOps para facilitar la lectura y replicación de los laboratorios por parte del equipo docente y otros desarrolladores.
