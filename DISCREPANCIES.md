# Revenue reconciliation: storefront vs finance

Period: 2026-01-06 to 2026-02-04 (30 days). Sources: `orders.csv` (storefront, one row per order) and `finance_export.csv` (finance, daily revenue by channel).

## Summary

**Reconciled net order revenue: USD 76,393.86.** Finance reported USD 77,303.41. Every cent of the USD 909.55 gap is traced to three problems in how the finance figure was built:

| | USD |
|---|---:|
| Finance export | 77,303.41 |
| Cancelled orders that finance counted | -1,389.34 |
| Duplicate orders that finance counted twice | -231.96 |
| Orders missing from finance on the last day (extract cut off at about 22:00 UTC) | +711.75 |
| **Reconciled** | **76,393.86** |

**Definition used: net order revenue, by order date.** Order gross minus refunds, in USD, dated on the order's UTC calendar day. Test orders and cancelled orders are excluded, and each order is counted once. CAD orders are converted at 0.74, the rate finance uses. This is the same basis finance reports on. It is not necessarily recognized revenue for the accounts, which usually follows shipment or delivery rather than the order date (see O8).

| Channel | Finance | Reconciled | Difference |
|---|---:|---:|---:|
| Paid Social | 30,645.21 | 29,843.62 | -801.59 |
| Other | 18,488.78 | 18,229.74 | -259.04 |
| Email | 9,899.05 | 10,084.95 | +185.90 |
| Direct | 8,934.57 | 9,333.09 | +398.52 |
| Paid Search | 9,335.80 | 8,902.46 | -433.34 |
| **Total** | **77,303.41** | **76,393.86** | **-909.55** |

**What I stand behind:** the reconciled daily figures under the definition above, and the explanation of the gap to finance. No part of the gap is unexplained.

**What I cannot give you yet:** nine questions that only the business can answer. Until they are answered, the total above is a figure on stated assumptions, not a final one:

| Open question | Can it move the total? | By how much |
|---|---|---|
| O6. Does `gross` include tax, shipping or discounts? | Yes | Down by roughly the tax rate, if tax is included |
| O8. Is revenue recognized at order, shipment or delivery? | Yes, near the period edges | Unknown |
| O2. Were any cancelled orders charged? | Yes | Up to +1,389.34 for the 14 finance counts, up to +2,905.60 if all 25 were charged |
| O1. Which CAD rate? | Yes | 142.65 for each 0.01 of rate |
| O5. Refunds dated on the order or on the refund? | Yes, for refunds after 02-04 | Up to +2,703.13 |
| O9. Should test order E76-1588, which was partly refunded, count? | Yes | Up to +65.92 |
| O7. What does `created_at` record? | Only at the period edges | Small |
| O3. TikTok in "Other" or "Paid Social"? | No, it moves 10,414.39 between channels | 0 |
| O4. Is the `facebook` label organic traffic? | No, it may move 11,686.46 out of Paid Social | 0 |

**What you need to do:**
1. Send the questions in the last section. Each one names who in the business can answer it.
2. If finance's figure for 2026-02-04 has already been reported, re-pull it. It is missing USD 711.75 (R3).

Deliverables:
- `output/reconciled_revenue.csv`: daily revenue by channel.
- `output/finance_bridge.csv`: the same days and channels, with finance's figure and the cause of every difference.

The `open_questions` column in the reconciled table lists the questions that affect each row, using the codes in the question headings (for example `Q-FX`). Q-CANCELLED marks every row that had a cancelled order. Q-GROSS, Q-CREATED-AT and Q-RECOGNITION affect every row, so they are not listed per row. Each daily figure is rounded to the cent, and totals are sums of those rounded figures, as in finance's export. This differs by at most USD 0.02 from rounding the exact total once.

## How the two sources relate

Finance's figures can be reproduced from the storefront extract cell by cell. The rule:

- gross minus refund, on the order's UTC date
- test orders and cancelled orders excluded
- CAD converted at a flat 0.74
- channel labels mapped to five buckets (see R1)
- duplicate rows counted as many times as they appear

