# Storefront vs finance revenue reconciliation

Reconciles the storefront order export (`data/orders.csv`) with the finance daily revenue export (`data/finance_export.csv`) for 2026-01-06 to 2026-02-04. It produces one reconciled daily revenue figure per channel.

The main deliverable is [`DISCREPANCIES.md`](DISCREPANCIES.md). It explains every difference between the two files, which ones are resolved, and which questions are still open for the client.

## Run

```sh
uv run reconcile.py                 # CAD converted at 0.74, the rate finance uses
uv run reconcile.py --fx-rate 0.72  # re-price CAD at another rate
```

Requires [uv](https://docs.astral.sh/uv/). DuckDB and pandas are installed automatically.

## Outputs

- `output/reconciled_revenue.csv`: one row per day and channel (150 rows).
  - Revenue is gross minus refunds for paid, non-test orders, counted once, on the order's UTC date.
  - `cad_net_native` shows the CAD amount before conversion, so the figure can be re-priced.
  - `open_questions` lists the open client questions that affect each cell.
- `output/finance_bridge.csv`: for each cell, the difference from finance's figure split into its causes. The run fails if any difference is left unexplained.

## Code

- `sql/reconcile.sql`: one view per decision, in the order they are applied.
- `sql/bridge.sql`: what finance was observed to do, and the bridge from its figures to the reconciled table.
- `reconcile.py`: runs both files, writes the CSVs and checks the results.
