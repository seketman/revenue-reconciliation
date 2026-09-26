# Revenue reconciliation: storefront vs finance

Period: 2026-01-06 to 2026-02-04 (30 days). Sources: `orders.csv` (storefront, one row per order) and `finance_export.csv` (finance, daily revenue by channel).

## Summary

**Reconciled revenue: USD 76,393.86.** Finance reported USD 77,303.41. Every cent of the USD 909.55 gap is traced to three problems in how the finance figure was built:

| | USD |
|---|---:|
| Finance export | 77,303.41 |
| Cancelled orders that finance counted | -1,389.34 |
| Duplicate orders that finance counted twice | -231.96 |
| Orders missing from finance on the last day (extract cut off at about 22:00 UTC) | +711.75 |
| **Reconciled** | **76,393.86** |

**Definition of revenue used:** order gross minus refunds, in USD, dated on the order's UTC calendar day. Test orders and cancelled orders are excluded, and each order is counted once. CAD orders are converted at 0.74, the rate finance uses. Each day-by-channel figure is rounded to the cent, and totals are sums of those rounded figures, the same way finance reports. Rounding the unrounded total once would give a result within USD 0.02 of this one.

| Channel | Finance | Reconciled | Difference |
|---|---:|---:|---:|
| Paid Social | 30,645.21 | 29,843.62 | -801.59 |
| Other | 18,488.78 | 18,229.74 | -259.04 |
| Email | 9,899.05 | 10,084.95 | +185.90 |
| Direct | 8,934.57 | 9,333.09 | +398.52 |
| Paid Search | 9,335.80 | 8,902.46 | -433.34 |
| **Total** | **77,303.41** | **76,393.86** | **-909.55** |

**What I stand behind:** the reconciled daily figures, computed under the definition above, and the explanation of the gap to finance. No part of the gap is unexplained.

**What I cannot give you yet:** seven questions only the business can answer. Two of them could move the total: which currency rate to use (each 0.01 of CAD rate moves revenue by USD 142.65) and whether the 14 cancelled orders were actually charged (USD 1,389.34). Two others move revenue between channels, not the total. The three remaining concern definitions. The questions are in the last section, written to be answered in one line.

