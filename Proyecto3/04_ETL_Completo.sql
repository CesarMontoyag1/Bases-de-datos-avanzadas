-- ============================================================
-- SI3009 - Bases de Datos Avanzadas - Proyecto 3
-- SCRIPT 04: ETL COMPLETO CORREGIDO
-- Corregido y validado el 23/05/2026
-- Cambios: columnas reales del DW, SCD Tipo 2, CostoUnitario,
--          DimCanalVenta con IDENTITY_INSERT, ValorInventario
--          es columna calculada (no se inserta)
-- ============================================================

USE master;
GO

-- Recrear BI_Staging limpia
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'BI_Staging')
BEGIN
    ALTER DATABASE BI_Staging SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BI_Staging;
END
GO

CREATE DATABASE BI_Staging;
GO
USE BI_Staging;
GO

-- ============================================================
-- TABLAS DE STAGING
-- ============================================================
CREATE TABLE Stg_Clientes (
    ClienteID INT, Cedula VARCHAR(30), Nombres VARCHAR(100), Apellidos VARCHAR(100),
    Email VARCHAR(150), Ciudad VARCHAR(100), Departamento VARCHAR(100), Segmento VARCHAR(50),
    Genero VARCHAR(5), FechaRegistro VARCHAR(30),
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
CREATE TABLE Stg_Productos (
    ProductoID INT, CodigoSKU VARCHAR(50), NombreProducto VARCHAR(200),
    Categoria VARCHAR(150), Proveedor VARCHAR(200),
    PrecioUnitario VARCHAR(30), CostoUnitario VARCHAR(30),
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
CREATE TABLE Stg_Ventas (
    VentaID INT, DetalleID INT, NumeroFactura VARCHAR(50), FechaVenta VARCHAR(30),
    ClienteID INT, TiendaID INT, VendedorID INT, CanalID INT, CampanaID INT, ProductoID INT,
    Cantidad VARCHAR(20), PrecioUnitario VARCHAR(30), CostoUnitario VARCHAR(30),
    Descuento VARCHAR(20), Subtotal VARCHAR(30),
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
CREATE TABLE Stg_Inventario (
    FechaRegistro VARCHAR(30), ProductoID INT, TiendaID INT,
    StockInicial INT, Entradas INT, Salidas INT, Ajustes INT, StockFinal INT,
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
CREATE TABLE Stg_Metas (
    MetaID INT, Anio INT, Mes INT, TiendaID INT, CategoriaID INT,
    VendedorID INT, CanalID INT, ValorMeta VARCHAR(30), UnidadesMeta VARCHAR(20),
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
CREATE TABLE Stg_Devoluciones (
    DevolucionID INT, NumeroDevolucion VARCHAR(50), FechaDevolucion VARCHAR(30),
    VentaID INT, ProductoID INT, TiendaID INT, CantidadDevuelta INT,
    MotivoDev VARCHAR(100), ValorDevuelto VARCHAR(30),
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
CREATE TABLE Stg_Compras (
    CompraID INT, DetalleCompraID INT, NumeroOrden VARCHAR(50),
    FechaRecepcion VARCHAR(30), ProveedorID INT, TiendaID INT, ProductoID INT,
    CantidadComprada INT, CostoUnitario VARCHAR(30), Subtotal VARCHAR(30),
    FechaCarga DATETIME DEFAULT GETDATE(),
    EstadoRegistro VARCHAR(20) DEFAULT 'Pendiente',
    MotivoRechazo VARCHAR(300)
);
GO

PRINT 'BI_Staging y tablas de staging creadas correctamente.';
GO

-- ============================================================
-- CAMBIO AL DATA WAREHOUSE
-- ============================================================
USE RetailCO_DW;
GO

-- ============================================================
-- PROCEDIMIENTOS DE LOG
-- ============================================================
CREATE OR ALTER PROCEDURE usp_LogInicio
    @Proceso VARCHAR(100),
    @LogID INT OUTPUT
AS
BEGIN
    INSERT INTO ETL_Log (NombreProceso, FechaInicio, Estado)
    VALUES (@Proceso, GETDATE(), 'En Proceso');
    SET @LogID = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE usp_LogFin
    @LogID INT,
    @Estado VARCHAR(20),
    @Leidos INT,
    @Cargados INT,
    @Rechazados INT,
    @Error VARCHAR(MAX) = NULL
AS
BEGIN
    UPDATE ETL_Log
    SET FechaFin = GETDATE(),
        Estado = @Estado,
        RegistrosLeidos = @Leidos,
        RegistrosCargados = @Cargados,
        RegistrosRechazados = @Rechazados,
        MensajeError = @Error
    WHERE LogID = @LogID;
END;
GO

-- ============================================================
-- 1. CARGAR DimCanalVenta (prerequisito para FactVentas y FactMetas)
-- NOTA: CanalKey es IDENTITY, se usa IDENTITY_INSERT para alinear
--       CanalKey con CanalID del OLTP
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarDimCanalVenta
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarDimCanalVenta', @LogID OUTPUT;
    BEGIN TRY
        -- Limpiar (FactVentas debe estar vacia o usar DELETE en orden)
        DELETE FROM RetailCO_DW.dbo.DimCanalVenta;

        SET IDENTITY_INSERT RetailCO_DW.dbo.DimCanalVenta ON;

        INSERT INTO RetailCO_DW.dbo.DimCanalVenta (CanalKey, CanalID, NombreCanal)
        SELECT CanalID, CanalID, NombreCanal
        FROM RetailCO_OLTP.dbo.CanalesVenta;

        SET IDENTITY_INSERT RetailCO_DW.dbo.DimCanalVenta OFF;

        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'DimCanalVenta cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        IF (SELECT OBJECTPROPERTY(OBJECT_ID('DimCanalVenta'), 'TableHasIdentity')) = 1
            SET IDENTITY_INSERT RetailCO_DW.dbo.DimCanalVenta OFF;
        DECLARE @Err0 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err0;
        PRINT 'Error DimCanalVenta: ' + @Err0;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 2. CARGAR DimFecha
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarDimFecha
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @d DATE = '2020-01-01', @fin DATE = '2030-12-31', @n INT = 0;
    EXEC usp_LogInicio 'CargarDimFecha', @LogID OUTPUT;
    BEGIN TRY
        DELETE FROM DimFecha;
        WHILE @d <= @fin
        BEGIN
            DECLARE @EsFestivo INT = 0;
            IF (MONTH(@d)=1 AND DAY(@d)=1) OR (MONTH(@d)=5 AND DAY(@d)=1)
            OR (MONTH(@d)=7 AND DAY(@d)=20) OR (MONTH(@d)=8 AND DAY(@d)=7)
            OR (MONTH(@d)=12 AND DAY(@d)=8) OR (MONTH(@d)=12 AND DAY(@d)=25)
                SET @EsFestivo = 1;

            INSERT INTO DimFecha (FechaKey, Fecha, Dia, NombreDia, Semana, Mes, NombreMes,
                                  Trimestre, NombreTrimestre, Semestre, Anio, EsFestivo, EsFinDeSemana)
            VALUES (
                CAST(CONVERT(VARCHAR(8), @d, 112) AS INT),
                @d,
                DAY(@d),
                CAST(DATENAME(WEEKDAY, @d) AS VARCHAR(50)),
                DATEPART(WEEK, @d),
                MONTH(@d),
                CAST(DATENAME(MONTH, @d) AS VARCHAR(50)),
                DATEPART(QUARTER, @d),
                CAST('T' + CAST(DATEPART(QUARTER, @d) AS VARCHAR(1)) AS VARCHAR(10)),
                CASE WHEN MONTH(@d) <= 6 THEN 1 ELSE 2 END,
                YEAR(@d),
                @EsFestivo,
                CASE WHEN DATEPART(WEEKDAY, @d) IN (1,7) THEN 1 ELSE 0 END
            );
            SET @d = DATEADD(DAY, 1, @d);
            SET @n = @n + 1;
        END
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'DimFecha cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err1 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', @n, 0, 0, @Err1;
        PRINT 'Error DimFecha: ' + @Err1;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 3. EXTRACT TO STAGING
-- ============================================================
CREATE OR ALTER PROCEDURE usp_ExtractToStaging
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'ExtractToStaging', @LogID OUTPUT;
    BEGIN TRY
        TRUNCATE TABLE BI_Staging.dbo.Stg_Clientes;
        TRUNCATE TABLE BI_Staging.dbo.Stg_Productos;
        TRUNCATE TABLE BI_Staging.dbo.Stg_Ventas;
        TRUNCATE TABLE BI_Staging.dbo.Stg_Inventario;
        TRUNCATE TABLE BI_Staging.dbo.Stg_Metas;
        TRUNCATE TABLE BI_Staging.dbo.Stg_Devoluciones;
        TRUNCATE TABLE BI_Staging.dbo.Stg_Compras;

        INSERT INTO BI_Staging.dbo.Stg_Clientes
            (ClienteID, Cedula, Nombres, Apellidos, Email, Ciudad, Departamento, Segmento, Genero, FechaRegistro)
        SELECT c.ClienteID, c.Cedula, c.Nombres, c.Apellidos, c.Email,
               g.Ciudad, g.Departamento, c.Segmento, c.Genero,
               CONVERT(VARCHAR(20), c.FechaRegistro, 23)
        FROM RetailCO_OLTP.dbo.Clientes c
        LEFT JOIN RetailCO_OLTP.dbo.Geografias g ON g.GeografiaID = c.GeografiaID;
        SET @n = @n + @@ROWCOUNT;

        INSERT INTO BI_Staging.dbo.Stg_Productos
            (ProductoID, CodigoSKU, NombreProducto, Categoria, Proveedor, PrecioUnitario, CostoUnitario)
        SELECT p.ProductoID, p.CodigoSKU, p.NombreProducto, c.NombreCategoria,
               pv.NombreEmpresa,
               CAST(p.PrecioUnitario AS VARCHAR(30)),
               CAST(p.CostoUnitario AS VARCHAR(30))
        FROM RetailCO_OLTP.dbo.Productos p
        INNER JOIN RetailCO_OLTP.dbo.Categorias c ON c.CategoriaID = p.CategoriaID
        INNER JOIN RetailCO_OLTP.dbo.Proveedores pv ON pv.ProveedorID = p.ProveedorID;
        SET @n = @n + @@ROWCOUNT;

        INSERT INTO BI_Staging.dbo.Stg_Ventas
            (VentaID, DetalleID, NumeroFactura, FechaVenta, ClienteID, TiendaID, VendedorID,
             CanalID, CampanaID, ProductoID, Cantidad, PrecioUnitario, CostoUnitario, Descuento, Subtotal)
        SELECT v.VentaID, dv.DetalleID, v.NumeroFactura,
               CONVERT(VARCHAR(30), v.FechaVenta, 120),
               v.ClienteID, v.TiendaID, v.VendedorID, v.CanalID, v.CampanaID, dv.ProductoID,
               CAST(dv.Cantidad AS VARCHAR(20)),
               CAST(dv.PrecioUnitario AS VARCHAR(30)),
               CAST(dv.CostoUnitario AS VARCHAR(30)),
               CAST(dv.Descuento AS VARCHAR(20)),
               CAST(dv.Subtotal AS VARCHAR(30))
        FROM RetailCO_OLTP.dbo.Ventas v
        INNER JOIN RetailCO_OLTP.dbo.DetalleVentas dv ON dv.VentaID = v.VentaID
        WHERE v.Estado = 'Completada';
        SET @n = @n + @@ROWCOUNT;

        INSERT INTO BI_Staging.dbo.Stg_Inventario
            (FechaRegistro, ProductoID, TiendaID, StockInicial, Entradas, Salidas, Ajustes, StockFinal)
        SELECT CONVERT(VARCHAR(20), FechaRegistro, 23), ProductoID, TiendaID,
               StockInicial, Entradas, Salidas, Ajustes, StockFinal
        FROM RetailCO_OLTP.dbo.InventarioDiario;
        SET @n = @n + @@ROWCOUNT;

        INSERT INTO BI_Staging.dbo.Stg_Metas
            (MetaID, Anio, Mes, TiendaID, CategoriaID, VendedorID, CanalID, ValorMeta, UnidadesMeta)
        SELECT MetaID, Anio, Mes, TiendaID, CategoriaID, VendedorID, CanalID,
               CAST(ValorMeta AS VARCHAR(30)), CAST(UnidadesMeta AS VARCHAR(20))
        FROM RetailCO_OLTP.dbo.MetasComerciales;
        SET @n = @n + @@ROWCOUNT;

        INSERT INTO BI_Staging.dbo.Stg_Devoluciones
            (DevolucionID, NumeroDevolucion, FechaDevolucion, VentaID, ProductoID,
             TiendaID, CantidadDevuelta, MotivoDev, ValorDevuelto)
        SELECT DevolucionID, NumeroDevolucion,
               CONVERT(VARCHAR(30), FechaDevolucion, 120),
               VentaID, ProductoID, TiendaID, CantidadDevuelta, MotivoDev,
               CAST(ValorDevuelto AS VARCHAR(30))
        FROM RetailCO_OLTP.dbo.Devoluciones;
        SET @n = @n + @@ROWCOUNT;

        INSERT INTO BI_Staging.dbo.Stg_Compras
            (CompraID, DetalleCompraID, NumeroOrden, FechaRecepcion, ProveedorID,
             TiendaID, ProductoID, CantidadComprada, CostoUnitario, Subtotal)
        SELECT c.CompraID, dc.DetalleCompraID, c.NumeroOrden,
               CONVERT(VARCHAR(20), c.FechaRecepcion, 23),
               c.ProveedorID, c.TiendaID, dc.ProductoID, dc.Cantidad,
               CAST(dc.CostoUnitario AS VARCHAR(30)),
               CAST(dc.Subtotal AS VARCHAR(30))
        FROM RetailCO_OLTP.dbo.Compras c
        INNER JOIN RetailCO_OLTP.dbo.DetalleCompras dc ON dc.CompraID = c.CompraID
        WHERE c.Estado = 'Recibida';
        SET @n = @n + @@ROWCOUNT;

        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'ExtractToStaging completado: ' + CAST(@n AS VARCHAR) + ' registros.';
    END TRY
    BEGIN CATCH
        DECLARE @Err2 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', @n, 0, 0, @Err2;
        PRINT 'Error ExtractToStaging: ' + @Err2;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 4. VALIDAR CALIDAD DE DATOS
-- ============================================================
CREATE OR ALTER PROCEDURE usp_ValidarCalidadDatos
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT;
    EXEC usp_LogInicio 'ValidarCalidadDatos', @LogID OUTPUT;
    BEGIN TRY
        -- Limpiar emails invalidos
        UPDATE BI_Staging.dbo.Stg_Clientes
        SET MotivoRechazo = 'Email invalido'
        WHERE Email NOT LIKE '%@%.%';

        -- Estandarizar ciudades
        UPDATE BI_Staging.dbo.Stg_Clientes
        SET Ciudad = UPPER(LEFT(Ciudad,1)) + LOWER(SUBSTRING(Ciudad,2,LEN(Ciudad)))
        WHERE Ciudad IS NOT NULL;

        -- Rechazar ventas con precio negativo o cero
        UPDATE BI_Staging.dbo.Stg_Ventas
        SET EstadoRegistro = 'Rechazado', MotivoRechazo = 'Precio negativo o cero'
        WHERE TRY_CAST(PrecioUnitario AS DECIMAL(12,2)) <= 0;

        -- Rechazar ventas con fecha invalida
        UPDATE BI_Staging.dbo.Stg_Ventas
        SET EstadoRegistro = 'Rechazado', MotivoRechazo = 'Fecha invalida'
        WHERE TRY_CAST(FechaVenta AS DATETIME) IS NULL
          AND EstadoRegistro = 'Pendiente';

        -- Marcar validos
        UPDATE BI_Staging.dbo.Stg_Clientes     SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';
        UPDATE BI_Staging.dbo.Stg_Productos    SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';
        UPDATE BI_Staging.dbo.Stg_Ventas       SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';
        UPDATE BI_Staging.dbo.Stg_Inventario   SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';
        UPDATE BI_Staging.dbo.Stg_Metas        SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';
        UPDATE BI_Staging.dbo.Stg_Devoluciones SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';
        UPDATE BI_Staging.dbo.Stg_Compras      SET EstadoRegistro = 'Valido' WHERE EstadoRegistro = 'Pendiente';

        EXEC usp_LogFin @LogID, 'Exitoso', 0, 0, 0, NULL;
        PRINT 'Validacion de calidad completada.';
    END TRY
    BEGIN CATCH
        DECLARE @Err3 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err3;
        PRINT 'Error ValidarCalidad: ' + @Err3;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 5. CARGAR DimCliente (SCD Tipo 2)
-- NOTA: columnas reales: NombreCompleto, FechaInicioVigencia,
--       FechaFinVigencia (no FechaInicio/FechaFin)
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarDimCliente
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarDimCliente', @LogID OUTPUT;
    BEGIN TRY
        -- Cerrar versiones anteriores que cambiaron
        UPDATE dc
        SET dc.EsVersionActual = 0,
            dc.FechaFinVigencia = CAST(GETDATE() AS DATE)
        FROM RetailCO_DW.dbo.DimCliente dc
        INNER JOIN BI_Staging.dbo.Stg_Clientes sc ON sc.ClienteID = dc.ClienteID
        WHERE dc.EsVersionActual = 1
          AND (dc.Segmento <> ISNULL(sc.Segmento,'')
            OR dc.Ciudad <> ISNULL(sc.Ciudad,''));

        -- Insertar nuevos o versiones nuevas
        INSERT INTO RetailCO_DW.dbo.DimCliente
            (ClienteID, Cedula, NombreCompleto, Genero, Ciudad,
             Departamento, Segmento, FechaInicioVigencia, EsVersionActual)
        SELECT sc.ClienteID, sc.Cedula,
               sc.Nombres + ' ' + sc.Apellidos,
               sc.Genero, sc.Ciudad, sc.Departamento, sc.Segmento,
               CAST(GETDATE() AS DATE), 1
        FROM BI_Staging.dbo.Stg_Clientes sc
        WHERE sc.EstadoRegistro = 'Valido'
          AND NOT EXISTS (
              SELECT 1 FROM RetailCO_DW.dbo.DimCliente dc
              WHERE dc.ClienteID = sc.ClienteID AND dc.EsVersionActual = 1
          );
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'DimCliente cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err4 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err4;
        PRINT 'Error DimCliente: ' + @Err4;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 6. CARGAR DimProducto (SCD Tipo 2)
-- NOTA: columnas reales: FechaInicioVigencia, FechaFinVigencia
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarDimProducto
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarDimProducto', @LogID OUTPUT;
    BEGIN TRY
        UPDATE dp
        SET dp.EsVersionActual = 0,
            dp.FechaFinVigencia = CAST(GETDATE() AS DATE)
        FROM RetailCO_DW.dbo.DimProducto dp
        INNER JOIN BI_Staging.dbo.Stg_Productos sp ON sp.ProductoID = dp.ProductoID
        WHERE dp.EsVersionActual = 1
          AND (dp.NombreProducto <> sp.NombreProducto
            OR dp.Categoria <> sp.Categoria);

        INSERT INTO RetailCO_DW.dbo.DimProducto
            (ProductoID, CodigoSKU, NombreProducto, Categoria, Proveedor,
             PrecioUnitario, CostoUnitario, FechaInicioVigencia, EsVersionActual)
        SELECT sp.ProductoID, sp.CodigoSKU, sp.NombreProducto, sp.Categoria, sp.Proveedor,
               TRY_CAST(sp.PrecioUnitario AS DECIMAL(12,2)),
               TRY_CAST(sp.CostoUnitario AS DECIMAL(12,2)),
               CAST(GETDATE() AS DATE), 1
        FROM BI_Staging.dbo.Stg_Productos sp
        WHERE sp.EstadoRegistro = 'Valido'
          AND NOT EXISTS (
              SELECT 1 FROM RetailCO_DW.dbo.DimProducto dp
              WHERE dp.ProductoID = sp.ProductoID AND dp.EsVersionActual = 1
          );
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'DimProducto cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err5 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err5;
        PRINT 'Error DimProducto: ' + @Err5;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 7. CARGAR DimTienda + DimVendedor
-- NOTA: DimVendedor tiene NombreTienda (no TiendaID)
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarDimTiendaVendedor
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarDimTiendaVendedor', @LogID OUTPUT;
    BEGIN TRY
        INSERT INTO RetailCO_DW.dbo.DimTienda
            (TiendaID, CodigoTienda, NombreTienda, Ciudad, Departamento, Region)
        SELECT t.TiendaID, t.CodigoTienda, t.NombreTienda,
               g.Ciudad, g.Departamento, g.Region
        FROM RetailCO_OLTP.dbo.Tiendas t
        INNER JOIN RetailCO_OLTP.dbo.Geografias g ON g.GeografiaID = t.GeografiaID
        WHERE NOT EXISTS (
            SELECT 1 FROM RetailCO_DW.dbo.DimTienda dt WHERE dt.TiendaID = t.TiendaID
        );
        SET @n = @@ROWCOUNT;

        INSERT INTO RetailCO_DW.dbo.DimVendedor
            (VendedorID, Cedula, NombreCompleto, Cargo, NombreTienda)
        SELECT v.VendedorID, v.Cedula,
               v.Nombres + ' ' + v.Apellidos,
               v.Cargo,
               t.NombreTienda
        FROM RetailCO_OLTP.dbo.Vendedores v
        INNER JOIN RetailCO_OLTP.dbo.Tiendas t ON t.TiendaID = v.TiendaID
        WHERE NOT EXISTS (
            SELECT 1 FROM RetailCO_DW.dbo.DimVendedor dv WHERE dv.VendedorID = v.VendedorID
        );
        SET @n = @n + @@ROWCOUNT;

        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'DimTienda + DimVendedor cargadas: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err6 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err6;
        PRINT 'Error DimTiendaVendedor: ' + @Err6;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 8. CARGAR FactVentas
-- NOTA: columnas reales incluyen PromocionKey y UtilidadBruta
--       ambas NOT NULL - se usan valores default seguros
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarFactVentas
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarFactVentas', @LogID OUTPUT;
    BEGIN TRY
        TRUNCATE TABLE RetailCO_DW.dbo.FactVentas;
        INSERT INTO RetailCO_DW.dbo.FactVentas
            (FechaKey, ClienteKey, ProductoKey, TiendaKey, VendedorKey,
             CanalKey, PromocionKey, VentaID, DetalleID, Cantidad,
             PrecioUnitario, CostoUnitario, ValorDescuento, ValorVenta,
             ValorCosto, UtilidadBruta)
        SELECT
            CAST(CONVERT(VARCHAR(8), TRY_CAST(sv.FechaVenta AS DATE), 112) AS INT),
            dc.ClienteKey,
            dp.ProductoKey,
            dt.TiendaKey,
            dv.VendedorKey,
            ISNULL(sv.CanalID, 1),
            1, -- PromocionKey default (sin promocion)
            sv.VentaID,
            sv.DetalleID,
            ISNULL(TRY_CAST(sv.Cantidad AS INT), 0),
            ISNULL(TRY_CAST(sv.PrecioUnitario AS DECIMAL(12,2)), 0),
            ISNULL(TRY_CAST(sv.CostoUnitario AS DECIMAL(12,2)), 0),
            -- ValorDescuento = precio * cantidad - subtotal
            ISNULL((TRY_CAST(sv.PrecioUnitario AS DECIMAL(12,2)) * TRY_CAST(sv.Cantidad AS INT))
                   - TRY_CAST(sv.Subtotal AS DECIMAL(14,2)), 0),
            ISNULL(TRY_CAST(sv.Subtotal AS DECIMAL(14,2)), 0),
            -- ValorCosto = costo * cantidad
            ISNULL(TRY_CAST(sv.CostoUnitario AS DECIMAL(12,2)) * TRY_CAST(sv.Cantidad AS INT), 0),
            -- UtilidadBruta = subtotal - (costo * cantidad)
            ISNULL(TRY_CAST(sv.Subtotal AS DECIMAL(14,2))
                   - (TRY_CAST(sv.CostoUnitario AS DECIMAL(12,2)) * TRY_CAST(sv.Cantidad AS INT)), 0)
        FROM BI_Staging.dbo.Stg_Ventas sv
        INNER JOIN RetailCO_DW.dbo.DimCliente  dc ON dc.ClienteID  = sv.ClienteID  AND dc.EsVersionActual = 1
        INNER JOIN RetailCO_DW.dbo.DimProducto dp ON dp.ProductoID = sv.ProductoID AND dp.EsVersionActual = 1
        INNER JOIN RetailCO_DW.dbo.DimTienda   dt ON dt.TiendaID   = sv.TiendaID
        INNER JOIN RetailCO_DW.dbo.DimVendedor dv ON dv.VendedorID = sv.VendedorID
        WHERE sv.EstadoRegistro = 'Valido';
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'FactVentas cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err7 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err7;
        PRINT 'Error FactVentas: ' + @Err7;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 9. CARGAR FactInventarioDiario
-- NOTA: CostoUnitario NOT NULL - se toma de DimProducto
--       ValorInventario es columna CALCULADA - no se inserta
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarFactInventario
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarFactInventario', @LogID OUTPUT;
    BEGIN TRY
        TRUNCATE TABLE RetailCO_DW.dbo.FactInventarioDiario;
        INSERT INTO RetailCO_DW.dbo.FactInventarioDiario
            (FechaKey, ProductoKey, TiendaKey, StockInicial, Entradas,
             Salidas, Ajustes, StockFinal, CostoUnitario)
        SELECT
            CAST(CONVERT(VARCHAR(8), TRY_CAST(i.FechaRegistro AS DATE), 112) AS INT),
            ISNULL(dp.ProductoKey, 1),
            ISNULL(dt.TiendaKey, 1),
            i.StockInicial,
            i.Entradas,
            i.Salidas,
            i.Ajustes,
            i.StockFinal,
            ISNULL(dp.CostoUnitario, 0)
        FROM RetailCO_OLTP.dbo.InventarioDiario i
        LEFT JOIN RetailCO_DW.dbo.DimProducto dp ON dp.ProductoID = i.ProductoID AND dp.EsVersionActual = 1
        LEFT JOIN RetailCO_DW.dbo.DimTienda   dt ON dt.TiendaID   = i.TiendaID;
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'FactInventarioDiario cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err8 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err8;
        PRINT 'Error FactInventario: ' + @Err8;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 10. CARGAR FactMetasComerciales
-- NOTA: CanalID es NULL en MetasComerciales del OLTP,
--       se asigna CanalKey=1 (Tienda Fisica) como default
--       FactMetasComerciales NO tiene columna CategoriaID
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarFactMetas
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarFactMetas', @LogID OUTPUT;
    BEGIN TRY
        TRUNCATE TABLE RetailCO_DW.dbo.FactMetasComerciales;
        INSERT INTO RetailCO_DW.dbo.FactMetasComerciales
            (FechaKey, TiendaKey, VendedorKey, CanalKey, ValorMeta, UnidadesMeta, MetaID)
        SELECT
            CAST(CAST(m.Anio AS VARCHAR(4))
                 + RIGHT('0' + CAST(m.Mes AS VARCHAR(2)), 2)
                 + '01' AS INT),
            dt.TiendaKey,
            ISNULL(dv.VendedorKey, 1),
            1, -- CanalKey default Tienda Fisica (CanalID es NULL en OLTP)
            m.ValorMeta,
            m.UnidadesMeta,
            m.MetaID
        FROM RetailCO_OLTP.dbo.MetasComerciales m
        INNER JOIN RetailCO_DW.dbo.DimTienda   dt ON dt.TiendaID   = m.TiendaID
        LEFT  JOIN RetailCO_DW.dbo.DimVendedor dv ON dv.VendedorID = m.VendedorID;
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'FactMetasComerciales cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err9 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err9;
        PRINT 'Error FactMetas: ' + @Err9;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 11. CARGAR FactDevoluciones
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarFactDevoluciones
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarFactDevoluciones', @LogID OUTPUT;
    BEGIN TRY
        TRUNCATE TABLE RetailCO_DW.dbo.FactDevoluciones;
        INSERT INTO RetailCO_DW.dbo.FactDevoluciones
            (FechaKey, ProductoKey, TiendaKey, ClienteKey, VendedorKey,
             CantidadDevuelta, ValorDevuelto, CostoUnitario, MotivoDev, DevolucionID)
        SELECT
            CAST(CONVERT(VARCHAR(8), TRY_CAST(sd.FechaDevolucion AS DATE), 112) AS INT),
            dp.ProductoKey,
            dt.TiendaKey,
            dc.ClienteKey,
            dv.VendedorKey,
            sd.CantidadDevuelta,
            ISNULL(TRY_CAST(sd.ValorDevuelto AS DECIMAL(12,2)), 0),
            ISNULL(dp.CostoUnitario, 0),
            sd.MotivoDev,
            sd.DevolucionID
        FROM BI_Staging.dbo.Stg_Devoluciones sd
        INNER JOIN RetailCO_DW.dbo.DimProducto dp ON dp.ProductoID = sd.ProductoID AND dp.EsVersionActual = 1
        INNER JOIN RetailCO_DW.dbo.DimTienda   dt ON dt.TiendaID   = sd.TiendaID
        INNER JOIN RetailCO_OLTP.dbo.Ventas     v  ON v.VentaID    = sd.VentaID
        INNER JOIN RetailCO_DW.dbo.DimCliente   dc ON dc.ClienteID = v.ClienteID  AND dc.EsVersionActual = 1
        INNER JOIN RetailCO_DW.dbo.DimVendedor  dv ON dv.VendedorID = v.VendedorID
        WHERE sd.EstadoRegistro = 'Valido';
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'FactDevoluciones cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err10 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err10;
        PRINT 'Error FactDevoluciones: ' + @Err10;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 12. CARGAR FactCompras
-- ============================================================
CREATE OR ALTER PROCEDURE usp_CargarFactCompras
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogID INT, @n INT = 0;
    EXEC usp_LogInicio 'CargarFactCompras', @LogID OUTPUT;
    BEGIN TRY
        TRUNCATE TABLE RetailCO_DW.dbo.FactCompras;
        INSERT INTO RetailCO_DW.dbo.FactCompras
            (FechaKey, ProductoKey, TiendaKey, ProveedorKey,
             CantidadComprada, CostoUnitario, ValorCompra, CompraID, DetalleCompraID)
        SELECT
            CAST(CONVERT(VARCHAR(8), TRY_CAST(sc.FechaRecepcion AS DATE), 112) AS INT),
            dp.ProductoKey,
            dt.TiendaKey,
            dpv.ProveedorKey,
            sc.CantidadComprada,
            ISNULL(TRY_CAST(sc.CostoUnitario AS DECIMAL(12,2)), 0),
            ISNULL(TRY_CAST(sc.Subtotal AS DECIMAL(14,2)), 0),
            sc.CompraID,
            sc.DetalleCompraID
        FROM BI_Staging.dbo.Stg_Compras sc
        INNER JOIN RetailCO_DW.dbo.DimProducto  dp  ON dp.ProductoID   = sc.ProductoID AND dp.EsVersionActual = 1
        INNER JOIN RetailCO_DW.dbo.DimTienda    dt  ON dt.TiendaID     = sc.TiendaID
        INNER JOIN RetailCO_DW.dbo.DimProveedor dpv ON dpv.ProveedorID = sc.ProveedorID
        WHERE sc.EstadoRegistro = 'Valido';
        SET @n = @@ROWCOUNT;
        EXEC usp_LogFin @LogID, 'Exitoso', @n, @n, 0, NULL;
        PRINT 'FactCompras cargada: ' + CAST(@n AS VARCHAR) + ' filas.';
    END TRY
    BEGIN CATCH
        DECLARE @Err11 VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC usp_LogFin @LogID, 'Error', 0, 0, 0, @Err11;
        PRINT 'Error FactCompras: ' + @Err11;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 13. ORQUESTADOR MAESTRO
-- ============================================================
CREATE OR ALTER PROCEDURE usp_EjecutarETL_Completo
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '=== INICIANDO ETL COMPLETO - ' + CONVERT(VARCHAR(30), GETDATE(), 120) + ' ===';

    EXEC usp_CargarDimCanalVenta;
    EXEC usp_CargarDimFecha;
    EXEC usp_ExtractToStaging;
    EXEC usp_ValidarCalidadDatos;
    EXEC usp_CargarDimCliente;
    EXEC usp_CargarDimProducto;
    EXEC usp_CargarDimTiendaVendedor;
    EXEC usp_CargarFactVentas;
    EXEC usp_CargarFactInventario;
    EXEC usp_CargarFactMetas;
    EXEC usp_CargarFactDevoluciones;
    EXEC usp_CargarFactCompras;

    PRINT '=== ETL COMPLETADO - ' + CONVERT(VARCHAR(30), GETDATE(), 120) + ' ===';

    SELECT NombreProceso, Estado, RegistrosCargados, RegistrosRechazados,
           DATEDIFF(SECOND, FechaInicio, FechaFin) AS Segundos,
           MensajeError
    FROM ETL_Log
    ORDER BY LogID DESC;
END;
GO

-- ============================================================
-- EJECUTAR EL PIPELINE COMPLETO
-- ============================================================
EXEC usp_EjecutarETL_Completo;
GO
