# RetailCO — Sistema de Business Intelligence
### SI3009 Bases de Datos Avanzadas · Universidad EAFIT · 2026-1

> Sistema completo de BI para una cadena de retail colombiana: OLTP normalizado, pipeline ETL en T-SQL, Data Warehouse dimensional y dashboard interactivo en Power BI.

---

## Demo y Tablero

| Recurso | Enlace |
|---|---|
| Video de sustentación | [Ver en YouTube](https://youtu.be/JJIgKqyDjDE) |
| Dashboard Power BI | [Abrir tablero](https://app.powerbi.com/view?r=eyJrIjoiZGZjMmRjZTUtNjk0OS00ZDdkLThiNjEtNGIyNTQ3MDA2M2ViIiwidCI6Ijk5ZjdiNTVlLTljYmUtNDY3Yi04MTQzLTkxOTc4MjkxOGFmYiIsImMiOjR9) |

---

## Acceso al Servidor Azure

La base de datos está desplegada en una VM de Azure con SQL Server 2022 Developer Edition.

```
Servidor (SSMS):   20.83.224.24,1433
Usuario:           proyectoprof
Contraseña:        ProyectoBIProf2026!
Autenticación:     SQL Server Authentication
```

> **Conexión desde SSMS:** Servidor → `20.83.224.24,1433` · Auth → SQL Server · Usuario/contraseña como se indica arriba.

### Bases de datos disponibles

| Base de datos | Descripción |
|---|---|
| `RetailCO_OLTP` | Transaccional — 16 tablas, ~50K ventas |
| `BI_Staging` | Staging del ETL — 7 tablas intermedias |
| `RetailCO_DW` | Data Warehouse — 9 dims, 5 facts |

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│  Azure VM · Standard_D2als_v7 · West US 2 · SQL Server 2022    │
│                                                                  │
│  RetailCO_OLTP ──Extract──► BI_Staging ──Load──► RetailCO_DW   │
│  (16 tablas)   13 Stored Procs (ETL_Log)         (Estrella)    │
└─────────────────────────────────────────────────────────────────┘
                                                        │
                                             Power BI Desktop
                                                        │
                                         app.powerbi.com (público)
```

---

## Archivos del Proyecto

| Archivo | Descripción |
|---|---|
| `01_OLTP_Creacion.sql` | Crea `RetailCO_OLTP` con 16 tablas normalizadas 3FN |
| `02_OLTP_DatosSinteticos.sql` | Genera ~50K ventas, 1K clientes, 200 productos |
| `03_DW_Creacion.sql` | Crea `RetailCO_DW` — 9 dimensiones + 5 tablas de hechos |
| `04_ETL_Completo_CORREGIDO.sql` | Pipeline ETL completo con 13 stored procedures |
| `05_DAX_Medidas_CORREGIDO.dax` | 37 medidas DAX para Power BI |
| `06a_Fuente_Metas_Mensuales.csv` | Fuente externa: metas comerciales por tienda |
| `06b_Fuente_InventarioFisico.csv` | Fuente externa: conteo físico de inventario |
| `07_Informe_Tecnico_FINAL.pdf` | Informe técnico completo |
| `08_Diccionario_Datos.pdf` | Diccionario de datos de las 3 BDs |
| `09_Proyecto_Final.pbix` | Dashboard Power BI — 6 páginas completas |

---

## Orden de Ejecución en SQL Server

```sql
-- 1. Crear estructura OLTP
01_OLTP_Creacion.sql

-- 2. Poblar con datos sintéticos (~10-15 min)
02_OLTP_DatosSinteticos.sql

-- 3. Crear Data Warehouse
03_DW_Creacion.sql

-- 4. Ejecutar pipeline ETL completo
04_ETL_Completo_CORREGIDO.sql
-- Crea BI_Staging, los 13 stored procedures
-- y ejecuta usp_EjecutarETL_Completo automáticamente
```

---

## Modelo Dimensional

**Esquema estrella** con datos desnormalizados en dimensiones para optimizar consultas DAX.

**Dimensiones (9):** `DimFecha` · `DimCliente` · `DimProducto` · `DimTienda` · `DimVendedor` · `DimCanalVenta` · `DimProveedor` · `DimPromocion` · `DimGeografia`

**Tablas de hechos (5):**

| Fact | Granularidad | Registros |
|---|---|---|
| `FactVentas` | Línea de detalle de venta | 174.814 |
| `FactInventarioDiario` | Producto × Tienda × Día | 718.000 |
| `FactMetasComerciales` | Tienda × Mes | 1.200 |
| `FactDevoluciones` | Devolución individual | ~2.000 |
| `FactCompras` | Línea de orden de compra | ~15.000 |

**SCD Tipo 2** implementado en `DimCliente` y `DimProducto` con columnas `FechaInicioVigencia`, `FechaFinVigencia` y `EsVersionActual`.

---

## Dashboard Power BI

6 páginas interactivas construidas sobre `RetailCO_DW`:

1. **Dashboard Ejecutivo** — KPIs: ventas totales, utilidad bruta, margen, cumplimiento de metas
2. **Análisis de Ventas** — Por fecha, categoría, tienda, vendedor y canal
3. **Inventario** — Stock actual, rotación, días disponibles, productos con bajo stock
4. **Rentabilidad** — Ingresos vs costos, margen por producto y por tienda
5. **Cumplimiento de Metas** — Ventas reales vs meta, brecha, semáforo de desempeño
6. **Exploración OLAP** — Drill-down año → trimestre → mes → día, slice por región y categoría

**37 medidas DAX** incluyendo Time Intelligence (YTD, MTD, año anterior), rankings, participación y métricas de inventario.

---

## ETL — Pipeline de Datos

El ETL se ejecuta completamente desde `usp_EjecutarETL_Completo`:

```
usp_CargarDimCanalVenta  →  usp_CargarDimFecha  →  usp_ExtractToStaging
→  usp_ValidarCalidadDatos  →  usp_CargarDimCliente  →  usp_CargarDimProducto
→  usp_CargarDimTiendaVendedor  →  usp_CargarFactVentas  →  usp_CargarFactInventario
→  usp_CargarFactMetas  →  usp_CargarFactDevoluciones  →  usp_CargarFactCompras
```

Cada ejecución queda registrada en `RetailCO_DW.dbo.ETL_Log` con estado, tiempos y conteos.

---

## Verificar resultados en el servidor

```sql
-- Conteos OLTP
USE RetailCO_OLTP;
SELECT 'Clientes'        AS Tabla, COUNT(*) AS N FROM Clientes      UNION ALL
SELECT 'Ventas',                   COUNT(*)       FROM Ventas        UNION ALL
SELECT 'DetalleVentas',            COUNT(*)       FROM DetalleVentas UNION ALL
SELECT 'InventarioDiario',         COUNT(*)       FROM InventarioDiario;

-- Conteos DW
USE RetailCO_DW;
SELECT 'FactVentas'           AS Tabla, COUNT(*) AS N FROM FactVentas            UNION ALL
SELECT 'FactInventarioDiario',          COUNT(*)       FROM FactInventarioDiario UNION ALL
SELECT 'FactMetasComerciales',          COUNT(*)       FROM FactMetasComerciales UNION ALL
SELECT 'DimCliente',                    COUNT(*)       FROM DimCliente           UNION ALL
SELECT 'DimFecha',                      COUNT(*)       FROM DimFecha;

-- Log del ETL
SELECT NombreProceso, Estado, RegistrosCargados,
       DATEDIFF(SECOND, FechaInicio, FechaFin) AS Segundos
FROM ETL_Log ORDER BY LogID DESC;
```

---

## Equipo

| Nombre | Rol |
|---|---|
| Cesar Augusto Montoya Giraldo | SQL Server · Azure · ETL · Infraestructura |
| Juan Pablo Corena | Power BI · DAX · Dashboard |

---


---

*SI3009 — Bases de Datos Avanzadas · Universidad EAFIT · Mayo 2026*
