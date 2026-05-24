-- ============================================================
-- SI3009 Bases de Datos Avanzadas - Proyecto 3
-- SCRIPT 02: Datos Sintéticos Realistas para OLTP
-- Genera: 1000 clientes, 200 productos, 10 tiendas,
--         20 vendedores, ~50.000 ventas, ~150.000 líneas
-- ============================================================

USE RetailCO_OLTP;
GO

-- ============================================================
-- DATOS BASE: GEOGRAFÍAS (ciudades colombianas reales)
-- ============================================================
INSERT INTO Geografias (Ciudad, Departamento, Region) VALUES
('Bogotá',        'Cundinamarca',  'Andina'),
('Medellín',      'Antioquia',     'Andina'),
('Cali',          'Valle del Cauca','Pacífico'),
('Barranquilla',  'Atlántico',     'Caribe'),
('Cartagena',     'Bolívar',       'Caribe'),
('Bucaramanga',   'Santander',     'Andina'),
('Pereira',       'Risaralda',     'Andina'),
('Manizales',     'Caldas',        'Andina'),
('Santa Marta',   'Magdalena',     'Caribe'),
('Cúcuta',        'Norte de Santander','Andina'),
('Ibagué',        'Tolima',        'Andina'),
('Armenia',       'Quindío',       'Andina'),
('Pasto',         'Nariño',        'Andina'),
('Montería',      'Córdoba',       'Caribe'),
('Villavicencio', 'Meta',          'Orinoquía'),
('Soledad',       'Atlántico',     'Caribe'),
('Bello',         'Antioquia',     'Andina'),
('Valledupar',    'Cesar',         'Caribe'),
('Popayán',       'Cauca',         'Andina'),
('Neiva',         'Huila',         'Andina');
GO

-- ============================================================
-- DATOS BASE: CATEGORÍAS (10 categorías de retail)
-- ============================================================
INSERT INTO Categorias (NombreCategoria, Descripcion) VALUES
('Electrónica',         'Dispositivos electrónicos, computadores, accesorios'),
('Ropa y Moda',         'Prendas de vestir para hombres, mujeres y niños'),
('Hogar y Decoración',  'Artículos para el hogar, muebles y decoración'),
('Alimentos',           'Alimentos procesados, snacks y bebidas empacadas'),
('Deportes',            'Artículos deportivos, ropa y equipos'),
('Belleza y Cuidado',   'Cosméticos, perfumería y cuidado personal'),
('Juguetería',          'Juguetes, juegos y artículos infantiles'),
('Librería',            'Libros, papelería y útiles escolares'),
('Ferretería',          'Herramientas, materiales de construcción básicos'),
('Mascotas',            'Alimentos y accesorios para mascotas');
GO

