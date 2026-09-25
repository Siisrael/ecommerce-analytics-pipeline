-- =====================================================================
-- Capa de reporting: vistas de negocio construidas con CTEs sobre staging.
-- Son las que consume el dashboard de Power BI y la API.
-- =====================================================================

DROP VIEW IF EXISTS rpt_revenue_mensual_categoria;
CREATE VIEW rpt_revenue_mensual_categoria AS

    WITH OrdenesProductos AS (

    SELECT
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        o.status,
        strftime('%Y-%m', o.order_date) AS mes 
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    ),

    OrdenesCompletas AS (

        SELECT 
            op.order_id,
            op.product_id,
            op.quantity,
            op.unit_price,
            op.discount_pct,
            op.status,
            p.category_clean,
            op.mes
        FROM OrdenesProductos op
        INNER JOIN stg_products p ON p.product_id = op.product_id
    )

    SELECT 
        mes,
        category_clean,
        SUM(quantity*(unit_price - unit_price*(discount_pct*0.01))) AS revenue
    FROM OrdenesCompletas
    WHERE OrdenesCompletas.status = 'Completado'
    GROUP BY mes, category_clean;


DROP VIEW IF EXISTS rpt_top_productos_revenue_margen;
CREATE VIEW rpt_top_productos_revenue_margen AS
WITH OrdenesProductos AS (

    SELECT
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        o.status
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE status = 'Completado'
    ),
    
    ProductosDeOrdeneesCompletadas AS (

        SELECT 
            op.order_id,
            op.product_id,
            op.quantity,
            op.unit_price,
            op.discount_pct,
            op.status,
            p.unit_cost,
            p.product_name
        FROM OrdenesProductos op
        INNER JOIN stg_products p ON p.product_id = op.product_id
    )
    
SELECT 
    product_name,
    SUM(quantity*(unit_price - unit_price*(discount_pct*0.01))) AS revenue,
    (SUM(quantity*((unit_price - unit_price*(discount_pct*0.01))-unit_cost))/SUM(quantity*(unit_price - unit_price*(discount_pct*0.01))))*100 as pctMargin, --margen $ / revenue
    SUM(quantity*((unit_price - unit_price*(discount_pct*0.01))-unit_cost)) as margin
    
FROM ProductosDeOrdeneesCompletadas
GROUP BY product_name
ORDER BY revenue DESC;


DROP VIEW IF EXISTS rpt_aov_por_pais;
CREATE VIEW rpt_aov_por_pais AS 

WITH OrdenesProductosCustomers AS (

    SELECT
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct,
        o.status,
        o.customer_id
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.order_id
    WHERE status = 'Completado'
    ),
    
    OrdenesPorPaises AS (

        SELECT 
            op.order_id,
            op.product_id,
            op.quantity,
            op.unit_price,
            op.discount_pct,
            op.status,
            c.country
        FROM OrdenesProductosCustomers op
        INNER JOIN stg_customers c ON c.customer_id = op.customer_id
    ),

    RevenuePorOrder AS (
    
    SELECT 
        country,
        order_id,
        SUM(quantity*(unit_price - unit_price*(discount_pct*0.01))) AS revenue

    FROM OrdenesPorPaises
    GROUP BY order_id,country

)

SELECT
    country,
    AVG(revenue) AS RevenuePromedio
FROM RevenuePorOrder
GROUP BY country
ORDER BY RevenuePromedio;


DROP VIEW IF EXISTS rpt_ltv_por_canal;
CREATE VIEW rpt_ltv_por_canal AS

WITH channelPorCustomer AS (
    SELECT
        c.customer_id,
        o.order_id,
        c.acquisition_channel
    FROM stg_customers c
    INNER JOIN orders o ON c.customer_id = o.customer_id
),

RevenuePorChannel AS (
    SELECT 
        c.order_id,
        c.customer_id,
        c.acquisition_channel,
        oi.quantity,
        oi.unit_price,
        oi.discount_pct
    FROM channelPorCustomer c
    INNER JOIN order_items oi ON oi.order_id = c.order_id
),

RevenuePorChannelCompletadas AS (
    SELECT 
        r.order_id,
        r.customer_id,
        r.acquisition_channel,
        r.quantity,
        r.unit_price,
        r.discount_pct
    FROM RevenuePorChannel r
    INNER JOIN orders o ON o.order_id = r.order_id
    WHERE status = 'Completado'
),

ltvPorCleinte AS (
    SELECT 
        acquisition_channel,
        customer_id,
        SUM(quantity*(unit_price - unit_price*(discount_pct*0.01))) AS revenue
    FROM RevenuePorChannelCompletadas
    GROUP BY customer_id, acquisition_channel
)

SELECT 
    acquisition_channel,
    COUNT(DISTINCT(customer_id)) as cantidadDeClientes,
    SUM(revenue) as revenueTotal,
    AVG(revenue) as LTV
FROM ltvPorCleinte
GROUP BY acquisition_channel;


DROP VIEW IF EXISTS rpt_roi_campanias;
CREATE VIEW rpt_roi_campanias AS