Deliverables: `output/reconciled_revenue.csv` (daily revenue by channel) and `output/finance_bridge.csv` (the same days and channels, with finance's figure and the cause of every difference). Each row of the reconciled table lists the open questions that affect it in the `open_questions` column, using the codes in the question headings below (for example `Q-FX`). Q-CANCELLED marks every cell that had a cancelled order. Q-GROSS and Q-CREATED-AT affect every cell, so they are not listed per row.

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
- **What I did:** counted each order once, because an order ID identifies one order. This removes USD 231.96 that finance double counted.

### R3. Finance's last day is incomplete

- **What:** finance's figures for 2026-02-04 are missing every order placed after about 22:00 UTC.
- **How I know:** the last order finance includes is at 21:35 UTC and the first one it misses is at 22:10 UTC. The missing orders are E76-1735, E76-1721, E76-1707 (Direct), E76-1712 (Email) and E76-1708 (Paid Social). On every earlier day, orders up to 23:59 UTC are included.
- **What I did:** used the full day from the storefront, adding USD 711.75. The finance extract was most likely taken before the day closed. The day's figure should be re-pulled if it was reported.

### R4. Five day-by-channel rows missing from finance

- **What:** finance has 145 rows, not 150. Missing: 01-07 Direct, 01-09 Paid Search, 01-17 Direct, 01-21 Email and 01-25 Direct.
- **How I know:** the storefront has no orders on those days and channels.
- **What I did:** the reconciled table shows these cells as 0.00, so every day has all five channels.

### R5. Test orders (checked, not a discrepancy)

- **What:** there are 12 orders flagged `is_test_order`.
- **How I know:** finance's figures match only when these orders are excluded.
- **What I did:** excluded them.
- **Limitation:** test orders that were never flagged cannot be detected from the data. I found no suspicious amounts, such as very small or repeated values.

### R6. Time zone (checked, not a discrepancy)

- **What:** storefront timestamps are in UTC and finance dates have no stated time zone.
- **How I know:** UTC calendar days reproduce finance exactly. All orders fall between 14:00 and 23:59 UTC.
- **What I did:** used UTC days.

### R7. Completeness of the storefront extract (checked, not a discrepancy)

- **What:** order IDs run from E76-1000 to E76-1735 with no gaps, so no order is missing from the storefront extract within the period.

## Open questions for the client

Each of these needs a decision that is not in the data. The reconciled table follows finance's current practice for each one, or excludes the item when that is the safer default, and says so. None of these has been settled by guessing.

### O1 (Q-FX). Currency rate for CAD orders

- **What:** 123 paid orders (CAD 14,264.62 net) are in Canadian dollars. Finance converts them all at a flat 0.74. Neither file contains an exchange rate.
- **What I did:** used 0.74 so the figures stay comparable with finance. The `cad_net_native` column keeps the CAD amount, so the table can be recomputed at another rate (`uv run reconcile.py --fx-rate <rate>`).
- **Impact:** each 0.01 change in the rate moves revenue by USD 142.65.
- **Question:**
  > Finance converts all CAD orders at a flat 0.74 for the whole period. Should revenue use that flat rate, or a daily rate? If daily, from which source?

### O2 (Q-CANCELLED). Cancelled orders that finance counted as revenue

- **What:** 25 orders are cancelled (not counting test orders). Finance counts 14 of them (USD 1,389.34) and leaves out the other 11. I found no pattern by date, channel or currency.
- **How I know:** each of the 10 cells where finance is higher than the storefront matches, to the cent, the value of one or two cancelled orders in that cell.
- **What I did:** excluded all cancelled orders. The storefront shows no refund on any of them, so either they were never charged, or they were charged and then cancelled without the money being returned.
- **Question:**
  > Finance's report counts these 14 cancelled orders as revenue: E76-1229, 1262, 1297, 1301, 1341, 1351, 1362, 1365, 1370, 1388, 1469, 1548, 1569, 1574 (USD 1,389.34 in total). Were any of them charged and not refunded?

### O3 (Q-TIKTOK). TikTok reported under "Other"

- **What:** finance puts TikTok orders (USD 10,414.39) in Other together with affiliate, not in Paid Social.
- **What I did:** kept finance's mapping, so the channel totals stay comparable. Affected cells carry `Q-TIKTOK`.
- **Question:**
  > TikTok orders (USD 10,414.39 this period) are currently reported under "Other", not "Paid Social". Is that intentional?

### O4 (Q-FB-ORGANIC). Three Facebook labels, possibly paid and organic mixed

- **What:** the storefront uses `facebook`, `Facebook Ads` and `fb` at the same time, every day of the period, so this is not a rename. Finance puts all three in Paid Social. If `facebook` is unpaid (organic) traffic, Paid Social is overstated by USD 11,686.46.
- **What I did:** kept all three in Paid Social, as finance does. Affected cells carry `Q-FB-ORGANIC`.
- **Question:**
  > The storefront tags Facebook orders three ways: "facebook", "Facebook Ads" and "fb". Are all three paid ads, or is any of them unpaid (organic) traffic?

### O5 (Q-REFUND-DATE). Refunds are dated on the order, not on the refund

- **What:** 37 paid orders carry refunds (USD 2,703.13). Both sources subtract each refund on the day the order was placed. Neither file has a refund date. As a result, a day that has already been reported goes down whenever a later refund arrives.
- **What I did:** followed the current practice. Affected cells carry `Q-REFUND-DATE`.
- **Question:**
  > Should a refund reduce revenue on the day of the original order (current practice, which changes past days), or on the day of the refund? If the latter, can the storefront export include the refund date?

### O6 (Q-GROSS). What the `gross` amount contains

- **What:** neither file says whether `gross` includes sales tax, shipping or discounts. This affects every figure in both sources.
- **What I did:** used `gross` as it comes.
- **Question:**
  > Does the "gross" amount in the order export include sales tax, shipping, or discounts? Which of those should count as revenue?

### O7 (Q-CREATED-AT). What `created_at` represents

- **What:** order IDs are not in time order. Some orders are up to 30 positions away from their place in time order, about one day of sales. If `created_at` is the payment time or the last-update time rather than the order time, some orders are dated on the wrong day, in both sources equally.
- **What I did:** used `created_at` as the order date.
- **Question:**
  > In the order export, is "created_at" the time the order was placed, or the time it was paid or last updated?

## Limitations

- Test orders that were never flagged cannot be detected (see R5).
- The reconciliation only compares one source with the other. Where both sources share a problem, it shows up only as an open question (O5, O6, O7), not as a difference.
