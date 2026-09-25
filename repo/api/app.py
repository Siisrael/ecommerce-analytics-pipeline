from flask import Flask, jsonify, request
import os
import sqlite3

app = Flask(__name__)


DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "nortestore_analytics.db")


def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # permite acceder a columnas por nombre
    return conn


@app.route("/top-productos", methods=["GET"])
def top_productos():
    """
    Devuelve el top 10 de productos por revenue.
    Reusa la misma vista SQL que ya usaste en Power BI (rpt_top_productos_revenue_margen).
    """
    conn = get_connection()
    cursor = conn.execute("""
        SELECT product_name, revenue
        FROM rpt_top_productos_revenue_margen
        ORDER BY revenue DESC
        LIMIT 10
    """)
    rows = cursor.fetchall()
    conn.close()

    resultado = [dict(row) for row in rows]
    return jsonify(resultado), 200


@app.route("/revenue-por-canal", methods=["GET"])
def revenue_por_canal():
    """
    Devuelve el revenue total por canal de adquisición.
    Si se pasa ?canal=X, filtra a un solo canal.
    Ejemplo: /revenue-por-canal?canal=Referido
    """
    canal = request.args.get("canal")  # query param, viene como texto o None si no se pasó
    conn = get_connection()

    if canal:
        # El "?" es un parámetro seguro -- evita SQL injection, nunca concatenar el string directo
        cursor = conn.execute("""
            SELECT acquisition_channel, revenueTotal
            FROM rpt_ltv_por_canal
            WHERE acquisition_channel = ?
        """, (canal,))
    else:
        cursor = conn.execute("""
            SELECT acquisition_channel, revenueTotal
            FROM rpt_ltv_por_canal
            ORDER BY revenueTotal DESC
        """)

    rows = cursor.fetchall()
    conn.close()

    if canal and not rows:
        # Si pidieron un canal específico y no existe, 404 con un mensaje claro
        return jsonify({"error": f"No se encontró el canal '{canal}'"}), 404

    resultado = [dict(row) for row in rows]
    return jsonify(resultado), 200


if __name__ == "__main__":
    app.run(debug=os.getenv("FLASK_DEBUG") == "1", port=5000)
