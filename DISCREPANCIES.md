# Discrepancy note (draft)

Working draft. Each item moves to "Resolved" or "Open" as it is investigated.

## Inventory from first profiling pass

| # | Observation | Evidence |
|---|---|---|
| 1 | Channel taxonomy differs: storefront has 8 raw values, finance has 5 buckets | Storefront: `facebook`, `Facebook Ads`, `fb`, `tiktok`, `google`, `email`, `(direct)`, `affiliate`. Finance: `Direct`, `Email`, `Other`, `Paid Search`, `Paid Social` |
| 2 | Finance `Other` is about 2x storefront `affiliate`, so something besides affiliate lands in `Other` | `Other` = 18,488.78; `affiliate` gross = 9,027.45 |
| 3 | Exact duplicate order rows | 5 order_ids appear twice with identical values (E76-1097, E76-1184, E76-1212, E76-1365, E76-1658) |
| 4 | Cancelled orders present | 28 rows with `status = cancelled`, none with a refund |
| 5 | Test orders present | 12 rows with `is_test_order = true` |
| 6 | Refunds present | 38 orders with `refund > 0`, 15 of them full refunds. The refund has no date of its own |
| 7 | Mixed currency | 128 orders in CAD; finance reports `revenue_usd`; no FX rate in either file |
| 8 | Finance is missing 5 day x channel cells | 2026-01-07 Direct, 2026-01-09 Paid Search, 2026-01-17 Direct, 2026-01-21 Email, 2026-01-25 Direct |
| 9 | Storefront timestamps are UTC; finance dates have no stated time zone | All orders fall between 14:00 and 23:59 UTC, so a US time zone would not move any order across midnight. To confirm in the baseline comparison |

Period: 2026-01-06 to 2026-02-04 (30 days) in both files. 741 order rows, 736 distinct order_ids. 145 finance rows.

## Findings from the baseline comparison

Finance can be reproduced cell by cell with this rule:

- revenue = gross - refund, on the order's UTC date
- excluding test orders and cancelled orders
- CAD converted at a fixed 0.74
- channels mapped as: `facebook`, `Facebook Ads`, `fb` -> Paid Social; `google` -> Paid Search; `(direct)` -> Direct; `email` -> Email; `affiliate`, `tiktok` -> Other
- duplicate rows counted as many times as they appear

With that rule, 137 of 150 day x channel cells match to the cent. Every one of the other 13 is explained by specific orders:

| Cause | Cells | Orders | Effect on finance |
|---|---|---|---|
| Finance includes some cancelled orders, not others | 10 | 14 cancelled orders included (E76-1229, 1262, 1297, 1301, 1341, 1351, 1362, 1365, 1370, 1388, 1469, 1548, 1569, 1574); the other 11 non-test cancelled orders are excluded. No pattern by date, channel or currency | +1,389.34 |
| Finance stops on 2026-02-04 between 21:35 and 22:10 UTC | 3 (Direct, Email, Paid Social on 02-04) | E76-1735, 1721, 1707, 1712, 1708 missing | -711.75 |

Other confirmations:

- Duplicates are counted twice in finance: with the duplicate included, Direct 01-13 and Paid Search 02-02 match exactly. Double counting of the 4 paid duplicates: +231.96.
- The 5 cells missing from finance have no storefront orders. Finance omits zero rows.
- Refunds are netted on the order date in both sources. Neither file carries a refund date.
- Test orders: finance already excludes all 12.
- Time zone: UTC calendar days reproduce finance exactly, so there is no time zone shift.
