-- Reconciled daily revenue by channel.
--
-- Revenue definition: gross - refund of paid, non-test orders, dated by the
-- order's UTC calendar day, converted to USD at a fixed CAD rate.
-- Each view applies one decision and cites the item it addresses in
-- DISCREPANCIES.md (R = resolved, O = open question).
--
-- Expects the variable `fx_rate` to be set by the caller (default 0.74).

-- Source rows, typed. Duplicates are still present here.
CREATE OR REPLACE VIEW typed_orders AS
SELECT
    order_id,
    created_at::TIMESTAMPTZ AT TIME ZONE 'UTC' AS created_utc,
    (created_at::TIMESTAMPTZ AT TIME ZONE 'UTC')::DATE AS order_date,
    channel AS source_channel,
    gross::DECIMAL(12, 2) AS gross,
    refund::DECIMAL(12, 2) AS refund,
    currency,
    status,
    is_test_order::BOOLEAN AS is_test
FROM read_csv('data/orders.csv', all_varchar = true);

CREATE OR REPLACE VIEW typed_finance AS
SELECT
    date::DATE AS finance_date,
    channel,
    revenue_usd::DECIMAL(12, 2) AS revenue_usd
FROM read_csv('data/finance_export.csv', all_varchar = true);

-- Exact duplicate rows are counted once (R2).
CREATE OR REPLACE VIEW deduplicated AS
SELECT DISTINCT * FROM typed_orders;

-- Test orders are not revenue (R5).
CREATE OR REPLACE VIEW excl_test AS
SELECT * FROM deduplicated WHERE NOT is_test;

-- Cancelled orders are not revenue (O2, Q-CANCELLED).
CREATE OR REPLACE VIEW excl_cancelled AS
SELECT * FROM excl_test WHERE status = 'paid';

-- Refunds are netted on the order date; no refund date exists (O5, Q-REFUND-DATE).
CREATE OR REPLACE VIEW net_of_refunds AS
SELECT *, gross - refund AS net_native FROM excl_cancelled;

-- CAD converted at a fixed rate, as finance does (O1, Q-FX).
CREATE OR REPLACE VIEW usd_converted AS
SELECT
    *,
    CASE currency
        WHEN 'USD' THEN net_native
        WHEN 'CAD' THEN net_native * getvariable('fx_rate')
        ELSE error('Unknown currency: ' || currency)
    END AS net_usd
FROM net_of_refunds;

-- Storefront channel tags mapped to finance channels (R1;
-- open questions O3 Q-TIKTOK and O4 Q-FB-ORGANIC). An unmapped tag fails the run.
CREATE OR REPLACE MACRO finance_channel(source_channel) AS
    CASE source_channel
        WHEN 'facebook' THEN 'Paid Social'
        WHEN 'Facebook Ads' THEN 'Paid Social'
        WHEN 'fb' THEN 'Paid Social'
        WHEN 'google' THEN 'Paid Search'
        WHEN '(direct)' THEN 'Direct'
        WHEN 'email' THEN 'Email'
        WHEN 'affiliate' THEN 'Other'
        WHEN 'tiktok' THEN 'Other'
        ELSE error('Unmapped channel: ' || source_channel)
    END;

CREATE OR REPLACE VIEW channel_mapped AS
SELECT *, finance_channel(source_channel) AS channel FROM usd_converted;

-- Full calendar x channel grid, so days without orders show 0
-- (R4).
CREATE OR REPLACE VIEW calendar_grid AS
SELECT d::DATE AS order_date, channel
FROM generate_series(DATE '2026-01-06', DATE '2026-02-04', INTERVAL 1 DAY) AS t(d)
CROSS JOIN (VALUES ('Direct'), ('Email'), ('Other'), ('Paid Search'), ('Paid Social')) AS c(channel);

-- Cells touched by a non-test cancelled order, for the Q-CANCELLED flag.
CREATE OR REPLACE VIEW cancelled_cells AS
SELECT DISTINCT order_date, finance_channel(source_channel) AS channel
FROM excl_test
WHERE status = 'cancelled';

CREATE OR REPLACE VIEW daily_aggregation AS
SELECT
    order_date,
    channel,
    ROUND(SUM(net_usd), 2)::DECIMAL(12, 2) AS revenue_usd,
    SUM(net_native) FILTER (WHERE currency = 'CAD') AS cad_net_native,
    COUNT(*) AS orders,
    BOOL_OR(source_channel = 'tiktok') AS has_tiktok,
    BOOL_OR(source_channel = 'facebook') AS has_facebook,
    BOOL_OR(refund > 0) AS has_refund
FROM channel_mapped
GROUP BY ALL;

CREATE OR REPLACE VIEW reconciled AS
SELECT
    g.order_date AS date,
    g.channel,
    COALESCE(a.revenue_usd, 0)::DECIMAL(12, 2) AS revenue_usd,
    COALESCE(a.cad_net_native, 0)::DECIMAL(12, 2) AS cad_net_native,
    COALESCE(a.orders, 0) AS orders,
    array_to_string(list_filter([
        CASE WHEN COALESCE(a.cad_net_native, 0) > 0 THEN 'Q-FX' END,
        CASE WHEN cc.order_date IS NOT NULL THEN 'Q-CANCELLED' END,
        CASE WHEN a.has_tiktok THEN 'Q-TIKTOK' END,
        CASE WHEN a.has_facebook THEN 'Q-FB-ORGANIC' END,
        CASE WHEN a.has_refund THEN 'Q-REFUND-DATE' END
    ], x -> x IS NOT NULL), ';') AS open_questions
FROM calendar_grid g
LEFT JOIN daily_aggregation a USING (order_date, channel)
LEFT JOIN cancelled_cells cc USING (order_date, channel)
ORDER BY date, channel;
