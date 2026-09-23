import sqlite3

DB_PATH = "nortestore_analytics_1.db"
PROCESO = "sync_orders"  # nombre de este proceso 


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def asegurar_tabla_control(conn):
    """
    Crea la tabla de control si no existe todavía.
    Acá vive la 'marca de agua' (watermark): hasta qué fecha ya procesamos,
    para no tener que releer todo orders cada vez que corremos el proceso.
    """
    conn.execute("""
        CREATE TABLE IF NOT EXISTS etl_control (
            proceso TEXT PRIMARY KEY,
            ultima_fecha_procesada TEXT
        )
    """)
    conn.commit()


def obtener_ultima_fecha(conn, proceso):
    cursor = conn.execute(
        "SELECT ultima_fecha_procesada FROM etl_control WHERE proceso = ?",
        (proceso,)
    )
    row = cursor.fetchone()
    if row is None:
        # Primera vez que corre este proceso -- no hay marca todavía,
        # así que traemos todo el historial disponible.
        return "1900-01-01"
    return row["ultima_fecha_procesada"]


def actualizar_ultima_fecha(conn, proceso, nueva_fecha):
    # ON CONFLICT ... DO UPDATE es el UPSERT de SQLite:
    # si la fila ya existe (mismo 'proceso'), la actualiza en vez de fallar por clave duplicada.
    conn.execute("""
        INSERT INTO etl_control (proceso, ultima_fecha_procesada)
        VALUES (?, ?)
        ON CONFLICT(proceso) DO UPDATE SET ultima_fecha_procesada = excluded.ultima_fecha_procesada
    """, (proceso, nueva_fecha))
    conn.commit()


def main():
    conn = get_connection()
    asegurar_tabla_control(conn)

    ultima_fecha = obtener_ultima_fecha(conn, PROCESO)
    print(f"Última fecha procesada registrada: {ultima_fecha}")

    cursor = conn.execute("""
        SELECT order_id, customer_id, order_date, status
        FROM orders
        WHERE order_date > ?
        ORDER BY order_date
    """, (ultima_fecha,))
    ordenes_nuevas = cursor.fetchall()

    print(f"Pedidos nuevos encontrados: {len(ordenes_nuevas)}")
    for o in ordenes_nuevas[:5]:  # solo una muestra, no todo
        print(dict(o))

    if ordenes_nuevas:
        # Guardamos como nueva marca la fecha más reciente que vimos 
        nueva_fecha_maxima = max(o["order_date"] for o in ordenes_nuevas)
        actualizar_ultima_fecha(conn, PROCESO, nueva_fecha_maxima)
        print(f"Fecha de control actualizada a: {nueva_fecha_maxima}")
    else:
        print("No hay pedidos nuevos -- no se actualiza la fecha de control.")

    conn.close()


if __name__ == "__main__":
    main()