-- ============================================================
-- DATOS BASE: PROVEEDORES (30 proveedores)
-- ============================================================
INSERT INTO Proveedores (NombreEmpresa, Contacto, Telefono, Email, Ciudad, Departamento) VALUES
('Samsung Colombia SAS',      'Carlos Ruiz',      '6015550101', 'ventas@samsung.com.co',    'Bogotá',       'Cundinamarca'),
('Alkosto Distribuciones',    'María Torres',     '6015550102', 'compras@alkosto.com',       'Bogotá',       'Cundinamarca'),
('Leonisa SA',                'Juana Pérez',      '6045550103', 'pedidos@leonisa.com',       'Medellín',     'Antioquia'),
('Alpina Productos Alim.',    'Pedro Gómez',      '6015550104', 'b2b@alpina.com.co',         'Bogotá',       'Cundinamarca'),
('Corona SA',                 'Luisa Vargas',     '6015550105', 'distribución@corona.com.co','Bogotá',       'Cundinamarca'),
('Haceb SA',                  'Andrés Castro',    '6045550106', 'ventas@haceb.com',          'Medellín',     'Antioquia'),
('Nacional de Chocolates',    'Sandra Mora',      '6045550107', 'pedidos@noel.com.co',       'Medellín',     'Antioquia'),
('Colgate Palmolive Col.',    'Felipe Suárez',    '6015550108', 'ventas@colgate.co',         'Bogotá',       'Cundinamarca'),
('Mattel Colombia',           'Gloria Herrera',   '6015550109', 'orders@mattel.com.co',      'Bogotá',       'Cundinamarca'),
('Norma SA',                  'Ricardo León',     '6025550110', 'ventas@norma.com.co',       'Cali',         'Valle del Cauca'),
('Adidas Colombia',           'Camila Díaz',      '6015550111', 'b2b@adidas.com.co',         'Bogotá',       'Cundinamarca'),
('LG Electronics Col.',       'Mauricio Ríos',    '6015550112', 'distribución@lg.com.co',    'Bogotá',       'Cundinamarca'),
('Nestlé Colombia',           'Beatriz Ospina',   '6025550113', 'pedidos@nestle.com.co',     'Cali',         'Valle del Cauca'),
('Homecenter Proveedores',    'David Jiménez',    '6015550114', 'compras@homecenter.co',     'Bogotá',       'Cundinamarca'),
('Nike Colombia SAS',         'Isabel Cortés',    '6015550115', 'b2b@nike.com.co',           'Bogotá',       'Cundinamarca'),
('HP Colombia',               'Tomás Vargas',     '6015550116', 'enterprise@hp.com.co',      'Bogotá',       'Cundinamarca'),
('Unilever Colombia',         'Natalia Franco',   '6015550117', 'ventas@unilever.com.co',    'Bogotá',       'Cundinamarca'),
('Bavaria SA',                'Ernesto Cano',     '6015550118', 'comercial@bavaria.com.co',  'Bogotá',       'Cundinamarca'),
('Familia SA',                'Lorena Pizarro',   '6025550119', 'ventas@familia.com.co',     'Cali',         'Valle del Cauca'),
('Industrias Bachoco',        'Pablo Arango',     '6045550120', 'pedidos@bachoco.com.co',    'Medellín',     'Antioquia'),
('Panasonic Colombia',        'Adriana Soto',     '6015550121', 'ventas@panasonic.com.co',   'Bogotá',       'Cundinamarca'),
('Apple Colombia SAS',        'Sebastián Mora',   '6015550122', 'b2b@apple.com.co',          'Bogotá',       'Cundinamarca'),
('Pelikan Colombia',          'Patricia Leal',    '6015550123', 'pedidos@pelikan.com.co',    'Bogotá',       'Cundinamarca'),
('Barranquilla Sumin.',       'Roberto Núñez',    '6055550124', 'ventas@barrsumin.com.co',   'Barranquilla', 'Atlántico'),
('Continental Gold',          'Elena Zapata',     '6015550125', 'comercial@continentalgold.co','Bogotá',     'Cundinamarca'),
('Coltejer SA',               'Hugo Montoya',     '6045550126', 'ventas@coltejer.com.co',    'Medellín',     'Antioquia'),
('Bayer Colombia',            'Claudia Rivas',    '6015550127', 'b2b@bayer.com.co',          'Bogotá',       'Cundinamarca'),
('Distribuidora Lelo',        'Juan Salcedo',     '6045550128', 'pedidos@lelo.com.co',       'Medellín',     'Antioquia'),
('Almacenes Éxito Distrib.',  'Martha Aguilar',   '6045550129', 'proveedores@exito.com.co',  'Medellín',     'Antioquia'),
('Import. Asia Colombia',     'Lin Wang',         '6015550130', 'ventas@importasia.com.co',  'Bogotá',       'Cundinamarca');
GO

-- ============================================================
-- DATOS BASE: TIENDAS (10 sedes)
-- ============================================================
INSERT INTO Tiendas (CodigoTienda, NombreTienda, GeografiaID, Direccion, Telefono, FechaApertura) VALUES
('T001', 'RetailCO Bogotá Norte',       1,  'Av. 19 # 122-45, Usaquén',                '6015551001', '2018-03-15'),
('T002', 'RetailCO Bogotá Sur',         1,  'Cra. 30 # 1-25 Sur, Kennedy',             '6015551002', '2019-06-01'),
('T003', 'RetailCO Medellín Centro',    2,  'Calle 52 # 43-15, El Centro',             '6045551003', '2018-09-20'),
('T004', 'RetailCO Medellín Laureles',  2,  'Cra. 76 # 34-12, Laureles',               '6045551004', '2020-02-14'),
('T005', 'RetailCO Cali Norte',         3,  'Av. 6N # 25N-40, Granada',                '6025551005', '2019-01-10'),
('T006', 'RetailCO Barranquilla',       4,  'Cra. 43 # 84-15, El Prado',               '6055551006', '2020-07-01'),
('T007', 'RetailCO Cartagena',          5,  'Av. Pedro de Heredia # 31-45',            '6055551007', '2021-03-25'),
('T008', 'RetailCO Bucaramanga',        6,  'Calle 45 # 33-22, Cabecera',              '6075551008', '2020-11-15'),
('T009', 'RetailCO Pereira',            7,  'Av. Las Américas # 23-10',                '6065551009', '2021-06-01'),
('T010', 'RetailCO Santa Marta',        9,  'Cra. 5 # 22-30, El Rodadero',             '6055551010', '2022-01-20');
GO

-- ============================================================
-- DATOS BASE: CANALES DE VENTA
-- ============================================================
INSERT INTO CanalesVenta (NombreCanal, Descripcion) VALUES
('Tienda Física',   'Venta directa en punto de venta físico'),
('E-Commerce',      'Venta a través del sitio web de la empresa'),
('App Móvil',       'Venta mediante la aplicación móvil'),
('Teléfono',        'Venta por línea telefónica o call center'),
('Marketplace',     'Venta a través de plataformas como Mercado Libre');
GO