WITH soloOrdeneesCompletadas AS(

    SELECT
        order_id,
        o.customer_id,
        o.status,
        o.campaign_id
        
    
    FROM orders o
    WHERE status = 'Completado'
),


 campanaCustomers AS(

    SELECT 
        o.order_id,
        o.customer_id,
        o.status,
        o.campaign_id,
        mc.channel,
        mc.campaign_name,
        mc.budget_usd
    
    
    FROM marketing_campaigns mc
    LEFT JOIN soloOrdeneesCompletadas o ON mc.campaign_id = o.campaign_id

),

    campamaRevenue AS (
        SELECT 
            cc.order_id,
            cc.campaign_name,
            cc.channel,
            cc.budget_usd,
            coalesce(SUM(oi.quantity*(oi.unit_price - oi.unit_price*(oi.discount_pct*0.01))),0) AS revenue
            
            
        FROM campanaCustomers cc
        LEFT JOIN order_items oi ON oi.order_id = cc.order_id
        GROUP BY cc.order_id,cc.campaign_name,cc.channel,cc.budget_usd
    

),
    
    porCampana AS(

SELECT 
    campaign_name,
    channel,
    budget_usd,
    SUM(revenue) AS revenue

FROM campamaRevenue
GROUP BY campaign_name,channel,budget_usd

)

SELECT
    campaign_name,
    channel,
    budget_usd,
    revenue,
    ((revenue - budget_usd)/budget_usd)*100 as roi
FROM porCampana;


DROP VIEW IF EXISTS rpt_recompra;
CREATE VIEW rpt_recompra AS

WITH clientesUnicos AS(

    SELECT 
        customer_id,
        COUNT(order_id) as cantidadDeOperaciones
    
    FROM orders
    WHERE status = 'Completado'
    GROUP BY customer_id

),
    datosClientes AS(
    
    SELECT 
        COUNT(DISTINCT(customer_id)) as cantidadDeClientes,
        COUNT(DISTINCT CASE
            WHEN cantidadDeOperaciones >= 2 THEN customer_id
            ELSE NULL
        END) AS clientesRecompra,
        COUNT(DISTINCT CASE
            WHEN cantidadDeOperaciones < 2 THEN customer_id
            ELSE NULL
        END) AS clientesUnacompra
        

    FROM clientesUnicos

)

SELECT 
    cantidadDeClientes,
    clientesRecompra,
    clientesUnaCompra,
    (clientesRecompra*1.0/cantidadDeClientes)*100 as tasaRecompra
    
FROM datosClientes;


DROP VIEW IF EXISTS rpt_estacionalidad;
CREATE VIEW rpt_estacionalidad AS 
WITH revenuePorDiaYmes AS (

SELECT 
    CASE cast(strftime('%w',o.order_date) as INTEGER)
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miercoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sabado'
    END AS dia_de_la_semana,
    
    strftime('%m',o.order_date) as mes,
    SUM(oi.quantity*(oi.unit_price - oi.unit_price*(oi.discount_pct*0.01))) AS revenue
    
    


FROM order_items oi
INNER JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 'Completado'
GROUP BY o.order_id

)

SELECT 
    mes,
    dia_de_la_semana,
    SUM(revenue) as rev


FROM revenuePorDiaYmes
GROUP BY mes,dia_de_la_semana;


DROP VIEW IF EXISTS rpt_rating_vs_ventas;
CREATE VIEW rpt_rating_vs_ventas AS
WITH porductsReviews AS (

    SELECT 
        product_id,
        AVG(rating) as ratingPromedio,
        COUNT(rating) as cantidadReviews
    FROM stg_reviews
    WHERE rating_valido = 'SI'
    GROUP BY product_id

),

    ordenes AS(
    
    SELECT
        oi.product_id,
        SUM(oi.quantity) as cantidad
        
    FROM order_items oi
    INNER JOIN orders o ON o.order_id = oi.order_id
    WHERE o.status = 'Completado'
    GROUP BY oi.product_id
    
),

final AS (

SELECT 
    o.product_id,
    o.cantidad,
    p.cantidadReviews,
    p.ratingPromedio
    
    FROM porductsReviews p
    INNER JOIN ordenes o ON o.product_id = p.product_id

)

SELECT
    p.product_name,
    f.cantidad,
    f.cantidadReviews,
    f.ratingPromedio
FROM stg_products p 
INNER JOIN final f ON p.product_id = f.product_id;


DROP VIEW IF EXISTS rpt_cancelacion_reembolso;
CREATE VIEW rpt_cancelacion_reembolso AS

WITH productConsigna AS (
SELECT 
    oi.order_id,
    oi.product_id,
    o.payment_method
FROM orders o
INNER JOIN order_items oi ON oi.order_id = o.order_id
WHERE status = 'Cancelado' OR status = 'Reembolsado'

),
 categoriaConsigna AS (
SELECT 
    p.payment_method,
    COUNT(p.payment_method) as ordenes_canceladas,
    stg.category_clean
FROM productConsigna p
INNER JOIN stg_products stg ON p.product_id = stg.product_id
GROUP BY payment_method, category_clean
),


 productTotales AS (
SELECT 
    oi.order_id,
    oi.product_id,
    o.status,
    o.payment_method
FROM orders o
INNER JOIN order_items oi ON oi.order_id = o.order_id

),

 categoriaTotales AS (
SELECT 
    payment_method,
    COUNT(p.payment_method) as totales_ordenes,
    stg.category_clean
FROM productTotales p
INNER JOIN stg_products stg ON p.product_id = stg.product_id
GROUP BY payment_method, category_clean
),

ultima AS (

    SELECT
        t.payment_method,
        t.category_clean,
        t.totales_ordenes,
        c.ordenes_canceladas

    FROM categoriaTotales t
    INNER JOIN categoriaConsigna c ON c.payment_method = t.payment_method AND c.category_clean = t.category_clean

)

SELECT 
    payment_method,
    category_clean,
    totales_ordenes,
    ordenes_canceladas,
    (1.0*ordenes_canceladas/totales_ordenes)*100 as pct
FROM ultima;


DROP VIEW IF EXISTS rpt_cantidad_ordenes;
CREATE VIEW rpt_cantidad_ordenes AS
SELECT COUNT(*) as total_ordenes
FROM orders
WHERE status = 'Completado';


