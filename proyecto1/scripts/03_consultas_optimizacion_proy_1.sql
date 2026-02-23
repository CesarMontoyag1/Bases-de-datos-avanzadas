
-- Q1 consulta con LIKE

-- indice y trigramas
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_cust_email_trgm 
ON customer USING gin (email gin_trgm_ops);

-- consulta
EXPLAIN (ANALYZE, BUFFERS)
SELECT name, email
FROM customer
WHERE email LIKE '%customer123%';

-- Q2 El Problema de la "Sargabilidad"

-- Consulta problemática (no sargable)
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2023;

-- Versión optimizada (sargable)
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM orders
WHERE order_date >= '2023-01-01'
  AND order_date < '2024-01-01';
  
-- indice propuesto
CREATE INDEX idx_orders_order_date
ON orders (order_date);

-- Q3 Consulta que hace uso de JOIN + WHERE + GROUP BY
EXPLAIN (ANALYZE, BUFFERS)
WITH electronics AS (
  SELECT product_id
  FROM product
  WHERE category = 'Electrónica'
),
orders_year AS (
  SELECT order_id, customer_id
  FROM orders
  WHERE order_date >= '2024-01-01'::timestamptz
  AND order_date <  '2025-01-01'::timestamptz  -- recomendable limitar rango
),
sales_per_order AS (
  SELECT oi.order_id, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM order_item oi
  JOIN electronics e ON oi.product_id = e.product_id
  GROUP BY oi.order_id
)
SELECT c.city, SUM(s.revenue) AS total_revenue
FROM sales_per_order s
JOIN orders_year o ON s.order_id = o.order_id
JOIN customer c ON o.customer_id = c.customer_id
GROUP BY c.city
ORDER BY total_revenue DESC
LIMIT 5;

-- indices propuestos: 

CREATE INDEX CONCURRENTLY idx_product_cat_electronica
  ON product(product_id)
  WHERE category = 'Electrónica';

CREATE INDEX CONCURRENTLY idx_orders_order_date_customer
 ON orders (order_date) INCLUDE (customer_id);

CREATE INDEX CONCURRENTLY idx_order_item_product_id 
 ON order_item(product_id);

CREATE INDEX CONCURRENTLY idx_order_item_prod_includes 
 ON order_item(product_id)
 INCLUDE (order_id, quantity, unit_price);


-- Consultas del informe numero 1 con Big Data: 

-- Q1: Ventas por ciudad en un año 
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.city, SUM(o.total_amount) AS total_sales
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date >= TIMESTAMPTZ '2023-01-01'
  AND o.order_date <  TIMESTAMPTZ '2024-01-01'
GROUP BY c.city
ORDER BY total_sales DESC;

-- Optimizacion:

--Creamos un índice compuesto que incluye la columna del filtro (order_date),
-- la columna del JOIN (customer_id) y agregamos el monto (total_amount) como payload.
CREATE INDEX IF NOT EXISTS idx_orders_order_date_customer 
ON orders (order_date, customer_id) INCLUDE (total_amount);
ANALYZE orders;


-- Q2: Top productos vendidos sin optimizacion
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.name, SUM(oi.quantity) AS total_sold
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
GROUP BY p.name
ORDER BY total_sold DESC
LIMIT 10;

-- Optimizacion:
-- Optimizacion de consulta Q2 sin indices, solo rescribiendo la consulta
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.name, s.total_sold
FROM (
  SELECT product_id, SUM(quantity) AS total_sold
  FROM order_item
  GROUP BY product_id
) s
JOIN product p USING (product_id)
ORDER BY s.total_sold DESC
LIMIT 10;


-- Q3: Dashboard: últimas órdenes de un cliente 
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE customer_id = 12345
ORDER BY order_date DESC
LIMIT 20;

-- Optimizacion:

-- Q3: Índice compuesto: primero por la columna de igualdad (customer_id)
-- y luego por la columna de ordenamiento en la dirección solicitada (DESC).
CREATE INDEX IF NOT EXISTS idx_orders_customer_date_desc 
ON orders(customer_id, order_date DESC);
ANALYZE orders;


--Q4: Degradación típica: LIKE con comodín inicial (no sargable)
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM product
WHERE name ILIKE '%42%'
LIMIT 50;

-- Optimizacion:

-- Habilitamos la extensión de trigramas
CREATE EXTENSION IF NOT EXISTS pg_trgm;
-- Creamos un índice GIN (Generalized Inverted Index) basado en trigramas
CREATE INDEX IF NOT EXISTS idx_product_name_trgm 
ON product USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_product_name_trgm_lower
ON product USING gin (lower(name) gin_trgm_ops);

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM product
WHERE lower(name) LIKE '%42%'
LIMIT 50;


-- Q5: Anti-pattern: función sobre columna en WHERE (rompe uso directo de índice)
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM orders
WHERE date_trunc('day', order_date) = TIMESTAMPTZ '2023-11-15';

-- Optimizacion:

-- Q5: reescribir consulta para usar rango
-- Crea un índice B-Tree normal:
CREATE INDEX idx_orders_order_date ON orders (order_date);
-- Reescribir consulta, en lugar de usar = con una función,
-- usar operadores de rango (>= y <):
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM orders
WHERE order_date >= '2023-11-15 00:00:00'::TIMESTAMPTZ 
  AND order_date < '2023-11-16 00:00:00'::TIMESTAMPTZ;


-- Q6: Join + filtro por status (sin índices)
EXPLAIN (ANALYZE, BUFFERS)
SELECT o.status, count(*) AS n
FROM orders o
JOIN payment p ON p.order_id = o.order_id
WHERE p.payment_status = 'APPROVED'
GROUP BY o.status
ORDER BY n DESC;

-- Optimizacion:

-- Q6:
-- Optimizar la tabla payment (El filtro)
CREATE INDEX idx_payment_status_order_id ON payment (payment_status, order_id);

-- Índice de Cobertura en Orders
CREATE INDEX idx_orders_order_id_status_include ON orders (order_id, status);
ANALYZE orders;