-- ============================================================
-- DATOS BASE: CAMPAÑAS (12 campañas del año)
-- ============================================================
INSERT INTO Campanas (NombreCampana, TipoDescuento, ValorDescuento, FechaInicio, FechaFin) VALUES
('Año Nuevo 2024',          'Porcentaje', 10.00, '2024-01-01', '2024-01-07'),
('San Valentín 2024',       'Porcentaje', 15.00, '2024-02-10', '2024-02-14'),
('Día del Padre 2024',      'Porcentaje', 12.00, '2024-06-14', '2024-06-16'),
('Mitad de Año 2024',       'Porcentaje', 20.00, '2024-06-30', '2024-07-05'),
('Amor y Amistad 2024',     'Porcentaje', 15.00, '2024-09-13', '2024-09-16'),
('Halloween 2024',          'ValorFijo',  15000, '2024-10-28', '2024-10-31'),
('Black Friday 2024',       'Porcentaje', 30.00, '2024-11-29', '2024-12-02'),
('Navidad 2024',            'Porcentaje', 20.00, '2024-12-20', '2024-12-24'),
('Fin de Año 2024',         'Porcentaje', 25.00, '2024-12-26', '2024-12-31'),
('Día de la Madre 2024',    'Porcentaje', 18.00, '2024-05-12', '2024-05-12'),
('Regreso a Clases 2024',   'Porcentaje', 10.00, '2024-01-15', '2024-01-31'),
('Semana Santa 2024',       'Porcentaje', 12.00, '2024-03-25', '2024-03-31');
GO

-- ============================================================
-- PRODUCTOS (200 productos distribuidos entre 10 categorías)
-- ============================================================
-- Usamos un procedimiento para generar productos realistas

DECLARE @cat INT, @prov INT, @i INT;
DECLARE @nombres TABLE (idx INT IDENTITY(1,1), nombre VARCHAR(150), cat INT, prov INT, precio DECIMAL(12,2), costo DECIMAL(12,2));