With this rule, 137 of the 150 day-by-channel cells match to the cent. The remaining 13 are each explained by specific orders (R2, R3 and O2). The finance process is therefore consistent with the storefront, and the differences come from a few identifiable exceptions rather than from a different method.

## Resolved discrepancies

These are settled from the data alone, or with a definition I state and apply.

### R1. Channel names differ between the sources

- **What:** the storefront uses 8 channel labels and finance uses 5 buckets.
- **How I know:** the mapping below reproduces finance's figures exactly in every cell where no other issue applies.
  - `facebook`, `Facebook Ads`, `fb` go to Paid Social.
  - `google` goes to Paid Search.
  - `(direct)` goes to Direct.
  - `email` goes to Email.
  - `affiliate` and `tiktok` go to Other.
- **What I did:** applied the same mapping. A label that is not on this list stops the script instead of falling into Other silently.
- **Still open:** whether TikTok and the `facebook` label belong where finance puts them (O3, O4). That changes channel totals but not the overall total.

### R2. Duplicate order rows, counted twice by finance

- **What:** 5 orders appear twice, with every field identical: E76-1097, E76-1184, E76-1212, E76-1365 and E76-1658. Four of them are paid orders.
- **How I know:** finance's Direct figure for 01-13 and Paid Search figure for 02-02 only match if the duplicate is counted twice.
- **What I did:** counted each order once, because an order ID identifies one order. This removes USD 231.96 that finance double counted. The fifth duplicate, E76-1365, is also a cancelled order. Finance counts it once, not twice, so it appears in O2 (cancelled orders), not in this amount.

### R3. Finance's last day is incomplete

- **What:** finance's figures for 2026-02-04 are missing every order placed after about 22:00 UTC.
- **How I know:** the last order finance includes is at 21:35 UTC and the first one it misses is at 22:10 UTC. The missing orders are E76-1735, E76-1721, E76-1707 (Direct), E76-1712 (Email) and E76-1708 (Paid Social). On every earlier day, orders up to 23:59 UTC are included.
- **What I did:** used the full day from the storefront, adding USD 711.75. The finance extract was most likely taken before the day closed. The day's figure should be re-pulled if it was reported. The storefront extract may also be incomplete for this day, if orders were placed after it was pulled (see R7).

### R4. Five day-by-channel rows missing from finance

- **What:** finance has 145 rows, not 150. Missing: 01-07 Direct, 01-09 Paid Search, 01-17 Direct, 01-21 Email and 01-25 Direct.
- **How I know:** the storefront has no orders on those days and channels.
- **What I did:** the reconciled table shows these cells as 0.00, so every day has all five channels.

### R5. Test orders (checked, not a discrepancy)

- **What:** there are 12 orders flagged `is_test_order`.
- **How I know:** finance's figures match only when these orders are excluded.
- **What I did:** excluded them.
- **Limitation:** test orders that were never flagged cannot be detected from the data. I found no suspicious amounts, such as very small or repeated values.
- **Exception:** one test order, E76-1588, carries a partial refund, which suggests real money moved. That order is an open question (O9).

### R6. Time zone (checked, not a discrepancy)

- **What:** storefront timestamps are in UTC and finance dates have no stated time zone.
- **How I know:** UTC calendar days reproduce finance exactly. All orders fall between 14:00 and 23:59 UTC, which is 09:00 to 18:59 US Eastern time. Any US time zone would therefore give the same days.
- **What I did:** used UTC days.

### R7. Completeness of the storefront extract (partly checked)

- **What:** order IDs run from E76-1000 to E76-1735 with no gaps, so no order is missing from inside that range.
- **What I cannot verify:** the edges of the period. IDs are not issued in time order (see O7). The last order of 2026-02-04, at 23:44 UTC, is E76-1707, not E76-1735. So an order with an ID above E76-1735, or below E76-1000, could still be dated inside the period and be missing from both files.

## Open questions for the client

Each of these needs an answer that is not in the data. The reconciled table follows finance's current practice for each one, or excludes the item when that is the safer default, and says so. None of these has been settled by guessing. Each question names who in the business is likely to know the answer.

### O1 (Q-FX). Currency rate for CAD orders

