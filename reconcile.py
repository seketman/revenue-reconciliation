"""Reconcile storefront orders against the finance daily revenue export.

Usage: uv run reconcile.py [--fx-rate 0.74]
"""

import argparse
from pathlib import Path

import duckdb

ROOT = Path(__file__).parent
OUTPUT = ROOT / "output"
EXPECTED_CELLS = 30 * 5


def run_sql(con: duckdb.DuckDBPyConnection, name: str) -> None:
    con.execute((ROOT / "sql" / name).read_text())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fx-rate", type=float, default=0.74, help="CAD to USD rate")
    args = parser.parse_args()

    con = duckdb.connect()
    con.execute(f"SET VARIABLE fx_rate = {args.fx_rate}::DECIMAL(10, 6)")
    run_sql(con, "reconcile.sql")

    OUTPUT.mkdir(exist_ok=True)
    reconciled = con.sql("SELECT * FROM reconciled").df()
    assert len(reconciled) == EXPECTED_CELLS, f"expected {EXPECTED_CELLS} cells, got {len(reconciled)}"
    reconciled.to_csv(OUTPUT / "reconciled_revenue.csv", index=False, float_format="%.2f")

    print(f"FX rate CAD->USD: {args.fx_rate}")
    print(f"Reconciled revenue (USD): {reconciled['revenue_usd'].sum():,.2f}")


if __name__ == "__main__":
    main()
