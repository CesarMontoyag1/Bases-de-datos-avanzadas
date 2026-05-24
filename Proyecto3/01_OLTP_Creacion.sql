-- ============================================================
-- SI3009 Bases de Datos Avanzadas - Proyecto 3
-- SCRIPT 01: Creación de la Base de Datos OLTP
-- Empresa: RetailCO S.A.S (minorista con sedes en Colombia)
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'RetailCO_OLTP')
    DROP DATABASE RetailCO_OLTP;
GO

CREATE DATABASE RetailCO_OLTP;
GO

USE RetailCO_OLTP;
GO

-- ============================================================
-- 1. CATEGORÍAS
-- ============================================================
CREATE TABLE Categorias (
    CategoriaID     INT IDENTITY(1,1) PRIMARY KEY,
    NombreCategoria VARCHAR(100) NOT NULL,
    Descripcion     VARCHAR(255),
    Activa          BIT NOT NULL DEFAULT 1,
    FechaCreacion   DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_Categorias_Nombre UNIQUE (NombreCategoria)
);

-- ============================================================
-- 2. PROVEEDORES
-- ============================================================
CREATE TABLE Proveedores (
    ProveedorID   INT IDENTITY(1,1) PRIMARY KEY,
    NombreEmpresa VARCHAR(150) NOT NULL,
    Contacto      VARCHAR(100),
    Telefono      VARCHAR(20),
    Email         VARCHAR(120),
    Ciudad        VARCHAR(80),
    Departamento  VARCHAR(80),
    Pais          VARCHAR(60) NOT NULL DEFAULT 'Colombia',
    Activo        BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CHK_Proveedores_Email CHECK (Email LIKE '%@%.%' OR Email IS NULL)
);

-- ============================================================
-- 3. PRODUCTOS
-- ============================================================
CREATE TABLE Productos (
    ProductoID      INT IDENTITY(1,1) PRIMARY KEY,
    CodigoSKU       VARCHAR(30) NOT NULL,
    NombreProducto  VARCHAR(150) NOT NULL,
    CategoriaID     INT NOT NULL,
    ProveedorID     INT NOT NULL,
    PrecioUnitario  DECIMAL(12,2) NOT NULL,
    CostoUnitario   DECIMAL(12,2) NOT NULL,
    UnidadMedida    VARCHAR(20) NOT NULL DEFAULT 'Unidad',
    StockMinimo     INT NOT NULL DEFAULT 10,
    Activo          BIT NOT NULL DEFAULT 1,
    FechaCreacion   DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_Productos_SKU    UNIQUE (CodigoSKU),
    CONSTRAINT FK_Productos_Cat    FOREIGN KEY (CategoriaID) REFERENCES Categorias(CategoriaID),
    CONSTRAINT FK_Productos_Prov   FOREIGN KEY (ProveedorID) REFERENCES Proveedores(ProveedorID),
    CONSTRAINT CHK_Productos_Precio CHECK (PrecioUnitario > 0),
    CONSTRAINT CHK_Productos_Costo  CHECK (CostoUnitario > 0),
    CONSTRAINT CHK_Productos_Margen CHECK (PrecioUnitario >= CostoUnitario)
);

-- ============================================================
-- 4. GEOGRAFÍA / REGIONES
-- ============================================================
CREATE TABLE Geografias (
    GeografiaID  INT IDENTITY(1,1) PRIMARY KEY,
    Ciudad       VARCHAR(80) NOT NULL,
    Departamento VARCHAR(80) NOT NULL,
    Region       VARCHAR(60) NOT NULL,  -- Caribe, Andina, Pacífico, Orinoquía, Amazonía
    Pais         VARCHAR(60) NOT NULL DEFAULT 'Colombia'
);

-- ============================================================
-- 5. TIENDAS / SEDES
-- ============================================================
CREATE TABLE Tiendas (
    TiendaID      INT IDENTITY(1,1) PRIMARY KEY,
    CodigoTienda  VARCHAR(20) NOT NULL,
    NombreTienda  VARCHAR(100) NOT NULL,
    GeografiaID   INT NOT NULL,
    Direccion     VARCHAR(200),
    Telefono      VARCHAR(20),
    Activa        BIT NOT NULL DEFAULT 1,
    FechaApertura DATE NOT NULL,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_Tiendas_Codigo UNIQUE (CodigoTienda),
    CONSTRAINT FK_Tiendas_Geo   FOREIGN KEY (GeografiaID) REFERENCES Geografias(GeografiaID)
);

