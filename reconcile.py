"""Reconcile storefront orders against the finance daily revenue export.

Usage: uv run reconcile.py [--fx-rate 0.74]
"""

import argparse
import os
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

    os.chdir(ROOT)  # SQL reads data/*.csv relative to the project root
    con = duckdb.connect()
    con.execute(f"SET VARIABLE fx_rate = {args.fx_rate}::DECIMAL(10, 6)")
    run_sql(con, "reconcile.sql")

    OUTPUT.mkdir(exist_ok=True)
    reconciled = con.sql("SELECT * FROM reconciled").df()
    assert len(reconciled) == EXPECTED_CELLS, f"expected {EXPECTED_CELLS} cells, got {len(reconciled)}"
    reconciled.to_csv(OUTPUT / "reconciled_revenue.csv", index=False, float_format="%.2f")

    run_sql(con, "bridge.sql")
    bridge = con.sql("SELECT * FROM finance_bridge").df()
    finance_total = con.sql("SELECT SUM(revenue_usd) FROM typed_finance").fetchone()[0]
    assert abs(bridge["finance_usd"].sum() - float(finance_total)) < 0.01, "finance rows fell outside the calendar grid"
    unexplained = bridge[bridge["unexplained"].abs() >= 0.01]
    assert unexplained.empty, f"unexplained differences:\n{unexplained}"
    bridge.to_csv(OUTPUT / "finance_bridge.csv", index=False, float_format="%.2f")

    print(f"FX rate CAD->USD: {args.fx_rate}")
    print(f"Finance export (USD):             {bridge['finance_usd'].sum():>10,.2f}")
    print(f"  cancelled included by finance:  {-bridge['cancelled_included_by_finance'].sum() + 0.0:>10,.2f}")
    print(f"  duplicates double counted:      {-bridge['duplicates_double_counted'].sum() + 0.0:>10,.2f}")
    print(f"  finance cutoff on 2026-02-04:   {-bridge['finance_cutoff_0204'].sum() + 0.0:>10,.2f}")
    print(f"  FX rate difference vs 0.74:     {-bridge['fx_rate_difference'].sum() + 0.0:>10,.2f}")
    print(f"  unexplained:                    {-bridge['unexplained'].sum() + 0.0:>10,.2f}")
    print(f"Reconciled revenue (USD):         {reconciled['revenue_usd'].sum():>10,.2f}")


if __name__ == "__main__":
    main()
