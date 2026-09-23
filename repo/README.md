# Pipeline analítico de e-commerce

Modelo de datos y pipeline de reporting sobre las ventas de un e-commerce
ficticio (NorteStore), desde los datos crudos hasta un dashboard ejecutivo en
Power BI.

El foco del proyecto no es el volumen de datos sino el recorrido completo:
limpiar y normalizar la fuente, construir una capa de staging, derivar vistas
de negocio con SQL, validar la calidad de los datos con controles explícitos y
exponer el resultado tanto en un dashboard como en una API.

**Stack:** SQLite · SQL (CTEs, window functions) · Python · Flask · Power BI

---

## Cómo correrlo

```bash
pip install -r requirements.txt

python scripts/build_db.py            # reconstruye la base desde data/raw/
python scripts/run_quality_checks.py  # corre los 17 controles de calidad
python api/app.py                     # levanta la API en localhost:5000
```

La base (`nortestore_analytics.db`) es un artefacto generado y no se versiona:
se reconstruye siempre con `build_db.py`.

---

## Estructura

```
data/raw/        CSV de origen (6 tablas)
sql/
  00_schema.sql          esquema de las tablas crudas
  01_staging.sql         capa de staging: limpieza y normalización
  02_reporting.sql       vistas de negocio con CTEs
  03_quality_checks.sql  17 controles de calidad de datos
scripts/
  build_db.py            reconstruye la base de cero
  run_quality_checks.py  corre los controles y arma el reporte
  incremental_load.py    carga incremental por watermark
api/app.py       API en Flask sobre las vistas de reporting
notebooks/       análisis exploratorio y gráficos
dashboard/       dashboard en Power BI (.pbix)
```

---

## Modelo de datos

Seis tablas de origen: `customers`, `products`, `orders`, `order_items`,
`marketing_campaigns` y `reviews`. `orders` se relaciona con `customers` y con
`marketing_campaigns`; `order_items` es el detalle de cada orden y apunta a
`products`.

### Capa de staging

Las vistas `stg_*` dejan los datos consistentes antes de cualquier cálculo de
negocio:

| Vista | Qué resuelve |
|---|---|
| `stg_customers` | Unifica variantes de país (`arg.`, `USA`, `Brazil`, `México`) en un valor único y numera las apariciones de cada email para poder detectar duplicados. |
| `stg_products` | Normaliza categorías (`electrónica` → `electronica`) e imputa el costo faltante como 65% del precio, marcando esas filas con la bandera `costo_estimado`. |
| `stg_reviews` | Marca con `rating_valido` las reseñas cuyo puntaje cae fuera de la escala 1–5. |

El criterio es no descartar filas en silencio: cuando un dato se imputa o se
considera inválido, queda una bandera que lo dice.

### Capa de reporting

Diez vistas construidas con CTEs, todas sobre órdenes en estado `Completado`:

- `rpt_revenue_mensual_categoria` — evolución del revenue por mes y categoría
- `rpt_top_productos_revenue_margen` — ranking de productos por revenue y margen
- `rpt_aov_por_pais` — ticket promedio (AOV) por país
- `rpt_ltv_por_canal` — clientes, revenue y LTV por canal de adquisición
- `rpt_roi_campanias` — ROI de cada campaña de marketing contra su presupuesto
- `rpt_recompra` — tasa de clientes que compraron más de una vez
- `rpt_estacionalidad` — revenue por mes y día de la semana
- `rpt_rating_vs_ventas` — relación entre puntaje promedio y unidades vendidas
- `rpt_cancelacion_reembolso` — tasa de cancelación por medio de pago y categoría
- `rpt_cantidad_ordenes` — total de órdenes completadas

---

## Calidad de datos

`sql/03_quality_checks.sql` define 17 reglas de completitud, unicidad, rango,
dominio, integridad referencial y consistencia temporal. Cada una devuelve la
cantidad de filas que la incumplen, y el resultado esperado es cero.

`run_quality_checks.py` separa las fallas reales de las excepciones ya
contempladas aguas abajo, y devuelve código de salida 1 solo si falla una regla
que debería dar cero.

Estado actual sobre los datos de origen:

| Regla | Filas | Cómo se trata |
|---|---:|---|
| Clientes sin email | 21 | Se conservan; el conteo de duplicados usa el `customer_id` como respaldo. |
| Clientes sin ciudad | 17 | Se conservan: no afectan ningún cálculo, el análisis geográfico usa el país. |
| Emails duplicados | 10 | Se detectan con `ROW_NUMBER()` en `stg_customers`. |
| Productos sin costo | 6 | Se imputan al 65% del precio y se marcan con `costo_estimado`. |
| Reseñas fuera de la escala 1–5 | 38 | Se marcan con `rating_valido` y se excluyen del análisis de puntajes. |
| Campañas sin presupuesto | 2 | Su ROI queda nulo; se reporta en vez de forzar un valor inventado. |
| Órdenes previas al alta del cliente | 1514 | Artefacto del generador de datos sintéticos, documentado como limitación. |

Todo el resto de los controles da cero.

Un caso que vale la pena señalar: hay 381 líneas de pedido con cantidad
negativa. No son un error de carga sino la forma en que el modelo representa
las devoluciones, y aparecen únicamente en órdenes `Reembolsado`. Por eso la
regla no prohíbe las cantidades negativas: verifica que no existan fuera de ese
estado. Como todas las vistas de reporting filtran por `Completado`, el revenue
no se ve afectado.

---

## Carga incremental

`scripts/incremental_load.py` implementa una carga incremental por *watermark*:
guarda en la tabla `etl_control` la fecha máxima ya procesada y en la corrida
siguiente lee solo las órdenes posteriores, en vez de releer la tabla completa.

---

## API

Expone las vistas de reporting por HTTP, reutilizando el mismo SQL que consume
el dashboard:

| Endpoint | Devuelve |
|---|---|
| `GET /top-productos` | Top 10 de productos por revenue |
| `GET /revenue-por-canal` | Revenue total por canal de adquisición |
| `GET /revenue-por-canal?canal=Referido` | Filtrado a un solo canal |

Las consultas usan parámetros ligados (`?`) en lugar de concatenar strings, para
evitar inyección SQL.

---

## Dashboard

`dashboard/nortestore_analytics.pbix` se conecta directamente a las vistas
`rpt_*`: toda la lógica de negocio vive en SQL y Power BI queda solo como capa
de visualización.