-- ============================================================
-- 6. VENDEDORES
-- ============================================================
CREATE TABLE Vendedores (
    VendedorID    INT IDENTITY(1,1) PRIMARY KEY,
    Cedula        VARCHAR(20) NOT NULL,
    Nombres       VARCHAR(80) NOT NULL,
    Apellidos     VARCHAR(80) NOT NULL,
    TiendaID      INT NOT NULL,
    Cargo         VARCHAR(60) NOT NULL DEFAULT 'Asesor Comercial',
    Email         VARCHAR(120),
    Telefono      VARCHAR(20),
    FechaIngreso  DATE NOT NULL,
    Activo        BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_Vendedores_Cedula UNIQUE (Cedula),
    CONSTRAINT FK_Vendedores_Tienda FOREIGN KEY (TiendaID) REFERENCES Tiendas(TiendaID),
    CONSTRAINT CHK_Vendedores_Email CHECK (Email LIKE '%@%.%' OR Email IS NULL)
);

-- ============================================================
-- 7. CLIENTES
-- ============================================================
CREATE TABLE Clientes (
    ClienteID         INT IDENTITY(1,1) PRIMARY KEY,
    Cedula            VARCHAR(20) NOT NULL,
    Nombres           VARCHAR(80) NOT NULL,
    Apellidos         VARCHAR(80) NOT NULL,
    Email             VARCHAR(120),
    Telefono          VARCHAR(20),
    GeografiaID       INT,
    Direccion         VARCHAR(200),
    FechaNacimiento   DATE,
    Genero            CHAR(1),
    Segmento          VARCHAR(40) NOT NULL DEFAULT 'Regular',  -- Regular, Frecuente, VIP, Nuevo
    FechaRegistro     DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Activo            BIT NOT NULL DEFAULT 1,
    CONSTRAINT UQ_Clientes_Cedula UNIQUE (Cedula),
    CONSTRAINT FK_Clientes_Geo    FOREIGN KEY (GeografiaID) REFERENCES Geografias(GeografiaID),
    CONSTRAINT CHK_Clientes_Genero   CHECK (Genero IN ('M','F','O') OR Genero IS NULL),
    CONSTRAINT CHK_Clientes_Segmento CHECK (Segmento IN ('Regular','Frecuente','VIP','Nuevo'))
);

-- ============================================================
-- 8. CANALES DE VENTA
-- ============================================================
CREATE TABLE CanalesVenta (
    CanalID     INT IDENTITY(1,1) PRIMARY KEY,
    NombreCanal VARCHAR(60) NOT NULL,
    Descripcion VARCHAR(200),
    CONSTRAINT UQ_Canales_Nombre UNIQUE (NombreCanal)
);

-- ============================================================
-- 9. CAMPAÑAS / PROMOCIONES
-- ============================================================
CREATE TABLE Campanas (
    CampanaID       INT IDENTITY(1,1) PRIMARY KEY,
    NombreCampana   VARCHAR(100) NOT NULL,
    TipoDescuento   VARCHAR(20) NOT NULL DEFAULT 'Porcentaje', -- Porcentaje, ValorFijo
    ValorDescuento  DECIMAL(8,2) NOT NULL DEFAULT 0,
    FechaInicio     DATE NOT NULL,
    FechaFin        DATE NOT NULL,
    Activa          BIT NOT NULL DEFAULT 1,
    CONSTRAINT CHK_Campanas_Tipo     CHECK (TipoDescuento IN ('Porcentaje','ValorFijo')),
    CONSTRAINT CHK_Campanas_Fechas   CHECK (FechaFin >= FechaInicio),
    CONSTRAINT CHK_Campanas_Descuento CHECK (ValorDescuento >= 0)
);