- **What:** 123 paid orders (CAD 14,264.62 net) are in Canadian dollars. Finance converts them all at a flat 0.74. Neither file contains an exchange rate.
- **What I did:** used 0.74 so the figures stay comparable with finance. The `cad_net_native` column keeps the CAD amount, so the table can be recomputed at another rate (`uv run reconcile.py --fx-rate <rate>`).
- **Impact:** each 0.01 change in the rate moves revenue by USD 142.65.
- **Who can answer:** CFO.
- **Question:**
  > Finance converts all CAD orders at a flat 0.74. Keep 0.74, or use the rate the payment processor actually settled at?

### O2 (Q-CANCELLED). Cancelled orders that finance counted as revenue

- **What:** 25 orders are cancelled (not counting test orders). Finance counts 14 of them (USD 1,389.34) and leaves out the other 11 (USD 1,516.26). I found no pattern by date, channel or currency.
- **How I know:** each of the 10 cells where finance is higher than the storefront matches, to the cent, the value of one or two cancelled orders in that cell.
- **What I did:** excluded all cancelled orders. The storefront shows no refund on any of them, so either they were never charged, or they were charged and then cancelled without the money being returned.
- **Who can answer:** whoever can look up payments in the payment processor.
- **Question:**
  > Finance's report counts these 14 cancelled orders as revenue: E76-1229, 1262, 1297, 1301, 1341, 1351, 1362, 1365, 1370, 1388, 1469, 1548, 1569, 1574 (USD 1,389.34 in total). Were any of them charged and not refunded?

  > Same question for the other 11 cancelled orders (USD 1,516.26), which finance leaves out: were any of them charged and not refunded?

### O3 (Q-TIKTOK). TikTok reported under "Other"

- **What:** finance puts TikTok orders (USD 10,414.39) in Other together with affiliate, not in Paid Social.
- **What I did:** kept finance's mapping, so the channel totals stay comparable. Affected cells carry `Q-TIKTOK`.
- **Who can answer:** CFO.
- **Question:**
  > TikTok orders (USD 10,414.39 this period) are currently reported under "Other", not "Paid Social". Is that intentional?

### O4 (Q-FB-ORGANIC). Three Facebook labels, possibly paid and organic mixed

- **What:** the storefront uses `facebook`, `Facebook Ads` and `fb` at the same time, every day of the period, so this is not a rename. Finance puts all three in Paid Social. If `facebook` is unpaid (organic) traffic, Paid Social is overstated by USD 11,686.46.
- **What I did:** kept all three in Paid Social, as finance does. Affected cells carry `Q-FB-ORGANIC`.
- **Who can answer:** marketing.
- **Question:**
  > The storefront tags Facebook orders three ways: "facebook", "Facebook Ads" and "fb". Are all three paid ads, or is any of them unpaid (organic) traffic?

### O5 (Q-REFUND-DATE). Refunds are dated on the order, not on the refund

- **What:** 37 paid orders carry refunds (USD 2,703.13). Both sources subtract each refund on the day the order was placed. Neither file has a refund date. As a result, a day that has already been reported goes down whenever a later refund arrives.
- **What I did:** followed the current practice. Affected cells carry `Q-REFUND-DATE`.
- **Who can answer:** CFO for the policy, and whoever owns the storefront export for the refund date.
- **Questions:**
  > Should a refund reduce revenue on the day of the original order (current practice, which changes past days), or on the day of the refund?

  > Can the order export include the date each refund was issued?

### O6 (Q-GROSS). What the `gross` amount contains

- **What:** neither file says whether `gross` includes sales tax, shipping, discounts or gift-card payments. This affects every figure in both sources. If sales tax is included, revenue is overstated by roughly the tax rate on every taxed order.
- **What I did:** used `gross` as it comes.
- **Who can answer:** whoever owns the storefront export for the first question, and the CFO for the second.
- **Questions:**
  > Does "gross" in the order export include sales tax, shipping, discounts, or amounts paid with gift cards or store credit?

  > Should shipping charged to customers count as revenue?

### O7 (Q-CREATED-AT). What `created_at` represents

