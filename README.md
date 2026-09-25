# Pipeline analítico de e-commerce

Proyecto de análisis sobre las ventas de una tienda online ficticia
(NorteStore). Parte de seis archivos de datos crudos y termina en un dashboard
con los indicadores del negocio: cuánto se vende, qué productos dejan más
margen, qué canales traen mejores clientes y qué tan bien funcionan las
campañas de marketing.

La idea fue hacer el recorrido completo: limpiar los datos, armar las consultas
que calculan cada métrica, y mostrar el resultado en un dashboard y en una API.

**Stack:** SQLite · SQL · Python · Flask · Power BI

---

## El dashboard

<!-- Pegá acá 2 o 3 capturas cuando las tengas:
     ![Vista general](dashboard/capturas/general.png)     -->

El archivo está en `dashboard/nortestore_analytics.pbix`. Se conecta directo a
las vistas de la base, así que todos los cálculos viven en SQL y Power BI se
ocupa solamente de mostrarlos.

---

## Los datos

Seis tablas: clientes, productos, órdenes, detalle de cada orden, campañas de
marketing y reseñas. En total unas 3.000 órdenes de 610 clientes.

Como vienen, los datos tienen los problemas típicos de una fuente real: el
mismo país escrito de varias formas (`arg.`, `USA`, `Brazil`), productos sin
costo cargado, reseñas con puntajes fuera de la escala 1 a 5 y algunos emails
repetidos.

---

## Cómo está armado

**1. Limpieza** (`sql/staging.sql`)

Tres vistas dejan los datos parejos antes de calcular nada: unifican los
nombres de países, normalizan las categorías de producto, completan los costos
que faltan y marcan las reseñas con puntaje inválido.

**2. Métricas** (`sql/reporting.sql`)

Diez vistas, una por indicador:

| Vista | Qué responde |
|---|---|
| `rpt_revenue_mensual_categoria` | Cómo evolucionan las ventas mes a mes por categoría |
| `rpt_top_productos_revenue_margen` | Qué productos venden más y cuáles dejan más margen |
| `rpt_aov_por_pais` | Cuánto gasta en promedio un cliente por compra, según el país |
| `rpt_ltv_por_canal` | Qué canal de captación trae los clientes más valiosos |
| `rpt_roi_campanias` | Cuánto devolvió cada campaña frente a lo que costó |
| `rpt_recompra` | Qué porcentaje de clientes vuelve a comprar |
| `rpt_estacionalidad` | En qué meses y días de la semana se vende más |
| `rpt_rating_vs_ventas` | Si los productos mejor puntuados venden más |
| `rpt_cancelacion_reembolso` | Qué medios de pago y categorías tienen más cancelaciones |
| `rpt_cantidad_ordenes` | Total de órdenes completadas |

**3. Salidas**

El dashboard de Power BI y una API en Flask (`api/app.py`), las dos leyendo las
mismas vistas.

---

## Decisiones que tomé

**Solo cuento las órdenes completadas.** Todas las métricas filtran por ese
estado: una orden cancelada o pendiente todavía no es plata que entró.

**Los costos que faltan los estimo, no los borro.** Seis productos no tenían
costo cargado. Descartarlos hubiera dejado huecos en el análisis de margen, así
que los estimo como el 65% del precio de venta y dejo una marca
(`costo_estimado`) en cada fila para que se sepa cuáles son estimados.

**Las reseñas inválidas quedan marcadas, no eliminadas.** Mismo criterio: el
dato se conserva con una bandera que avisa que el puntaje está fuera de escala,
y los análisis de puntaje lo excluyen.

**Las campañas sin presupuesto muestran ROI vacío.** Dos campañas no tienen
cargado el presupuesto. Preferí que el ROI quede en blanco antes que inventar
un número que después nadie pueda explicar.

---

## Cómo correrlo

```bash
pip install -r requirements.txt
python api/app.py
```

La base ya viene armada (`nortestore_analytics.db`), así que se puede abrir y
consultar directamente con DB Browser for SQLite.

Para rehacerla desde cero: crear una base nueva, correr `sql/schema.sql`,
importar los CSV de `data/raw/` y después correr `sql/staging.sql` y
`sql/reporting.sql`, en ese orden.

---

## API

| Endpoint | Devuelve |
|---|---|
| `GET /top-productos` | Los 10 productos que más facturan |
| `GET /revenue-por-canal` | Ventas totales por canal de captación |
| `GET /revenue-por-canal?canal=Referido` | Lo mismo, filtrado a un canal |

---

## Carga incremental

`scripts/incremental_load.py` guarda la fecha de la última orden procesada y en
la corrida siguiente lee solo las nuevas, en lugar de volver a leer toda la
tabla.
