# Medical consumables in the Fusion GL (KPI 63)

**Why this note exists.** KPI 63 (Total Consumables Ratio) is GL medical consumables ÷ net revenue (spec Appendix B). The combined GL (`gold.fact_gl_fs_monthly`) takes each branch-month from Oasis before the branch's Fusion cutover and from Fusion after it. Oasis has a `medical consumables` caption. Fusion has none, so the KPI drops to about 0 after each cutover.

Queried read-only on 2026-10-20 through `HNH_Gold`.

## Finding

**Fusion has no expense account for medical consumables, and stock issued to patients is not costed in the GL.**
- Fusion's medical inventory accounts grow through 2026: Medical Supplies 11501101 +13.7M, OTC & Pharmacy Items 11501302 +77.4M, Medical Implants 11501102 +1.8M.
- The only cost-of-goods expense is 1.2–1.5M on "COGS of SCR - Others" (51101108) and a stock-count shortage account.
- In Oasis, `medical consumables` was 160.5M in 2025.

Mapping an existing Fusion account to the caption will therefore not restore the KPI. The consumption has to be posted first.

## Oasis accounts on `medical consumables` (2025 movement, SAR M)

| Account | 2025 |
|---|---|
| 31300001 | 65.73 |
| 411502000 | 9.01 |
| 31300002 | 7.60 |
| 31300004 | 3.95 |
| 411503000 | 3.29 |
| 31300000 | 3.24 |
| 31300003 | 1.36 |
| 31650001 | 0.69 |
| 31650310 | 0.67 |
| others (19 accounts) | 1.0 in total |

## Fusion accounts that could carry it

| Natural account | Name | Current caption | 2026 movement (SAR M) | Map to `medical consumables`? |
|---|---|---|---|---|
| 51101108 | COGS of SCR - Others | Cost of Goods Sold | 1.548 | |
| 51101102 | COGS of SCR - Insurance Companies | Cost of Goods Sold | 0 | |
| 51101103 | COGS of SCR - Government, Embassies | Cost of Goods Sold | 0 | |
| 51201202 | Stock Count Variances (Shortage) | Cost of Goods Sold | 0.862 | |

## What to decide

1. **Finance:** the account that patient consumption of medical supplies will be posted to in Fusion, and when the inventory issues start posting. Until then KPI 63 shows about 0 for Fusion months.
2. **Then:** add that account in `map_fs_account` with caption `medical consumables` and reload it with `scripts/load_fs_mapping.ps1`. The KPI picks it up at the next build.
3. **Meanwhile, optionally:** park KPI 63 for Fusion months by inserting a `map_bsc_kpi` row with `status = 'parked'`. Or keep it active and read the drop as a known gap.
