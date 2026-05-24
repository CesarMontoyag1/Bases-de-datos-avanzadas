-- ============================================================
-- SI3009 Bases de Datos Avanzadas - Proyecto 3
-- SCRIPT 03: Creación del Data Warehouse Dimensional
-- Modelo en estrella | Base: RetailCO_DW
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RetailCO_DW')
    DROP DATABASE RetailCO_DW;
GO

CREATE DATABASE RetailCO_DW;
GO

USE RetailCO_DW;
GO

-- ============================================================
-- DIMENSIONES
-- ============================================================

-- DIM FECHA (poblada manualmente, clave de negocio = fecha)
CREATE TABLE DimFecha (
    FechaKey        INT PRIMARY KEY,           -- YYYYMMDD, surrogate natural
    Fecha           DATE NOT NULL,
    Dia             INT NOT NULL,
    NombreDia       VARCHAR(15) NOT NULL,
    Semana          INT NOT NULL,
    Mes             INT NOT NULL,
    NombreMes       VARCHAR(15) NOT NULL,
    Trimestre       INT NOT NULL,
    NombreTrimestre VARCHAR(10) NOT NULL,
    Semestre        INT NOT NULL,
    Anio            INT NOT NULL,
    EsFestivo       BIT NOT NULL DEFAULT 0,
    EsFinDeSemana   BIT NOT NULL DEFAULT 0,
    CONSTRAINT UQ_DimFecha_Fecha UNIQUE (Fecha)
);

-- DIM GEOGRAFÍA
CREATE TABLE DimGeografia (
    GeografiaKey INT IDENTITY(1,1) PRIMARY KEY,
    GeografiaID  INT NOT NULL,              -- clave de negocio (OLTP)
    Ciudad       VARCHAR(80) NOT NULL,
    Departamento VARCHAR(80) NOT NULL,
    Region       VARCHAR(60) NOT NULL,
    Pais         VARCHAR(60) NOT NULL DEFAULT 'Colombia',
    CONSTRAINT UQ_DimGeo_ID UNIQUE (GeografiaID)
);

-- DIM TIENDA
CREATE TABLE DimTienda (
    TiendaKey    INT IDENTITY(1,1) PRIMARY KEY,
    TiendaID     INT NOT NULL,              -- clave de negocio
    CodigoTienda VARCHAR(20) NOT NULL,
    NombreTienda VARCHAR(100) NOT NULL,
    Ciudad       VARCHAR(80) NOT NULL,
    Departamento VARCHAR(80) NOT NULL,
    Region       VARCHAR(60) NOT NULL,
    Direccion    VARCHAR(200),
    FechaApertura DATE,
    Activa       BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_DimTienda_ID UNIQUE (TiendaID)
);

-- DIM CLIENTE (SCD Tipo 2 - registra cambio de segmento)
CREATE TABLE DimCliente (
    ClienteKey    INT IDENTITY(1,1) PRIMARY KEY,
    ClienteID     INT NOT NULL,             -- clave de negocio
    Cedula        VARCHAR(20) NOT NULL,
    NombreCompleto VARCHAR(160) NOT NULL,
    Genero        CHAR(1),
    Ciudad        VARCHAR(80),
    Departamento  VARCHAR(80),
    Segmento      VARCHAR(40) NOT NULL,
    -- SCD Tipo 2
    FechaInicioVigencia DATE NOT NULL DEFAULT '2000-01-01',
    FechaFinVigencia    DATE NOT NULL DEFAULT '9999-12-31',
    EsVersionActual     BIT NOT NULL DEFAULT 1
);