-- ============================================================
-- 10. VENTAS (cabecera de factura)
-- ============================================================
CREATE TABLE Ventas (
    VentaID       INT IDENTITY(1,1) PRIMARY KEY,
    NumeroFactura VARCHAR(30) NOT NULL,
    FechaVenta    DATETIME NOT NULL DEFAULT GETDATE(),
    ClienteID     INT NOT NULL,
    TiendaID      INT NOT NULL,
    VendedorID    INT NOT NULL,
    CanalID       INT NOT NULL,
    CampanaID     INT,                       -- NULL si no aplica campaña
    TotalBruto    DECIMAL(14,2) NOT NULL DEFAULT 0,
    TotalDescuento DECIMAL(14,2) NOT NULL DEFAULT 0,
    TotalNeto     DECIMAL(14,2) NOT NULL DEFAULT 0,
    Estado        VARCHAR(20) NOT NULL DEFAULT 'Completada',  -- Completada, Anulada
    CONSTRAINT UQ_Ventas_Factura   UNIQUE (NumeroFactura),
    CONSTRAINT FK_Ventas_Cliente   FOREIGN KEY (ClienteID)  REFERENCES Clientes(ClienteID),
    CONSTRAINT FK_Ventas_Tienda    FOREIGN KEY (TiendaID)   REFERENCES Tiendas(TiendaID),
    CONSTRAINT FK_Ventas_Vendedor  FOREIGN KEY (VendedorID) REFERENCES Vendedores(VendedorID),
    CONSTRAINT FK_Ventas_Canal     FOREIGN KEY (CanalID)    REFERENCES CanalesVenta(CanalID),
    CONSTRAINT FK_Ventas_Campana   FOREIGN KEY (CampanaID)  REFERENCES Campanas(CampanaID),
    CONSTRAINT CHK_Ventas_Total    CHECK (TotalNeto >= 0),
    CONSTRAINT CHK_Ventas_Estado   CHECK (Estado IN ('Completada','Anulada'))
);

-- ============================================================
-- 11. DETALLE DE VENTAS
-- ============================================================
CREATE TABLE DetalleVentas (
    DetalleID       INT IDENTITY(1,1) PRIMARY KEY,
    VentaID         INT NOT NULL,
    ProductoID      INT NOT NULL,
    Cantidad        INT NOT NULL,
    PrecioUnitario  DECIMAL(12,2) NOT NULL,
    CostoUnitario   DECIMAL(12,2) NOT NULL,
    Descuento       DECIMAL(8,2) NOT NULL DEFAULT 0,
    Subtotal        DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_Detalle_Venta    FOREIGN KEY (VentaID)    REFERENCES Ventas(VentaID),
    CONSTRAINT FK_Detalle_Producto FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT CHK_Detalle_Cant    CHECK (Cantidad > 0),
    CONSTRAINT CHK_Detalle_Precio  CHECK (PrecioUnitario > 0),
    CONSTRAINT CHK_Detalle_Desc    CHECK (Descuento >= 0 AND Descuento <= 100)
);

-- ============================================================
-- 12. INVENTARIO DIARIO
-- ============================================================
CREATE TABLE InventarioDiario (
    InventarioID  INT IDENTITY(1,1) PRIMARY KEY,
    FechaRegistro DATE NOT NULL,
    ProductoID    INT NOT NULL,
    TiendaID      INT NOT NULL,
    StockInicial  INT NOT NULL DEFAULT 0,
    Entradas      INT NOT NULL DEFAULT 0,
    Salidas       INT NOT NULL DEFAULT 0,
    Ajustes       INT NOT NULL DEFAULT 0,
    StockFinal    INT NOT NULL DEFAULT 0,
    CONSTRAINT FK_Inv_Producto FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT FK_Inv_Tienda   FOREIGN KEY (TiendaID)   REFERENCES Tiendas(TiendaID),
    CONSTRAINT UQ_Inv_FechaProdTienda UNIQUE (FechaRegistro, ProductoID, TiendaID),
    CONSTRAINT CHK_Inv_Stock   CHECK (StockFinal >= 0)
);

-- ============================================================
-- 13. COMPRAS (cabecera de orden de compra)
-- ============================================================
CREATE TABLE Compras (
    CompraID        INT IDENTITY(1,1) PRIMARY KEY,
    NumeroOrden     VARCHAR(30) NOT NULL,
    FechaCompra     DATETIME NOT NULL DEFAULT GETDATE(),
    FechaRecepcion  DATE,
    ProveedorID     INT NOT NULL,
    TiendaID        INT NOT NULL,
    TotalCompra     DECIMAL(14,2) NOT NULL DEFAULT 0,
    Estado          VARCHAR(20) NOT NULL DEFAULT 'Recibida',  -- Pendiente, Recibida, Anulada
    CONSTRAINT UQ_Compras_Orden  UNIQUE (NumeroOrden),
    CONSTRAINT FK_Compras_Prov   FOREIGN KEY (ProveedorID) REFERENCES Proveedores(ProveedorID),
    CONSTRAINT FK_Compras_Tienda FOREIGN KEY (TiendaID)    REFERENCES Tiendas(TiendaID),
    CONSTRAINT CHK_Compras_Estado CHECK (Estado IN ('Pendiente','Recibida','Anulada'))
);

