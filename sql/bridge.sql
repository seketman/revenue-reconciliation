-- Bridge from the finance export to the reconciled table, per day x channel.
--
-- diff = finance_usd - reconciled_usd, split into the causes found in
-- DISCREPANCIES.md. `unexplained` is what is left; it must be 0.00.
--
-- Requires the views from reconcile.sql.

-- OBSERVATIONS, NOT RULES. These describe what the finance export was found
-- to contain; they are not decisions about what revenue should be.
--   - 14 cancelled orders appear in finance; the other 11 do not, with no
--     pattern by date, channel or currency (open question Q-CANCELLED).
--   - The export stops on 2026-02-04 between 21:35 and 22:10 UTC.
--   - CAD is converted at a fixed 0.74 on every day (open question Q-FX).
CREATE OR REPLACE VIEW finance_observed_behaviour AS
SELECT
    0.74::DECIMAL(10, 6) AS finance_fx_rate,
    [
        'E76-1229', 'E76-1262', 'E76-1297', 'E76-1301', 'E76-1341', 'E76-1351', 'E76-1362',
        'E76-1365', 'E76-1370', 'E76-1388', 'E76-1469', 'E76-1548', 'E76-1569', 'E76-1574'
    ] AS cancelled_ids_in_finance,
    TIMESTAMP '2026-02-04 22:00:00' AS finance_cutoff_utc;

-- Converts at finance's rate: every cause below is valued the way finance saw it.
CREATE OR REPLACE MACRO to_usd(amount, currency) AS
    CASE currency
        WHEN 'CAD' THEN amount * (SELECT finance_fx_rate FROM finance_observed_behaviour)
        ELSE amount
    END;

-- Difference from converting CAD at the chosen rate instead of finance's.
-- Zero when reconcile.py runs with the default rate.
CREATE OR REPLACE VIEW cause_fx AS
SELECT order_date, channel,
       ROUND(SUM(to_usd(net_native, currency)), 2) - ROUND(SUM(net_usd), 2) AS amount
FROM channel_mapped
GROUP BY ALL;

-- Cancelled orders finance counted, each once.
CREATE OR REPLACE VIEW cause_cancelled AS
SELECT order_date, finance_channel(source_channel) AS channel,
       SUM(to_usd(gross - refund, currency)) AS amount
FROM excl_test, finance_observed_behaviour
WHERE status = 'cancelled' AND list_contains(cancelled_ids_in_finance, order_id)
GROUP BY ALL;

-- Extra copies of paid, non-test duplicate rows, which finance counts again.
CREATE OR REPLACE VIEW cause_duplicates AS
SELECT order_date, finance_channel(source_channel) AS channel,
       SUM(to_usd(gross - refund, currency) * (copies - 1)) AS amount
FROM (
    SELECT *, COUNT(*) AS copies FROM typed_orders
    WHERE NOT is_test AND status = 'paid'
    GROUP BY ALL HAVING COUNT(*) > 1
)
GROUP BY ALL;

-- Revenue finance is missing because its export stops early on the last day.
-- Computed as the cell finance saw minus the full cell, each rounded to the
-- cent, so half-cent CAD conversions do not leave a one-cent residual.
CREATE OR REPLACE VIEW cause_cutoff AS
SELECT order_date, channel,
       ROUND(COALESCE(SUM(to_usd(net_native, currency)) FILTER (WHERE created_utc < finance_cutoff_utc), 0), 2)
           - ROUND(SUM(to_usd(net_native, currency)), 2) AS amount
FROM channel_mapped, finance_observed_behaviour
WHERE order_date = finance_cutoff_utc::DATE
GROUP BY ALL;

CREATE OR REPLACE VIEW finance_bridge AS
SELECT
    r.date,
    r.channel,
    COALESCE(f.revenue_usd, 0)::DECIMAL(12, 2) AS finance_usd,
    r.revenue_usd AS reconciled_usd,
    (COALESCE(f.revenue_usd, 0) - r.revenue_usd)::DECIMAL(12, 2) AS diff,
    ROUND(COALESCE(c.amount, 0), 2)::DECIMAL(12, 2) AS cancelled_included_by_finance,
    ROUND(COALESCE(d.amount, 0), 2)::DECIMAL(12, 2) AS duplicates_double_counted,
    ROUND(COALESCE(k.amount, 0), 2)::DECIMAL(12, 2) AS finance_cutoff_0204,
    ROUND(COALESCE(x.amount, 0), 2)::DECIMAL(12, 2) AS fx_rate_difference,
    (COALESCE(f.revenue_usd, 0) - r.revenue_usd
        - ROUND(COALESCE(c.amount, 0), 2)
        - ROUND(COALESCE(d.amount, 0), 2)
        - ROUND(COALESCE(k.amount, 0), 2)
        - ROUND(COALESCE(x.amount, 0), 2))::DECIMAL(12, 2) AS unexplained
FROM reconciled r
LEFT JOIN typed_finance f ON f.finance_date = r.date AND f.channel = r.channel
LEFT JOIN cause_cancelled c ON c.order_date = r.date AND c.channel = r.channel
LEFT JOIN cause_duplicates d ON d.order_date = r.date AND d.channel = r.channel
LEFT JOIN cause_cutoff k ON k.order_date = r.date AND k.channel = r.channel
LEFT JOIN cause_fx x ON x.order_date = r.date AND x.channel = r.channel
ORDER BY r.date, r.channel;
