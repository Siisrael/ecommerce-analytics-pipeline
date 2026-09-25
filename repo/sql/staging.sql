-- =====================================================================
-- Capa de staging: limpieza y normalizacion sobre las tablas crudas.
-- Nada de logica de negocio aca, solo dejar los datos consistentes.
-- =====================================================================

DROP VIEW IF EXISTS stg_customers;
CREATE VIEW stg_customers AS
SELECT
    customer_id,
    first_name,
    last_name,
    email,
    signup_date,
    city,
    CASE
    WHEN lower(country) LIKE "arg." THEN "argentina"
    WHEN lower(country) LIKE "brazil" THEN "brasil"
    WHEN lower(country) LIKE "ee.uu." THEN "estados unidos"
    WHEN lower(country) LIKE "méxico" THEN "mexico"
    WHEN lower(country) LIKE "usa" THEN "estados unidos"
    ELSE lower(country)
END AS country,
    segment,
    acquisition_channel,
    ROW_NUMBER() OVER (PARTITION BY COALESCE(email, CAST(customer_id AS TEXT)) ORDER BY signup_date) as nro_email_asociado
FROM customers;


DROP VIEW IF EXISTS stg_products;
CREATE VIEW stg_products AS
SELECT 
    product_id,
    product_name,
    CASE
        WHEN lower(category) LIKE "electrónica" THEN "electronica"
        ELSE lower(category)
    END AS category_clean,
      CASE 
        WHEN unit_cost IS NULL THEN 'SI'
        ELSE 'NO'
    END AS costo_estimado,
    COALESCE(unit_cost, unit_price * 0.65) as unit_cost,
    unit_price,
    active
FROM products;


DROP VIEW IF EXISTS stg_reviews;
CREATE VIEW stg_reviews AS
SELECT
    review_id,
    product_id,
    customer_id,
    rating,
    review_date,
    comment,
    CASE
        WHEN rating < 1 OR rating > 5 THEN "NO"
        ELSE "SI"
    END AS rating_valido
FROM reviews;