-- DIM PRODUCTO (SCD Tipo 2 - registra cambio de precio)
CREATE TABLE DimProducto (
    ProductoKey   INT IDENTITY(1,1) PRIMARY KEY,
    ProductoID    INT NOT NULL,             -- clave de negocio
    CodigoSKU     VARCHAR(30) NOT NULL,
    NombreProducto VARCHAR(150) NOT NULL,
    Categoria     VARCHAR(100) NOT NULL,
    Proveedor     VARCHAR(150) NOT NULL,
    PrecioUnitario DECIMAL(12,2) NOT NULL,
    CostoUnitario  DECIMAL(12,2) NOT NULL,
    MargenBruto   AS (PrecioUnitario - CostoUnitario),
    MargenBrutoPct AS (CASE WHEN PrecioUnitario > 0 THEN (PrecioUnitario - CostoUnitario) / PrecioUnitario * 100 ELSE 0 END),
    -- SCD Tipo 2
    FechaInicioVigencia DATE NOT NULL DEFAULT '2000-01-01',
    FechaFinVigencia    DATE NOT NULL DEFAULT '9999-12-31',
    EsVersionActual     BIT NOT NULL DEFAULT 1
);

-- DIM VENDEDOR
CREATE TABLE DimVendedor (
    VendedorKey   INT IDENTITY(1,1) PRIMARY KEY,
    VendedorID    INT NOT NULL,
    Cedula        VARCHAR(20) NOT NULL,
    NombreCompleto VARCHAR(160) NOT NULL,
    Cargo         VARCHAR(60) NOT NULL,
    NombreTienda  VARCHAR(100) NOT NULL,
    FechaIngreso  DATE,
    Activo        BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_DimVendedor_ID UNIQUE (VendedorID)
);

-- DIM PROVEEDOR
CREATE TABLE DimProveedor (
    ProveedorKey  INT IDENTITY(1,1) PRIMARY KEY,
    ProveedorID   INT NOT NULL,
    NombreEmpresa VARCHAR(150) NOT NULL,
    Ciudad        VARCHAR(80),
    Departamento  VARCHAR(80),
    Activo        BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_DimProveedor_ID UNIQUE (ProveedorID)
);

-- DIM CANAL DE VENTA
CREATE TABLE DimCanalVenta (
    CanalKey      INT IDENTITY(1,1) PRIMARY KEY,
    CanalID       INT NOT NULL,
    NombreCanal   VARCHAR(60) NOT NULL,
    CONSTRAINT UQ_DimCanal_ID UNIQUE (CanalID)
);

-- DIM PROMOCIÓN / CAMPAÑA
CREATE TABLE DimPromocion (
    PromocionKey  INT IDENTITY(1,1) PRIMARY KEY,
    CampanaID     INT,                       -- NULL para fila "Sin Campaña"
    NombreCampana VARCHAR(100) NOT NULL,
    TipoDescuento VARCHAR(20),
    ValorDescuento DECIMAL(8,2),
    FechaInicio   DATE,
    FechaFin      DATE
);
-- Insertar fila especial "Sin campaña"
INSERT INTO DimPromocion (CampanaID, NombreCampana, TipoDescuento, ValorDescuento)
VALUES (NULL, 'Sin Campaña', 'N/A', 0);

-- ============================================================
-- TABLAS DE HECHOS
-- ============================================================

-- FACT VENTAS (granularidad: una línea de venta)
CREATE TABLE FactVentas (
    VentaKey       BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Claves foráneas a dimensiones
    FechaKey       INT NOT NULL,
    ClienteKey     INT NOT NULL,
    ProductoKey    INT NOT NULL,
    TiendaKey      INT NOT NULL,
    VendedorKey    INT NOT NULL,
    CanalKey       INT NOT NULL,
    PromocionKey   INT NOT NULL,
    -- Claves de negocio (para trazabilidad)
    VentaID        INT NOT NULL,
    DetalleID      INT NOT NULL,
    -- Medidas aditivas
    Cantidad        INT NOT NULL,
    PrecioUnitario  DECIMAL(12,2) NOT NULL,
    CostoUnitario   DECIMAL(12,2) NOT NULL,
    ValorDescuento  DECIMAL(12,2) NOT NULL DEFAULT 0,
    ValorVenta      DECIMAL(14,2) NOT NULL,     -- después de descuento
    ValorCosto      DECIMAL(14,2) NOT NULL,     -- Cantidad * CostoUnitario
    UtilidadBruta   DECIMAL(14,2) NOT NULL,     -- ValorVenta - ValorCosto
    -- FK constraints
    CONSTRAINT FK_FV_Fecha    FOREIGN KEY (FechaKey)    REFERENCES DimFecha(FechaKey),
    CONSTRAINT FK_FV_Cliente  FOREIGN KEY (ClienteKey)  REFERENCES DimCliente(ClienteKey),
    CONSTRAINT FK_FV_Producto FOREIGN KEY (ProductoKey) REFERENCES DimProducto(ProductoKey),
    CONSTRAINT FK_FV_Tienda   FOREIGN KEY (TiendaKey)   REFERENCES DimTienda(TiendaKey),
    CONSTRAINT FK_FV_Vendedor FOREIGN KEY (VendedorKey) REFERENCES DimVendedor(VendedorKey),
    CONSTRAINT FK_FV_Canal    FOREIGN KEY (CanalKey)    REFERENCES DimCanalVenta(CanalKey),
    CONSTRAINT FK_FV_Promo    FOREIGN KEY (PromocionKey) REFERENCES DimPromocion(PromocionKey)
);

