# SI3009 - Proyecto 3: Sistema BI RetailCO
**Bases de Datos Avanzadas | Universidad EAFIT | Mayo 2026**

---

## Descripción
Sistema completo de Business Intelligence para RetailCO, cadena de retail colombiana con 10 tiendas. Incluye OLTP, Data Warehouse, pipeline ETL y dashboard Power BI.

---

## Estructura de Archivos

| Archivo | Descripción |
|---|---|
| `01_OLTP_Creacion.sql` | Base de datos transaccional (16 tablas, 3FN) |
| `02_OLTP_DatosSinteticos.sql` | Datos sintéticos (~50K ventas, 1K clientes) |
| `03_DW_Creacion.sql` | Data Warehouse dimensional (9 dims, 5 facts) |
| `04_ETL_Completo_CORREGIDO.sql` | Pipeline ETL con 13 stored procedures |
| `05_DAX_Medidas_CORREGIDO.dax` | 37 medidas DAX para Power BI |
| `06a_Fuente_Metas_Mensuales.csv` | Fuente externa: metas por tienda |
| `06b_Fuente_InventarioFisico.csv` | Fuente externa: conteo físico de inventario |
| `Proyecto_Final.pbix` | Dashboard Power BI (6 páginas) |
| `07_Informe_Tecnico_ACTUALIZADO.docx` | Informe técnico completo |
| `08_Diccionario_Datos.docx` | Diccionario de datos |
| `09_Guia_PowerBI.docx` | Guía de uso del dashboard |

---

## Orden de Ejecución en SQL Server

```
1. 01_OLTP_Creacion.sql          → Crea RetailCO_OLTP
2. 02_OLTP_DatosSinteticos.sql   → Llena OLTP (~10-15 min)
3. 03_DW_Creacion.sql            → Crea RetailCO_DW
4. 04_ETL_Completo_CORREGIDO.sql → Crea BI_Staging + ETL + ejecuta pipeline
```

---

## Conexión al Servidor Azure

| Campo | Valor |
|---|---|
| IP Pública | `20.83.224.24` |
| Puerto | `1433` |
| Usuario | `proyectoprof` |
| Contraseña | `ProyectoBIProf2026!` |
| OLTP | `RetailCO_OLTP` |
| DW | `RetailCO_DW` |

---

## Dashboard Power BI
- **URL:** [Pendiente de publicación en app.powerbi.com]
- **Páginas:** Dashboard Ejecutivo, Análisis Ventas, Inventario, Rentabilidad, Cumplimiento Metas, Exploración OLAP

---

## Resultados del ETL

| Tabla | Registros |
|---|---|
| FactVentas | 174.814 |
| FactInventarioDiario | 718.000 |
| FactMetasComerciales | 1.200 |
| DimFecha | 4.018 |
| DimCliente | 1.001 |
| DimVendedor | 20 |