INSERT INTO @nombres (nombre, cat, prov, precio, costo) VALUES
-- Electrónica (cat 1)
('Samsung Galaxy A54 128GB',       1,1,  1299000, 890000),
('Samsung Galaxy A34 6GB RAM',     1,1,  999000,  680000),
('LG Monitor 24" Full HD',         1,12, 549000,  380000),
('HP Laptop 15" Core i5',          1,16, 2499000,1750000),
('HP Laptop 14" Core i3',          1,16, 1799000,1250000),
('Apple iPhone 14 128GB',          1,22,4399000, 3100000),
('Apple AirPods 3ra Gen',          1,22, 699000,  480000),
('Panasonic Microondas 20L',       1,21, 349000,  230000),
('Samsung Tablet A7 10"',          1,1,  899000,  620000),
('LG Soundbar 120W',               1,12, 449000,  310000),
('Audífonos Bluetooth Genérico',   1,30, 89000,    55000),
('Cable USB-C 2m',                 1,30, 25000,    12000),
('Cargador Rápido 65W',            1,30, 65000,    38000),
('Mouse Inalámbrico Logitech',     1,30, 79000,    48000),
('Teclado Mecánico Gamer',         1,30, 149000,   95000),
('Webcam Full HD 1080p',           1,30, 119000,   72000),
('Disco Externo 1TB',              1,30, 219000,   145000),
('Memoria USB 64GB',               1,30, 35000,    18000),
('Router WiFi 6 TP-Link',         1,30, 189000,   120000),
('Smart TV 43" 4K',               1,12, 1599000,  1100000),
-- Ropa (cat 2)
('Camiseta Básica Hombre M',      2,26,  49000,  22000),
('Camiseta Básica Hombre L',      2,26,  49000,  22000),
('Jean Slim Fit Hombre 32',       2,26,  129000,  65000),
('Jean Slim Fit Mujer 28',        2,26,  129000,  65000),
('Vestido Casual Mujer T.M',      2,3,   99000,   48000),
('Blusa Manga Larga Mujer',       2,3,   69000,   32000),
('Pantaloneta Deportiva',         2,3,   55000,   25000),
('Chaqueta Impermeable',          2,26, 189000,   95000),
('Medias Paquete x6',             2,26,  25000,   10000),
('Ropa Interior Hombre x3',       2,26,  65000,   30000),
('Blusón Estampado Mujer',        2,3,   85000,   40000),
('Camiseta Polo Hombre',          2,26,  79000,   35000),
('Leggings Deportivos',           2,3,   75000,   34000),
('Pijama Mujer Algodón',          2,3,   89000,   42000),
('Bermuda Cargo Hombre',          2,26, 115000,   55000),
-- Hogar (cat 3)
('Juego Ollas Antiadherente x5',  3,5,  299000,  165000),
('Licuadora 10 Velocidades',      3,6,  179000,  105000),
('Sábana Doble Microfibra',       3,19,  89000,   42000),
('Almohada Memory Foam',          3,19,  59000,   28000),
('Cojín Decorativo 45x45',        3,14,  35000,   16000),
('Porta Vasos Madera x4',         3,14,  45000,   20000),
('Organizador Cajón Cocina',      3,14,  39000,   18000),
('Tapete Sala 1.5x2m',            3,14, 159000,   82000),
('Cortina Blackout 1.4x2.3m',    3,14, 129000,   68000),
('Jabón Líquido Lava Manos 500ml',3,8,   18000,    8000),
('Aspiradora Ciclónica 2200W',    3,6,  449000,  290000),
('Plancha de Vapor 1800W',        3,6,  129000,   72000),
('Secador Cabello 2000W',         3,6,   89000,   50000),
('Batidora Manual 300W',          3,6,   75000,   40000),
('Set Cuchillos x6 Acero',       3,5,   85000,   45000),
-- Alimentos (cat 4)
('Avena Quaker 500g',             4,4,   12000,    7000),
('Arroz Diana x5kg',              4,29,  26000,   18000),
('Aceite Vegetal 1L',             4,29,  18000,   11000),
('Leche en Polvo Klim 400g',     4,13,  35000,   22000),
('Chocolate Jet 500g',            4,7,   28000,   17000),
('Café Juan Valdez 500g',         4,29,  45000,   28000),
('Azúcar Manuelita 1kg',         4,29,   9000,    5500),
('Sal Marina 500g',               4,29,   4500,    2000),
('Sardinas Van Camps x155g',      4,29,   8500,    4500),
('Arvejas con Zanahoria Fruco',   4,29,  12000,    7000),
('Galletas Festival x500g',       4,7,   15000,    8500),
('Kumis Alpina 1L',               4,4,   11000,    6500),
('Yogurt Natural Alpina 1kg',     4,4,   18500,   11000),
('Maizena 400g',                  4,29,  10000,    5500),
('Gelatina Royal Fresa 100g',     4,29,   5500,    2800),
-- Deportes (cat 5)
('Tenis Nike Revolution 6',       5,15, 259000,  145000),
('Tenis Adidas Runfalcon',        5,11, 239000,  130000),
('Balón Fútbol #5 Adidas',       5,11,  99000,   55000),
('Pesas Hexagonales 5kg c/u',    5,14,  85000,   45000),
('Colchoneta Yoga 6mm',          5,14,  75000,   38000),
('Raqueta Tenis Iniciación',     5,14, 149000,   80000),
('Guantes Boxeo Cuero 12oz',     5,14, 129000,   68000),
('Bicicleta Estática Doméstica', 5,14,1299000,  850000),
('Cuerda Saltar Profesional',    5,14,  35000,   16000),
('Mochila Deportiva 30L',        5,14,  89000,   45000),
-- Belleza (cat 6)
('Crema Nivea Body 400ml',       6,8,   28000,   15000),
('Shampoo Head & Shoulders 375ml',6,8,  22000,   12000),
('Desodorante Rexona 150ml',     6,8,   18000,    9500),
('Perfume Hugo Boss 100ml',      6,17,  299000,  160000),
('Labial Maybelline Color Sensational',6,17, 35000, 18000),
('Base de Maquillaje Maybelline',6,17,  65000,   34000),
('Bloqueador Solar SPF50 200ml', 6,27,  45000,   23000),
('Crema Antiarrugas 50ml',       6,27,  79000,   42000),
('Set Cuidado Facial Hombre',    6,8,   89000,   48000),
('Esmalte de Uñas x12 colores', 6,17,  55000,   28000),
-- Juguetería (cat 7)
('LEGO Classic 484 piezas',      7,9,  249000,  140000),
('Muñeca Barbie Fashionista',    7,9,   89000,   47000),
('Hot Wheels Pista Velocidad',   7,9,  129000,   70000),
('Juego de Mesa Monopoly',       7,9,  119000,   62000),
('Rompecabezas 1000 piezas',     7,9,   65000,   33000),
('Carrito Teledirigido',         7,30, 149000,   80000),
('Set Plastilina x12 colores',   7,9,   25000,   12000),
('Bicicleta Niño Rin 20"',      7,14, 399000,  230000),
('Patineta Completa Iniciación', 7,14, 179000,   98000),
('Muñeco de Peluche 40cm',       7,9,   45000,   22000),
-- Librería (cat 8)
('Cuaderno Cuadriculado Norma 100h',8,10, 8500,  4000),
('Esferos BIC x12',               8,10,  12000,  6000),
('Libro Matemáticas 9no Grado',   8,10,  45000, 25000),
('Calculadora Científica Casio', 8,10,  89000,  50000),
('Colores Pelikan x24',           8,23,  25000,  12000),
('Marcadores Exposición x12',     8,23,  18000,   9000),
('Agenda 2024 Ejecutiva',         8,10,  35000,  18000),
('Resma Papel Bond 75g',          8,10,  22000,  12000),
('Diccionario Español Larousse',  8,10,  75000,  40000),
('Tijeras Escolares x6',          8,23,  15000,   7500),
-- Ferretería (cat 9)
('Taladro Percutor 500W',        9,14, 299000, 180000),
('Set Destornilladores x8',      9,14,  65000,  35000),
('Pintura Viniltex Blanco 1gl',  9,14,  95000,  55000),
('Llave Inglesa 10"',            9,14,  45000,  22000),
('Cinta de Enmascarar x10m',     9,14,  12000,   6000),
('Bombillos LED x10 9W',        9,14,  55000,  30000),
('Extensión Eléctrica 5m',       9,14,  35000,  18000),
('Manguera Jardín 15m',          9,14,  89000,  48000),
('Llave Pico de Loro',           9,14,  38000,  19000),
('Caja Herramientas Metálica',   9,14, 179000, 100000),
-- Mascotas (cat 10)
('Concentrado Perro 15kg Purina',10,29, 135000,  82000),
('Concentrado Gato 3kg Royal',   10,29,  65000,  40000),
('Correa Retráctil 5m',         10,14,  55000,  28000),
('Cama Mascotas Talla M',        10,14,  89000,  48000),
('Collar LED Anti-Pérdida',      10,14,  45000,  23000),
('Arena para Gatos 5kg',         10,14,  35000,  17000),
('Shampoo Mascotas 500ml',       10,27,  32000,  16000),
('Juguete Perro Kong Clásico',   10,9,   45000,  23000),
('Vitaminas Perro x60 tabs',     10,27,  55000,  30000),
('Transportador Mascotas S',     10,14,  129000,  70000);

