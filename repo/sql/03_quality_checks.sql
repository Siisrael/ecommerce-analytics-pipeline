-- =====================================================================
-- Controles de calidad de datos.
-- Cada query devuelve la cantidad de filas que INCUMPLEN la regla:
-- el resultado esperado es 0. Las excepciones conocidas estan comentadas.
-- =====================================================================

-- 1. Completitud: clientes sin email
SELECT 'customers.email nulo' AS regla, COUNT(*) AS filas_en_falta
FROM customers WHERE email IS NULL OR TRIM(email) = '';

-- 2. Completitud: clientes sin ciudad
SELECT 'customers.city nulo' AS regla, COUNT(*) AS filas_en_falta
FROM customers WHERE city IS NULL OR TRIM(city) = '';

-- 3. Unicidad: emails repetidos (un mismo cliente cargado dos veces)
SELECT 'customers.email duplicado' AS regla, COUNT(*) AS filas_en_falta
FROM (SELECT email FROM customers WHERE email IS NOT NULL
      GROUP BY LOWER(TRIM(email)) HAVING COUNT(*) > 1);

-- 4. Completitud: productos sin costo unitario.
--    Excepcion conocida: stg_products los imputa como unit_price * 0.65
--    y los marca con la bandera costo_estimado = 'SI'.
SELECT 'products.unit_cost nulo (imputado)' AS regla, COUNT(*) AS filas_en_falta
FROM products WHERE unit_cost IS NULL;

-- 5. Rango: precios o costos que no son positivos
SELECT 'products precio/costo <= 0' AS regla, COUNT(*) AS filas_en_falta
FROM products WHERE unit_price <= 0 OR (unit_cost IS NOT NULL AND unit_cost <= 0);

-- 6. Consistencia: costo mayor al precio de venta (margen negativo)
SELECT 'products unit_cost > unit_price' AS regla, COUNT(*) AS filas_en_falta
FROM products WHERE unit_cost IS NOT NULL AND unit_cost > unit_price;

-- 7. Rango: rating fuera de la escala 1-5
SELECT 'reviews.rating fuera de 1-5' AS regla, COUNT(*) AS filas_en_falta
FROM reviews WHERE rating < 1 OR rating > 5;

-- 8. Integridad referencial: items que apuntan a una orden inexistente
SELECT 'order_items.order_id huerfano' AS regla, COUNT(*) AS filas_en_falta
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- 9. Integridad referencial: items que apuntan a un producto inexistente
SELECT 'order_items.product_id huerfano' AS regla, COUNT(*) AS filas_en_falta
FROM order_items oi
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;

-- 10. Integridad referencial: ordenes de un cliente inexistente
SELECT 'orders.customer_id huerfano' AS regla, COUNT(*) AS filas_en_falta
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- 11. Completitud: campanias sin presupuesto.
--     Impacta directo en rpt_roi_campanias: sin budget_usd el ROI queda NULL.
SELECT 'marketing_campaigns.budget_usd nulo' AS regla, COUNT(*) AS filas_en_falta
FROM marketing_campaigns WHERE budget_usd IS NULL;

-- 12. Rango: descuentos fuera de 0-100
SELECT 'order_items.discount_pct fuera de 0-100' AS regla, COUNT(*) AS filas_en_falta
FROM order_items WHERE discount_pct < 0 OR discount_pct > 100;

-- 13. Regla de negocio: las cantidades negativas representan devoluciones y solo
--     pueden aparecer en ordenes 'Reembolsado'. Una cantidad negativa en
--     cualquier otro estado es un error de carga.
SELECT 'order_items.quantity < 0 fuera de Reembolsado' AS regla, COUNT(*) AS filas_en_falta
FROM order_items oi
INNER JOIN orders o ON o.order_id = oi.order_id
WHERE oi.quantity < 0 AND o.status != 'Reembolsado';

-- 14. Rango: cantidad igual a cero (una linea de pedido sin unidades no tiene sentido)
SELECT 'order_items.quantity = 0' AS regla, COUNT(*) AS filas_en_falta
FROM order_items WHERE quantity = 0;

-- 15. Consistencia temporal: orden anterior al alta del cliente
SELECT 'orders.order_date < customers.signup_date' AS regla, COUNT(*) AS filas_en_falta
FROM orders o
INNER JOIN customers c ON c.customer_id = o.customer_id
WHERE DATE(o.order_date) < DATE(c.signup_date);

-- 16. Dominio: estados de orden fuera de los valores esperados
SELECT 'orders.status fuera de dominio' AS regla, COUNT(*) AS filas_en_falta
FROM orders
WHERE status NOT IN ('Completado','Cancelado','Reembolsado','Pendiente','Enviado');

-- 17. Normalizacion: paises que siguen sin unificar despues del staging
--     (arg. / ARG / Argentina deben colapsar en un unico valor)
SELECT 'stg_customers.country sin normalizar' AS regla, COUNT(*) AS filas_en_falta
FROM (SELECT country FROM stg_customers GROUP BY country) x
WHERE country LIKE '%.%' OR country != LOWER(country);