-- FACT INVENTARIO DIARIO (granularidad: día x producto x tienda)
-- IMPORTANTE: StockFinal es SEMI-ADITIVO (no sumar entre fechas, sí entre tiendas)
CREATE TABLE FactInventarioDiario (
    InventarioKey  BIGINT IDENTITY(1,1) PRIMARY KEY,
    FechaKey       INT NOT NULL,
    ProductoKey    INT NOT NULL,
    TiendaKey      INT NOT NULL,
    -- Medidas
    StockInicial   INT NOT NULL,        -- Semi-aditiva
    Entradas       INT NOT NULL,        -- Aditiva
    Salidas        INT NOT NULL,        -- Aditiva
    Ajustes        INT NOT NULL,        -- Aditiva
    StockFinal     INT NOT NULL,        -- Semi-aditiva (snapshot)
    CostoUnitario  DECIMAL(12,2) NOT NULL,
    ValorInventario AS (StockFinal * CostoUnitario),  -- Semi-aditiva
    CONSTRAINT FK_FID_Fecha    FOREIGN KEY (FechaKey)    REFERENCES DimFecha(FechaKey),
    CONSTRAINT FK_FID_Producto FOREIGN KEY (ProductoKey) REFERENCES DimProducto(ProductoKey),
    CONSTRAINT FK_FID_Tienda   FOREIGN KEY (TiendaKey)   REFERENCES DimTienda(TiendaKey)
);

-- FACT METAS COMERCIALES (granularidad: mes x tienda x categoría)
CREATE TABLE FactMetasComerciales (
    MetaKey        INT IDENTITY(1,1) PRIMARY KEY,
    FechaKey       INT NOT NULL,        -- Primer día del mes
    TiendaKey      INT NOT NULL,
    ProductoKey    INT,                 -- NULL si es meta por categoría general
    CanalKey       INT,
    VendedorKey    INT,
    -- Medidas
    ValorMeta      DECIMAL(14,2) NOT NULL,
    UnidadesMeta   INT,
    -- Referencias OLTP
    MetaID         INT NOT NULL,
    CONSTRAINT FK_FM_Fecha    FOREIGN KEY (FechaKey)    REFERENCES DimFecha(FechaKey),
    CONSTRAINT FK_FM_Tienda   FOREIGN KEY (TiendaKey)   REFERENCES DimTienda(TiendaKey),
    CONSTRAINT FK_FM_Canal    FOREIGN KEY (CanalKey)    REFERENCES DimCanalVenta(CanalKey)
);

-- FACT DEVOLUCIONES (granularidad: línea de devolución)
CREATE TABLE FactDevoluciones (
    DevolucionKey  BIGINT IDENTITY(1,1) PRIMARY KEY,
    FechaKey       INT NOT NULL,
    ProductoKey    INT NOT NULL,
    TiendaKey      INT NOT NULL,
    ClienteKey     INT NOT NULL,
    VendedorKey    INT NOT NULL,
    -- Medidas
    CantidadDevuelta INT NOT NULL,
    ValorDevuelto    DECIMAL(12,2) NOT NULL,
    CostoUnitario    DECIMAL(12,2) NOT NULL,
    ValorCostoDevuelto AS (CantidadDevuelta * CostoUnitario),
    MotivoDev        VARCHAR(100) NOT NULL,
    -- Referencia OLTP
    DevolucionID     INT NOT NULL,
    CONSTRAINT FK_FD_Fecha    FOREIGN KEY (FechaKey)    REFERENCES DimFecha(FechaKey),
    CONSTRAINT FK_FD_Producto FOREIGN KEY (ProductoKey) REFERENCES DimProducto(ProductoKey),
    CONSTRAINT FK_FD_Tienda   FOREIGN KEY (TiendaKey)   REFERENCES DimTienda(TiendaKey),
    CONSTRAINT FK_FD_Cliente  FOREIGN KEY (ClienteKey)  REFERENCES DimCliente(ClienteKey)
);