-- Insertar los 200 productos
DECLARE @idx INT = 1;
DECLARE @totalProd INT = 110; -- los que ya definimos
WHILE @idx <= @totalProd
BEGIN
    INSERT INTO Productos (CodigoSKU, NombreProducto, CategoriaID, ProveedorID, PrecioUnitario, CostoUnitario)
    SELECT 
        'SKU' + RIGHT('000' + CAST(@idx AS VARCHAR), 4),
        nombre,
        cat,
        prov,
        precio,
        costo
    FROM @nombres WHERE idx = @idx;
    SET @idx += 1;
END

-- Completar hasta 200 con variaciones
SET @idx = 111;
WHILE @idx <= 200
BEGIN
    INSERT INTO Productos (CodigoSKU, NombreProducto, CategoriaID, ProveedorID, PrecioUnitario, CostoUnitario)
    SELECT
        'SKU' + RIGHT('000' + CAST(@idx AS VARCHAR), 4),
        nombre + ' (Var ' + CAST(@idx - 110 AS VARCHAR) + ')',
        cat,
        prov,
        precio * (1 + ((@idx % 5) * 0.05)),
        costo * (1 + ((@idx % 5) * 0.05))
    FROM @nombres WHERE idx = ((@idx - 111) % 110) + 1;
    SET @idx += 1;
END
GO

-- ============================================================
-- VENDEDORES (20 vendedores, 2 por tienda)
-- ============================================================
DECLARE @t INT = 1;
DECLARE @v INT = 1;
DECLARE @nombresV TABLE (idx INT IDENTITY(1,1), nom VARCHAR(80), ape VARCHAR(80));
INSERT INTO @nombresV (nom, ape) VALUES
('Juan Carlos','Rodríguez Peña'),('María Alejandra','González López'),
('Carlos Andrés','Martínez Ruiz'),('Laura Valentina','Hernández Torres'),
('Sergio Iván','García Moreno'),('Ana María','López Jiménez'),
('Diego Fernando','Ramírez Castro'),('Valentina','Pérez Sánchez'),
('Andrés Felipe','Gómez Vargas'),('Daniela','Rojas Mendoza'),
('Felipe','Morales Quintero'),('Camila Andrea','Suárez Pinto'),
('Julián','Reyes Ávila'),('Paola Andrea','Castillo Bermúdez'),
('Esteban','Herrera Muñoz'),('Natalia','Jiménez Acosta'),
('David','Díaz Romero'),('Alejandra','Mora Salcedo'),
('Sebastián','Vargas Ríos'),('Karen','Ochoa Mejía');

WHILE @v <= 20
BEGIN
    DECLARE @tid INT = ((@v - 1) / 2) + 1;
    INSERT INTO Vendedores (Cedula, Nombres, Apellidos, TiendaID, Cargo, Email, FechaIngreso)
    SELECT
        '10' + RIGHT('0000000' + CAST(1000000 + @v AS VARCHAR), 7),
        nom,
        ape,
        @tid,
        CASE WHEN @v % 2 = 0 THEN 'Asesor Comercial' ELSE 'Supervisor de Ventas' END,
        LOWER(REPLACE(nom,' ','')) + '.' + LOWER(REPLACE(ape,' ','_')) + '@retailco.com.co',
        DATEADD(DAY, -ABS(CHECKSUM(NEWID()) % 1826), '2024-01-01')
    FROM @nombresV WHERE idx = @v;
    SET @v += 1;
END
GO

-- ============================================================
-- CLIENTES (1000 clientes con datos realistas)
-- ============================================================
DECLARE @i INT = 1;
DECLARE @geo INT;
DECLARE @ciudadesNombres TABLE (idx INT IDENTITY(1,1), nombre VARCHAR(40));
INSERT INTO @ciudadesNombres VALUES ('Bogotá'),('Medellín'),('Cali'),('Barranquilla'),
    ('Cartagena'),('Bucaramanga'),('Pereira'),('Manizales'),('Santa Marta'),('Cúcuta');

