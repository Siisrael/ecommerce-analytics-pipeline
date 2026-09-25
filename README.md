# Pipeline analítico de e-commerce

<!-- ------------------------------------------------------------------
ESQUELETO PARA COMPLETAR. Cada bloque en comentarios dice qué escribir.
Borrá los comentarios a medida que los vas llenando.
------------------------------------------------------------------- -->

<!-- 2 o 3 renglones: qué es el proyecto y qué resuelve.
     Ej: de dónde salen los datos, a dónde llegan (dashboard), y qué
     preguntas de negocio responde. -->


**Stack:** SQLite · SQL · Python · Flask · Power BI


## Estructura

```
data/raw/     CSV de origen (6 tablas)
sql/
  schema.sql     esquema de las tablas crudas
  staging.sql    limpieza y normalización
  reporting.sql  vistas de negocio con CTEs
api/          API en Flask sobre las vistas
scripts/      carga incremental
notebooks/    análisis exploratorio
dashboard/    dashboard en Power BI + capturas
```


## El dashboard

<!-- Pegá acá 2 o 3 capturas:
     ![Ventas](dashboard/capturas/ventas.png)
     Es lo único que se ve sin abrir el .pbix, así que va arriba de todo. -->


## Modelo de datos

<!-- Las 6 tablas y cómo se relacionan.
     Después, las 3 vistas stg_*: qué limpia cada una.
       - stg_customers: unificación de países, numeración de emails repetidos
       - stg_products: normalización de categorías, imputación del costo
       - stg_reviews: marcado de ratings fuera de escala -->


## Vistas de reporting

<!-- Las 10 vistas rpt_*, una línea cada una: qué métrica devuelve. -->


## Decisiones

<!-- LA SECCIÓN MÁS IMPORTANTE: es la que te van a preguntar.
     Explicá el porqué, no el qué:
       - por qué imputás el costo faltante como unit_price * 0.65
       - por qué dejás la bandera costo_estimado en vez de borrar esas filas
       - por qué todas las vistas filtran status = 'Completado'
       - por qué marcás los ratings inválidos en vez de excluirlos en el staging
       - qué hacés con las 2 campañas sin presupuesto en rpt_roi_campanias -->


## Cómo correrlo

<!-- Los pasos reales:
       pip install -r requirements.txt
       python api/app.py
     Y si alguien quiere rehacer la base desde cero: qué orden de scripts
     correr en DB Browser (schema.sql → cargar los CSV → staging.sql →
     reporting.sql). -->


## API

<!-- Los 2 endpoints: qué devuelve cada uno y un ejemplo de llamada. -->
