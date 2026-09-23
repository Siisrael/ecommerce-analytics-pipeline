"""
Corre los controles de calidad de sql/03_quality_checks.sql y arma un reporte.

    python scripts/run_quality_checks.py

Cada control devuelve la cantidad de filas que incumplen la regla. Las reglas
con excepciones conocidas (documentadas en el README) no cortan la ejecucion;
el script sale con codigo 1 solo si falla una regla que deberia dar cero.
"""
import re
import sqlite3
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DB = RAIZ / "nortestore_analytics.db"

# Reglas que hoy dan distinto de cero por como viene la fuente. Estan
# contempladas aguas abajo (imputacion, banderas o filtros), asi que se
# reportan como advertencia en vez de como falla.
EXCEPCIONES = {
    "customers.email nulo",
    "customers.city nulo",
    "customers.email duplicado",
    "products.unit_cost nulo (imputado)",
    "reviews.rating fuera de 1-5",
    "marketing_campaigns.budget_usd nulo",
    "orders.order_date < customers.signup_date",
}


def main():
    if not DB.exists():
        sys.exit("No existe la base. Corre antes: python scripts/build_db.py")

    sql = (RAIZ / "sql" / "03_quality_checks.sql").read_text(encoding="utf-8")
    consultas = [q.strip() for q in sql.split(";") if re.search(r"\bSELECT\b", q)]

    con = sqlite3.connect(DB)
    fallas = 0
    advertencias = 0

    print(f"{'REGLA':<48}{'FILAS':>8}  ESTADO")
    print("-" * 68)
    for consulta in consultas:
        regla, filas = con.execute(consulta).fetchone()
        if filas == 0:
            estado = "OK"
        elif regla in EXCEPCIONES:
            estado = "ADVERTENCIA (contemplada)"
            advertencias += 1
        else:
            estado = "FALLA"
            fallas += 1
        print(f"{regla:<48}{filas:>8}  {estado}")
    con.close()

    print("-" * 68)
    print(f"{fallas} fallas, {advertencias} advertencias contempladas.")
    sys.exit(1 if fallas else 0)


if __name__ == "__main__":
    main()