DECLARE @prefNombM TABLE(idx INT IDENTITY(1,1), n VARCHAR(40));
DECLARE @prefNombF TABLE(idx INT IDENTITY(1,1), n VARCHAR(40));
DECLARE @prefApe  TABLE(idx INT IDENTITY(1,1), a VARCHAR(40));
INSERT INTO @prefNombM VALUES ('Juan'),('Carlos'),('Andrés'),('Diego'),('Sergio'),('Felipe'),('Jorge'),('Alejandro'),('Luis'),('Daniel');
INSERT INTO @prefNombF VALUES ('María'),('Laura'),('Valentina'),('Camila'),('Paola'),('Natalia'),('Daniela'),('Ana'),('Karen'),('Juliana');
INSERT INTO @prefApe  VALUES ('García'),('Rodríguez'),('López'),('Martínez'),('González'),('Hernández'),('Pérez'),('Sánchez'),('Ramírez'),('Torres'),
                              ('Flores'),('Gómez'),('Díaz'),('Moreno'),('Ruiz'),('Castro'),('Vargas'),('Romero'),('Jiménez'),('Suárez');

WHILE @i <= 1000
BEGIN
    SET @geo = (@i % 20) + 1;
    DECLARE @esM BIT = CASE WHEN @i % 2 = 0 THEN 1 ELSE 0 END;
    DECLARE @nomIdx INT = (@i % 10) + 1;
    DECLARE @apeIdx1 INT = (@i % 20) + 1;
    DECLARE @apeIdx2 INT = ((@i + 5) % 20) + 1;

    DECLARE @nomC VARCHAR(80) = CASE WHEN @esM = 1
        THEN (SELECT n FROM @prefNombM WHERE idx = @nomIdx)
        ELSE (SELECT n FROM @prefNombF WHERE idx = @nomIdx) END;
    DECLARE @apeC1 VARCHAR(40) = (SELECT a FROM @prefApe WHERE idx = @apeIdx1);
    DECLARE @apeC2 VARCHAR(40) = (SELECT a FROM @prefApe WHERE idx = @apeIdx2);
    DECLARE @seg VARCHAR(40) = CASE 
        WHEN @i % 10 = 0 THEN 'VIP'
        WHEN @i % 4 = 0 THEN 'Frecuente'
        WHEN @i % 7 = 0 THEN 'Nuevo'
        ELSE 'Regular' END;

    INSERT INTO Clientes (Cedula, Nombres, Apellidos, Email, Telefono, GeografiaID, Genero, Segmento, FechaRegistro)
    VALUES (
        CAST(10000000 + @i AS VARCHAR),
        @nomC + CASE WHEN @i % 3 = 0 THEN ' Alberto' ELSE '' END,
        @apeC1 + ' ' + @apeC2,
        LOWER(@nomC) + CAST(@i AS VARCHAR) + '@gmail.com',
        '3' + RIGHT('0' + CAST(100000000 + ABS(CHECKSUM(NEWID())) % 900000000 AS VARCHAR),9),
        @geo,
        CASE WHEN @esM = 1 THEN 'M' ELSE 'F' END,
        @seg,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID()) % 1826), '2024-01-01')
    );
    SET @i += 1;
END
GO

-- ============================================================
-- INVENTARIO INICIAL (stock base para todas las tiendas)
-- ============================================================
INSERT INTO InventarioDiario (FechaRegistro, ProductoID, TiendaID, StockInicial, Entradas, Salidas, Ajustes, StockFinal)
SELECT
    '2023-12-31',
    p.ProductoID,
    t.TiendaID,
    100 + (ABS(CHECKSUM(NEWID())) % 400) AS StockInicial,
    0, 0, 0,
    100 + (ABS(CHECKSUM(NEWID())) % 400) AS StockFinal
FROM Productos p CROSS JOIN Tiendas t;
GO

-- ============================================================
-- VENTAS Y DETALLE (~50.000 ventas, ~150.000 líneas)
-- Generación masiva en bloques por mes (2024 completo)
-- ============================================================
DECLARE @fecha DATE = '2024-01-01';
DECLARE @ventaNum INT = 1;
DECLARE @totalVentas INT = 0;