-- ============================================================
-- 14. DETALLE DE COMPRAS
-- ============================================================
CREATE TABLE DetalleCompras (
    DetalleCompraID INT IDENTITY(1,1) PRIMARY KEY,
    CompraID        INT NOT NULL,
    ProductoID      INT NOT NULL,
    Cantidad        INT NOT NULL,
    CostoUnitario   DECIMAL(12,2) NOT NULL,
    Subtotal        DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_DetCompra_Compra   FOREIGN KEY (CompraID)   REFERENCES Compras(CompraID),
    CONSTRAINT FK_DetCompra_Producto FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT CHK_DetCompra_Cant    CHECK (Cantidad > 0),
    CONSTRAINT CHK_DetCompra_Costo   CHECK (CostoUnitario > 0)
);

-- ============================================================
-- 15. DEVOLUCIONES
-- ============================================================
CREATE TABLE Devoluciones (
    DevolucionID    INT IDENTITY(1,1) PRIMARY KEY,
    NumeroDevolucion VARCHAR(30) NOT NULL,
    FechaDevolucion  DATETIME NOT NULL DEFAULT GETDATE(),
    VentaID          INT NOT NULL,
    ProductoID       INT NOT NULL,
    TiendaID         INT NOT NULL,
    CantidadDevuelta INT NOT NULL,
    MotivoDev        VARCHAR(100) NOT NULL,  -- Defecto, Cambio, Error, Otro
    ValorDevuelto    DECIMAL(12,2) NOT NULL,
    CONSTRAINT UQ_Dev_Numero     UNIQUE (NumeroDevolucion),
    CONSTRAINT FK_Dev_Venta      FOREIGN KEY (VentaID)    REFERENCES Ventas(VentaID),
    CONSTRAINT FK_Dev_Producto   FOREIGN KEY (ProductoID) REFERENCES Productos(ProductoID),
    CONSTRAINT FK_Dev_Tienda     FOREIGN KEY (TiendaID)   REFERENCES Tiendas(TiendaID),
    CONSTRAINT CHK_Dev_Cantidad  CHECK (CantidadDevuelta > 0),
    CONSTRAINT CHK_Dev_Motivo    CHECK (MotivoDev IN ('Defecto','Cambio','Error','Otro'))
);

-- ============================================================
-- 16. METAS COMERCIALES
-- ============================================================
CREATE TABLE MetasComerciales (
    MetaID       INT IDENTITY(1,1) PRIMARY KEY,
    Anio         INT NOT NULL,
    Mes          INT NOT NULL,
    TiendaID     INT NOT NULL,
    CategoriaID  INT,
    VendedorID   INT,
    CanalID      INT,
    ValorMeta    DECIMAL(14,2) NOT NULL,
    UnidadesMeta INT,
    CONSTRAINT FK_Metas_Tienda    FOREIGN KEY (TiendaID)   REFERENCES Tiendas(TiendaID),
    CONSTRAINT FK_Metas_Categoria FOREIGN KEY (CategoriaID) REFERENCES Categorias(CategoriaID),
    CONSTRAINT FK_Metas_Vendedor  FOREIGN KEY (VendedorID) REFERENCES Vendedores(VendedorID),
    CONSTRAINT FK_Metas_Canal     FOREIGN KEY (CanalID)    REFERENCES CanalesVenta(CanalID),
    CONSTRAINT CHK_Metas_Mes      CHECK (Mes BETWEEN 1 AND 12),
    CONSTRAINT CHK_Metas_Anio     CHECK (Anio BETWEEN 2020 AND 2030),
    CONSTRAINT CHK_Metas_Valor    CHECK (ValorMeta > 0)
);

-- ============================================================
-- ÍNDICES DE RENDIMIENTO
-- ============================================================
CREATE INDEX IX_Ventas_Fecha      ON Ventas(FechaVenta);
CREATE INDEX IX_Ventas_Cliente    ON Ventas(ClienteID);
CREATE INDEX IX_Ventas_Tienda     ON Ventas(TiendaID);
CREATE INDEX IX_DetalleVentas_V   ON DetalleVentas(VentaID);
CREATE INDEX IX_DetalleVentas_P   ON DetalleVentas(ProductoID);
CREATE INDEX IX_Inv_Fecha         ON InventarioDiario(FechaRegistro);
CREATE INDEX IX_Inv_Producto      ON InventarioDiario(ProductoID, TiendaID);
CREATE INDEX IX_Metas_AnioMes     ON MetasComerciales(Anio, Mes, TiendaID);

PRINT 'OLTP RetailCO_OLTP creado exitosamente.';
GO