- **What:** order IDs are not in time order. Some orders are up to 30 positions away from their place in time order, about one day of sales. If `created_at` is the payment time or the last-update time rather than the order time, some orders are dated on the wrong day, in both sources equally.
- **What I did:** used `created_at` as the order date.
- **Who can answer:** whoever owns the storefront export.
- **Question:**
  > In the order export, is "created_at" the time the order was placed, or the time it was paid or last updated?

### O8 (Q-RECOGNITION). When revenue is recognized

- **What:** both sources date revenue on the day the order is placed. For the accounts, revenue is usually recognized when the goods are shipped or delivered. The two can differ for orders placed near the start or end of a period.
- **What I did:** reported on order date, as finance does, and called the figure "net order revenue" rather than revenue.
- **Who can answer:** CFO.
- **Question:**
  > Is this daily report meant to show orders taken (order date) or revenue recognized (shipment or delivery date)?

### O9 (Q-TEST-REFUND). A test order that was partly refunded

- **What:** E76-1588 (facebook, 2026-01-30, USD 131.84) is flagged as a test order but has a USD 65.92 refund. Refunding a test order suggests a real customer paid. It is the only test order with a refund.
- **What I did:** excluded it, like every other test order, as finance does. The affected row carries `Q-TEST-REFUND`.
- **Impact:** up to +65.92 (gross minus refund) in Paid Social on 2026-01-30.
- **Who can answer:** whoever owns the storefront.
- **Question:**
  > Order E76-1588 is flagged as a test but was partly refunded (USD 65.92). Was it a real customer order?

## Preventing this next month

### Checks that would catch each issue automatically

Run after both extracts land. Each check fails loudly instead of letting the number through. Checks marked *built* are already enforced by `reconcile.py`.

| Check | Catches |
|---|---|
| Every storefront channel label is in the mapping (*built*) | R1, and any new label such as a new ad network |
| Every currency is USD or CAD (*built*) | New currencies arriving without a rate |
| `order_id` is unique in the storefront extract | R2 |
| Finance has 5 rows for every day, including zero rows | R4 |
| Recomputing finance from the storefront with the agreed rule leaves no difference in any day and channel above USD 0.01 (*built* as the bridge's `unexplained` column) | O2, R2, R3, and any new cause |
| The finance extract was pulled after the last day closed: its extract time is later than 23:59 on the last day, and the storefront's last order of that day is in finance | R3 |
| The CAD rate used differs from the reference rate by less than an agreed tolerance | O1 |
| Order IDs have no gaps, and orders just outside the ID range are checked for dates inside the period | R7 |
| No refund exceeds its order's gross, and no cancelled order carries revenue | O2, O5 |
| Totals for days already reported have not changed since the last run. Any change is listed as a restatement | O5 (late refunds), O2 (late cancellations) |

### What I would change in how the extracts are produced

1. **Build finance's report from the storefront orders**, order by order, with `order_id` kept. The two stop being separate sources that have to be reconciled, and any difference can be traced to an order in minutes.
2. **Pull the extracts after the day closes**, in a stated time zone, and record the extract time in the file. This removes R3.
3. **Add the missing fields to the order export:** placed, paid, cancelled and refunded timestamps, plus tax, shipping and discount amounts, and the USD amount actually settled. This answers O5, O6, O7 and O1 from data instead of from people.
4. **Replace the free-text channel with a controlled list** that includes a paid or organic flag. This removes R1, O3 and O4.
5. **Write down the revenue definition** once the client answers O1 to O9, and keep it in the code with a version. The CFO's number and the analyst's number then come from the same rule.
6. **Report late changes as adjustments, not silent restatements.** A refund or cancellation after a day is reported becomes a new dated line, so past totals stay stable.

## Limitations

- Test orders that were never flagged cannot be detected (see R5).
- The reconciliation only compares one source with the other. Where both sources share a problem, it shows up only as an open question (O5 to O8), not as a difference.
- Neither file shows chargebacks, disputes or payment processing fees. The figures are before fees, and any chargeback is not deducted.
- Nothing here is tied to cash. Matching the figures to payment processor payouts would be the next check.