WHILE @fecha <= '2024-12-31'
BEGIN
    -- Número de ventas por día: entre 120-200 (varía entre tiendas)
    DECLARE @ventasDia INT = 120 + (ABS(CHECKSUM(NEWID())) % 80);
    DECLARE @d INT = 1;
    
    WHILE @d <= @ventasDia
    BEGIN
        DECLARE @cli   INT = 1 + (ABS(CHECKSUM(NEWID())) % 1000);
        DECLARE @tienda INT = 1 + (ABS(CHECKSUM(NEWID())) % 10);
        DECLARE @vend  INT;
        -- Vendedor de esa tienda
        SELECT @vend = MIN(VendedorID) + (ABS(CHECKSUM(NEWID())) % 2)
        FROM Vendedores WHERE TiendaID = @tienda;

        DECLARE @canal INT = 1 + (ABS(CHECKSUM(NEWID())) % 5);
        DECLARE @campana INT = NULL;
        -- Asignar campaña si la fecha cae en rango
        SELECT TOP 1 @campana = CampanaID 
        FROM Campanas 
        WHERE @fecha BETWEEN FechaInicio AND FechaFin;

        DECLARE @numFac VARCHAR(30) = 'FAC-' + RIGHT('000000' + CAST(@ventaNum AS VARCHAR), 7);
        DECLARE @hora TIME = CAST(CAST(8 + (ABS(CHECKSUM(NEWID())) % 12) AS VARCHAR) + ':' 
                              + CAST(ABS(CHECKSUM(NEWID())) % 60 AS VARCHAR) + ':00' AS TIME);
        DECLARE @fechaHora DATETIME = CAST(@fecha AS DATETIME) + CAST(@hora AS DATETIME);

        INSERT INTO Ventas (NumeroFactura, FechaVenta, ClienteID, TiendaID, VendedorID, CanalID, CampanaID, Estado)
        VALUES (@numFac, @fechaHora, @cli, @tienda, @vend, @canal, @campana, 'Completada');

        DECLARE @vid INT = SCOPE_IDENTITY();

        -- Detalle: entre 1 y 5 líneas por venta
        DECLARE @lineas INT = 1 + (ABS(CHECKSUM(NEWID())) % 5);
        DECLARE @l INT = 1;
        DECLARE @totalBruto DECIMAL(14,2) = 0;
        DECLARE @totalDesc  DECIMAL(14,2) = 0;

        WHILE @l <= @lineas
        BEGIN
            DECLARE @prod  INT = 1 + (ABS(CHECKSUM(NEWID())) % 200);
            DECLARE @cant  INT = 1 + (ABS(CHECKSUM(NEWID())) % 5);
            DECLARE @pUnit DECIMAL(12,2);
            DECLARE @cUnit DECIMAL(12,2);
            SELECT @pUnit = PrecioUnitario, @cUnit = CostoUnitario FROM Productos WHERE ProductoID = @prod;
            DECLARE @desc DECIMAL(8,2) = CASE WHEN @campana IS NOT NULL THEN 10 + (ABS(CHECKSUM(NEWID())) % 20) ELSE 0 END;
            DECLARE @sub  DECIMAL(14,2) = @cant * @pUnit * (1 - @desc/100.0);

            INSERT INTO DetalleVentas (VentaID, ProductoID, Cantidad, PrecioUnitario, CostoUnitario, Descuento, Subtotal)
            VALUES (@vid, @prod, @cant, @pUnit, @cUnit, @desc, @sub);

            SET @totalBruto += @cant * @pUnit;
            SET @totalDesc  += @cant * @pUnit * (@desc/100.0);
            SET @l += 1;
        END

        UPDATE Ventas 
        SET TotalBruto = @totalBruto, TotalDescuento = @totalDesc, TotalNeto = @totalBruto - @totalDesc
        WHERE VentaID = @vid;

        SET @ventaNum += 1;
        SET @d += 1;
    END

    -- Inventario diario: actualizar stock
    INSERT INTO InventarioDiario (FechaRegistro, ProductoID, TiendaID, StockInicial, Salidas, Entradas, Ajustes, StockFinal)
    SELECT
        @fecha,
        p.ProductoID,
        t.TiendaID,
        ISNULL(prev.StockFinal, 50),
        ISNULL(sal.Salidas, 0),
        CASE WHEN ABS(CHECKSUM(NEWID())) % 30 = 0 THEN 50 + ABS(CHECKSUM(NEWID())) % 100 ELSE 0 END,
        0,
        ISNULL(prev.StockFinal, 50) 
            - ISNULL(sal.Salidas, 0) 
            + CASE WHEN ABS(CHECKSUM(NEWID())) % 30 = 0 THEN 50 + ABS(CHECKSUM(NEWID())) % 100 ELSE 0 END
    FROM Productos p
    CROSS JOIN Tiendas t
    LEFT JOIN InventarioDiario prev 
        ON prev.ProductoID = p.ProductoID AND prev.TiendaID = t.TiendaID 
        AND prev.FechaRegistro = DATEADD(DAY,-1,@fecha)
    LEFT JOIN (
        SELECT dv.ProductoID, v.TiendaID, SUM(dv.Cantidad) AS Salidas
        FROM DetalleVentas dv
        INNER JOIN Ventas v ON v.VentaID = dv.VentaID
        WHERE CAST(v.FechaVenta AS DATE) = @fecha
        GROUP BY dv.ProductoID, v.TiendaID
    ) sal ON sal.ProductoID = p.ProductoID AND sal.TiendaID = t.TiendaID;

    SET @fecha = DATEADD(DAY, 1, @fecha);
    IF @totalVentas % 10000 = 0
        PRINT 'Progreso: ' + CAST(@ventaNum AS VARCHAR) + ' ventas generadas...';
    SET @totalVentas += @ventasDia;
END
GO

