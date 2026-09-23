"""
Reconstruye la base analitica desde cero a partir de los CSV crudos.

    python scripts/build_db.py

Deja nortestore_analytics.db con las tablas crudas cargadas y todas las
vistas de staging y reporting creadas. La base es un artefacto generado:
no se versiona, se regenera con este script.
"""
import csv
import sqlite3
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DB = RAIZ / "nortestore_analytics.db"
CRUDOS = RAIZ / "data" / "raw"
TABLAS = ["customers", "products", "orders", "order_items",
          "marketing_campaigns", "reviews"]


def cargar_csv(con, tabla):
    """Carga un CSV crudo en su tabla. Los campos vacios entran como NULL
    para que los controles de completitud los detecten como tales."""
    ruta = CRUDOS / f"{tabla}.csv"
    with open(ruta, encoding="utf-8", newline="") as fh:
        lector = csv.reader(fh)
        columnas = next(lector)
        filas = [[None if v == "" else v for v in fila] for fila in lector]
    marcadores = ",".join("?" * len(columnas))
    con.executemany(f"INSERT INTO {tabla} VALUES ({marcadores})", filas)
    return len(filas)


def main():
    if DB.exists():
        DB.unlink()  # build limpio: evita quedar con vistas viejas dando vueltas
    con = sqlite3.connect(DB)

    con.executescript((RAIZ / "sql" / "00_schema.sql").read_text(encoding="utf-8"))
    for tabla in TABLAS:
        print(f"  {tabla:22} {cargar_csv(con, tabla):>6} filas")
    con.commit()

    for archivo in ["01_staging.sql", "02_reporting.sql"]:
        con.executescript((RAIZ / "sql" / archivo).read_text(encoding="utf-8"))
        print(f"  {archivo} aplicado")
    con.commit()

    vistas = con.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type = 'view'"
    ).fetchone()[0]
    con.close()
    print(f"\nListo: {DB.name} con {vistas} vistas.")


if __name__ == "__main__":
    main()