-- FACT COMPRAS (granularidad: línea de orden de compra)
CREATE TABLE FactCompras (
    CompraKey      BIGINT IDENTITY(1,1) PRIMARY KEY,
    FechaKey       INT NOT NULL,            -- fecha de recepción
    ProductoKey    INT NOT NULL,
    TiendaKey      INT NOT NULL,
    ProveedorKey   INT NOT NULL,
    -- Medidas
    CantidadComprada INT NOT NULL,
    CostoUnitario    DECIMAL(12,2) NOT NULL,
    ValorCompra      DECIMAL(14,2) NOT NULL,
    -- Referencia OLTP
    CompraID         INT NOT NULL,
    DetalleCompraID  INT NOT NULL,
    CONSTRAINT FK_FC_Fecha    FOREIGN KEY (FechaKey)    REFERENCES DimFecha(FechaKey),
    CONSTRAINT FK_FC_Producto FOREIGN KEY (ProductoKey) REFERENCES DimProducto(ProductoKey),
    CONSTRAINT FK_FC_Tienda   FOREIGN KEY (TiendaKey)   REFERENCES DimTienda(TiendaKey),
    CONSTRAINT FK_FC_Prov     FOREIGN KEY (ProveedorKey) REFERENCES DimProveedor(ProveedorKey)
);

-- ============================================================
-- TABLA DE LOG ETL (requerida por el enunciado)
-- ============================================================
CREATE TABLE ETL_Log (
    LogID             INT IDENTITY(1,1) PRIMARY KEY,
    NombreProceso     VARCHAR(100) NOT NULL,
    FechaInicio       DATETIME NOT NULL,
    FechaFin          DATETIME,
    Estado            VARCHAR(20) NOT NULL DEFAULT 'En Proceso',  -- En Proceso, Exitoso, Error
    RegistrosLeidos   INT NOT NULL DEFAULT 0,
    RegistrosCargados INT NOT NULL DEFAULT 0,
    RegistrosRechazados INT NOT NULL DEFAULT 0,
    MensajeError      VARCHAR(MAX),
    CONSTRAINT CHK_Log_Estado CHECK (Estado IN ('En Proceso','Exitoso','Error'))
);

-- ============================================================
-- ÍNDICES PARA RENDIMIENTO EN DW
-- ============================================================
CREATE INDEX IX_FV_Fecha     ON FactVentas(FechaKey);
CREATE INDEX IX_FV_Tienda    ON FactVentas(TiendaKey);
CREATE INDEX IX_FV_Producto  ON FactVentas(ProductoKey);
CREATE INDEX IX_FV_Cliente   ON FactVentas(ClienteKey);
CREATE INDEX IX_FID_Fecha    ON FactInventarioDiario(FechaKey);
CREATE INDEX IX_FID_Producto ON FactInventarioDiario(ProductoKey, TiendaKey);
CREATE INDEX IX_FM_Fecha     ON FactMetasComerciales(FechaKey, TiendaKey);

PRINT '✅ Data Warehouse RetailCO_DW creado exitosamente.';
PRINT 'Dimensiones: DimFecha, DimCliente, DimProducto, DimTienda, DimVendedor,';
PRINT '             DimProveedor, DimCanalVenta, DimPromocion, DimGeografia';
PRINT 'Hechos: FactVentas, FactInventarioDiario, FactMetasComerciales,';
PRINT '        FactDevoluciones, FactCompras';
GO