-- ============================================================
-- COMPRAS (reabastecimiento, ~1200 órdenes)
-- ============================================================
DECLARE @oc INT = 1;
WHILE @oc <= 1200
BEGIN
    DECLARE @fechaOC DATE = DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 365, '2024-01-01');
    DECLARE @tiendaOC INT = 1 + (ABS(CHECKSUM(NEWID())) % 10);
    DECLARE @provOC   INT = 1 + (ABS(CHECKSUM(NEWID())) % 30);

    INSERT INTO Compras (NumeroOrden, FechaCompra, FechaRecepcion, ProveedorID, TiendaID, Estado)
    VALUES (
        'OC-' + RIGHT('000000' + CAST(@oc AS VARCHAR), 6),
        CAST(@fechaOC AS DATETIME),
        DATEADD(DAY, 5 + ABS(CHECKSUM(NEWID())) % 15, @fechaOC),
        @provOC,
        @tiendaOC,
        'Recibida'
    );
    DECLARE @cid INT = SCOPE_IDENTITY();
    DECLARE @totalOC DECIMAL(14,2) = 0;

    DECLARE @lc INT = 1;
    WHILE @lc <= (2 + ABS(CHECKSUM(NEWID())) % 8)
    BEGIN
        DECLARE @prodOC INT = 1 + (ABS(CHECKSUM(NEWID())) % 200);
        DECLARE @cantOC INT = 20 + ABS(CHECKSUM(NEWID())) % 100;
        DECLARE @costoOC DECIMAL(12,2);
        SELECT @costoOC = CostoUnitario FROM Productos WHERE ProductoID = @prodOC;
        DECLARE @subOC DECIMAL(14,2) = @cantOC * @costoOC;

        INSERT INTO DetalleCompras (CompraID, ProductoID, Cantidad, CostoUnitario, Subtotal)
        VALUES (@cid, @prodOC, @cantOC, @costoOC, @subOC);

        SET @totalOC += @subOC;
        SET @lc += 1;
    END

    UPDATE Compras SET TotalCompra = @totalOC WHERE CompraID = @cid;
    SET @oc += 1;
END
GO

-- ============================================================
-- DEVOLUCIONES (~2% de ventas = ~1000 devoluciones)
-- ============================================================
DECLARE @dev INT = 1;
WHILE @dev <= 1000
BEGIN
    DECLARE @ventaBase INT = @dev * 50; -- cada 50 ventas aprox 1 devolución
    IF @ventaBase > (SELECT MAX(VentaID) FROM Ventas) SET @ventaBase = @dev;

    DECLARE @prodDev INT;
    DECLARE @tiendaDev INT;
    DECLARE @cantVendida INT;

    SELECT TOP 1 @prodDev = dv.ProductoID, @tiendaDev = v.TiendaID, @cantVendida = dv.Cantidad
    FROM DetalleVentas dv INNER JOIN Ventas v ON v.VentaID = dv.VentaID
    WHERE dv.VentaID = @ventaBase;

    IF @prodDev IS NOT NULL
    BEGIN
        DECLARE @valorDev DECIMAL(12,2);
        SELECT @valorDev = PrecioUnitario FROM Productos WHERE ProductoID = @prodDev;

        INSERT INTO Devoluciones (NumeroDevolucion, FechaDevolucion, VentaID, ProductoID, TiendaID, 
                                  CantidadDevuelta, MotivoDev, ValorDevuelto)
        VALUES (
            'DEV-' + RIGHT('000000' + CAST(@dev AS VARCHAR), 6),
            DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 30, (SELECT FechaVenta FROM Ventas WHERE VentaID = @ventaBase)),
            @ventaBase,
            @prodDev,
            @tiendaDev,
            1,
            CASE ABS(CHECKSUM(NEWID())) % 4 WHEN 0 THEN 'Defecto' WHEN 1 THEN 'Cambio' WHEN 2 THEN 'Error' ELSE 'Otro' END,
            @valorDev
        );
    END
    SET @dev += 1;
END
GO

-- ============================================================
-- METAS COMERCIALES (12 meses x 10 tiendas x 10 categorías)
-- ============================================================
DECLARE @mes INT, @anio INT = 2024, @tMeta INT, @cMeta INT;
SET @mes = 1;
WHILE @mes <= 12
BEGIN
    SET @tMeta = 1;
    WHILE @tMeta <= 10
    BEGIN
        SET @cMeta = 1;
        WHILE @cMeta <= 10
        BEGIN
            INSERT INTO MetasComerciales (Anio, Mes, TiendaID, CategoriaID, ValorMeta, UnidadesMeta)
            VALUES (
                @anio, @mes, @tMeta, @cMeta,
                5000000 + (ABS(CHECKSUM(NEWID())) % 45000000),
                500 + (ABS(CHECKSUM(NEWID())) % 4500)
            );
            SET @cMeta += 1;
        END
        SET @tMeta += 1;
    END
    SET @mes += 1;
END
GO

PRINT '✅ Datos sintéticos generados exitosamente.';
PRINT 'Clientes: 1000 | Productos: 200 | Tiendas: 10 | Vendedores: 20';
PRINT 'Ventas: ~50.000 | Líneas: ~150.000 | Inventario: 365 días';
GO
