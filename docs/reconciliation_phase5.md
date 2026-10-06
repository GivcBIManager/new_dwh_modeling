# Phase 5 reconciliation (supply chain)

Run after a successful `dbt build --select tag:hnh`. Figures below are measured on the live tables after the full build of 2026-10-06 (`PASS=1037 WARN=49 ERROR=3 TOTAL=1089`, about 17.5 minutes, peak query memory 69.7 GiB). The 3 errors were Phase 4 position-key relationship tests, fixed afterwards by commit 271be60 (Fusion HR staging keeps end-dated members) and re-tested green; they are not supply-chain nodes. Amounts are SAR. Branches: 1 Al-Rabwa, 2 Khamis, 3 Jazan, 4 Unaizah, 5 Madinah, 6 Abha, 7 Ghirnata, 8 Muhayil, 100 Head Office. Data is as of 2026-10-06; October 2026 is a partial month.

Row counts of the supply models at this build: `gold.dim_item` 99,316; `gold.dim_store` 2,618; `gold.dim_movement_type` 10; `gold.dim_supplier` 32,044; `gold.fact_stock_movement` 32,225,374; `gold.fact_patient_consumption` 26,467,826; `gold.fact_stock_monthly` 296,821; `gold.fact_purchase_line` 438,958; `gold.fact_goods_receipt` 408,248; `gold.rec_stock_interface_daily` 1,870; `gold.rec_inventory_gl_monthly` 55; `gold.rec_purchase_ap_monthly` 338; `gold.rec_consumption_charge_monthly` 332; `int.int_item_crosswalk` 14,893; `int.int_oasis_stock_line` 32,181,475; `int.int_fusion_stock_line` 1,034,150; `int.int_stock_month_end` 228,487; `int.int_store_crosswalk` 324; `int.int_consumption_charge_link` 39,796,013. `stg_ref__stock_snapshot` is empty (0 rows) until `bal_product_base` is loaded. The staging views are not counted.

## 1. Stock lines and the cutover (`gold.fact_stock_movement`)

Go-live dates of `map_scm_cutover` (inventory go-live date, first Fusion purchasing month): Khamis (2) 2026-09-05 / 202609, Jazan (3) 2026-07-12 / 202607, Unaizah (4) 2026-08-01 / 202608, Madinah (5) 2026-09-05 / 202609, Abha (6) 2026-05-01 / 202605, Ghirnata (7) 2026-04-26 / 202604, Muhayil (8) 2026-05-03 / 202608, Head Office (100) not set / 202603. Al-Rabwa (1) has no row: it is not live on Fusion inventory, and Head Office has no go-live date (O-P5-6).

Rows by branch and source (cost_amount as recorded; a gap row is an Oasis line that Fusion has not received yet):

| Branch | Source | Fusion gap | Lines | Cost |
|---|---:|---:|---:|---:|
| 1 Al-Rabwa | oasis | 0 | 8,376,645 | 29,832,723 |
| 2 Khamis | fusion | 0 | 80,988 | 2,142,302 |
| 2 Khamis | oasis | 0 | 7,116,841 | 16,043,646 |
| 2 Khamis | oasis | 1 | 31,382 | -2,302,097 |
| 3 Jazan | fusion | 0 | 188,833 | 12,372,214 |
| 3 Jazan | oasis | 0 | 5,212,857 | 37,237,753 |
| 3 Jazan | oasis | 1 | 127,138 | -6,887,089 |
| 4 Unaizah | fusion | 0 | 164,476 | 2,718,923 |
| 4 Unaizah | oasis | 0 | 5,067,455 | 38,304,169 |
| 4 Unaizah | oasis | 1 | 64,020 | -3,468,285 |
| 5 Madinah | fusion | 0 | 74,102 | -651,863 |
| 5 Madinah | oasis | 0 | 4,506,388 | 48,624,847 |
| 5 Madinah | oasis | 1 | 25,056 | -1,869,223 |
| 6 Abha | fusion | 0 | 128,625 | 12,360,942 |
| 6 Abha | oasis | 0 | 701,689 | 15,069,574 |
| 6 Abha | oasis | 1 | 161,529 | -11,504,513 |
| 7 Ghirnata | fusion | 0 | 63,992 | 18,038,624 |
| 7 Ghirnata | oasis | 0 | 38,319 | 1,522,653 |
| 7 Ghirnata | oasis | 1 | 61,977 | -1,282,374 |
| 8 Muhayil | fusion | 0 | 23,318 | 7,611,163 |
| 8 Muhayil | oasis | 1 | 9,744 | -305,703 |


By origin: source fusion, in Oasis 0, in Fusion 1, gap 0: 66,402; source fusion, in Oasis 1, in Fusion 1, gap 0: 657,932; source oasis, in Oasis 1, in Fusion 0, gap 0: 31,018,433; source oasis, in Oasis 1, in Fusion 0, gap 1: 480,846; source oasis, in Oasis 1, in Fusion 1, gap 0: 1,761. So 657,932 lines that exist in both systems are taken from Fusion (kept on the Oasis date), 66,402 are Fusion-only, and 480,846 are gap-filled from Oasis and move to Fusion on a later build without changing date.

The 22,503 Oasis batch postings (STOCKISS BATCH / BAT-) after each go-live are left out: after go-live the Oasis GRNs stop and batch receipts appear at the rate of Fusion PO receipts (Jazan August 1,596 batch lines against 1,568 Fusion PO receipts), so they echo Fusion transactions that are already lines of their own. The 38,406 integration transactions without a parseable Oasis reference (April to July: Abha 4,707, Ghirnata 33,281, Jazan 418) are left out because their Oasis lines exist and are gap-filled or matched by other transactions; 8,282 reference an Oasis line that Oasis does not hold (mainly Muhayil before its Oasis history starts on 2026-06-16) and become Fusion-only lines. 49,682 Fusion transactions dated before a branch go-live are shown in the interface reconciliation and not in the fact.

Fusion transactions that reference an Oasis line the Oasis side excludes (211,572 after go-live): reversed invoice 186,529, CREDITAR 23,364 (Ghirnata), not stock or zero cost 1,067, other 612. The fact drops 209,893 of them (reversed invoice and CREDITAR, consistent with Oasis) and keeps 1,679 (the last two reasons) as Fusion-only lines.

Consumption cost by branch and year (`sum(consumption_cost)` where `is_consumption = 1`):

| Branch | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 24,027,521 | 59,252,925 | 54,584,326 | 48,849,615 | 57,017,846 |
| 2 Khamis | 50,425,563 | 61,500,002 | 57,846,950 | 43,942,805 | 36,010,169 |
| 3 Jazan | 29,278,995 | 34,896,418 | 40,420,366 | 41,244,230 | 36,696,240 |
| 4 Unaizah | 25,398,169 | 25,334,734 | 24,366,170 | 25,140,748 | 20,923,179 |
| 5 Madinah | 21,594,250 | 33,824,369 | 31,398,431 | 31,267,739 | 24,026,971 |
| 6 Abha | 0 | 0 | 1,249,574 | 17,606,796 | 17,376,262 |
| 7 Ghirnata | 0 | 0 | 0 | 0 | 2,875,082 |
| 8 Muhayil | 0 | 0 | 0 | 0 | 486,999 |


## 2. Fusion interface gap (`gold.rec_stock_interface_daily`)

Gap share = Oasis lines from go-live that Fusion has not received, over all lines from go-live, for the last 30 closed days (is_live = 1):

| Branch | Lines | Gap lines | Gap share |
|---|---:|---:|---:|
| 2 Khamis | 107,245 | 31,114 | 0.290 |
| 3 Jazan | 103,128 | 66,259 | 0.642 |
| 4 Unaizah | 110,348 | 41,973 | 0.380 |
| 5 Madinah | 93,767 | 24,833 | 0.265 |
| 6 Abha | 53,730 | 35,923 | 0.669 |
| 7 Ghirnata | 32,051 | 16,599 | 0.518 |
| 8 Muhayil | 9,773 | 5,261 | 0.538 |


From each go-live to today 480,846 of 1,138,778 Oasis lines (42%) are not in Fusion. Jazan's coverage (1 minus gap share) by month: 
2026-07 81%, 2026-08 63%, 2026-09 33%, 2026-10 60%. The planning profile (about 78% coverage in mid-July falling to 15 to 20% in late September) is the daily view of the same decline; the monthly figures above average it. This is open item O-P5-1: is it an integration backlog or an extract gap in staging?

Interface totals per branch (all days): Oasis lines, Oasis lines found in Fusion, Fusion integration transactions, without reference, before go-live, batch lines left out, gap lines, out-of-scope reversals dropped, out-of-scope rows kept:

| Branch | Oasis lines | In Fusion | Fusion txns | No reference | Before go-live | Batch left out | Gap lines | OOS reversals | OOS kept |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 1,393,463 | 0 | 0 | 0 | 15,240 | 0 | 0 | 0 | 0 |
| 2 Khamis | 928,782 | 79,876 | 86,699 | 0 | 8,257 | 940 | 31,382 | 6,392 | 334 |
| 3 Jazan | 880,302 | 165,865 | 238,713 | 418 | 0 | 4,185 | 127,138 | 65,922 | 180 |
| 4 Unaizah | 831,437 | 162,788 | 180,580 | 0 | 7,160 | 2,735 | 64,020 | 16,518 | 425 |
| 5 Madinah | 714,682 | 71,694 | 74,827 | 0 | 6,184 | 649 | 25,056 | 2,971 | 144 |
| 6 Abha | 421,543 | 106,035 | 157,557 | 4,707 | 10,951 | 6,576 | 161,529 | 45,976 | 423 |
| 7 Ghirnata | 152,320 | 58,449 | 166,316 | 33,281 | 25 | 4,400 | 61,977 | 70,938 | 163 |
| 8 Muhayil | 27,705 | 14,943 | 23,336 | 0 | 0 | 3,018 | 9,744 | 1,176 | 10 |
| 100 Head Office | 0 | 0 | 0 | 0 | 1,865 | 0 | 0 | 0 | 0 |


The interface reconciliation closes: every Oasis line and Fusion transaction is accounted for by one column.


## 3. Patient consumption against the charge (`gold.rec_consumption_charge_monthly`)

Link rate = patient-sale and return lines linked to at least one live charge; cost, revenue and margin cover `revenue_basis = 'charge'` lines only. Package-component dispenses carry cost but their revenue is on the package header, so their cost is reported separately (`package_component_cost`); cancelled-only charges likewise (`cancelled_only_cost`). Margin = revenue minus cost on `revenue_basis = 'charge'`.

| Branch | Year | Lines | Link rate | Cost (charge) | Revenue | Margin | Package comp. cost | Cancelled-only cost | Sales w/o charge | Med. charges w/o cost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 2022 | 796,675 | 0.9935 | 12,832,622 | 19,518,033 | 6,685,411 | 3,888,464 | 14,418 | 0 | 558,612 |
| 1 Al-Rabwa | 2023 | 1,915,263 | 0.9950 | 30,903,138 | 44,887,799 | 13,984,661 | 10,422,492 | 25,231 | 35 | 102,326 |
| 1 Al-Rabwa | 2024 | 1,636,122 | 0.9951 | 29,914,458 | 43,893,206 | 13,978,748 | 11,193,899 | -15,695 | 9 | 149,365 |
| 1 Al-Rabwa | 2025 | 1,460,521 | 0.9939 | 22,315,250 | 35,569,929 | 13,254,679 | 12,207,504 | 8,176 | 13 | 50,306 |
| 1 Al-Rabwa | 2026 | 1,302,816 | 0.9936 | 23,531,669 | 37,583,041 | 14,051,371 | 10,955,161 | 1,018 | 344 | 822 |
| 2 Khamis | 2022 | 1,294,736 | 0.9743 | 20,277,625 | 30,887,411 | 10,609,786 | 11,665,588 | 73,665 | 0 | 9,165 |
| 2 Khamis | 2023 | 1,465,433 | 0.9754 | 28,234,217 | 38,342,919 | 10,108,702 | 13,521,391 | -11,260 | 130 | 8,988 |
| 2 Khamis | 2024 | 1,266,115 | 0.9770 | 23,381,284 | 34,508,268 | 11,126,983 | 16,197,990 | 30,428 | 181 | 5,182 |
| 2 Khamis | 2025 | 1,104,854 | 0.9765 | 16,932,641 | 27,604,983 | 10,672,342 | 12,497,402 | -1,984 | 456 | 2,541 |
| 2 Khamis | 2026 | 845,037 | 0.9751 | 13,808,243 | 24,662,628 | 10,854,385 | 10,228,355 | 7,533 | 429 | 1,442 |
| 3 Jazan | 2022 | 793,426 | 0.9917 | 12,944,965 | 21,511,665 | 8,566,699 | 8,387,726 | 4,418 | 0 | 6,580 |
| 3 Jazan | 2023 | 927,024 | 0.9943 | 16,190,749 | 25,456,988 | 9,266,239 | 9,546,313 | 3,164 | 10 | 2,917 |
| 3 Jazan | 2024 | 937,590 | 0.9935 | 17,217,210 | 26,851,927 | 9,634,717 | 9,507,341 | 840 | 27 | 2,757 |
| 3 Jazan | 2025 | 963,601 | 0.9918 | 13,852,294 | 22,914,322 | 9,062,028 | 10,632,553 | 1,811 | 62 | 1,843 |
| 3 Jazan | 2026 | 812,472 | 0.9875 | 12,156,533 | 23,514,856 | 11,358,322 | 11,313,505 | 3,303 | 3,322 | 806 |
| 4 Unaizah | 2022 | 791,035 | 0.9905 | 10,264,910 | 15,725,929 | 5,461,020 | 7,500,948 | 9,140 | 14 | 4,328 |
| 4 Unaizah | 2023 | 926,152 | 0.9945 | 10,985,487 | 16,589,322 | 5,603,834 | 7,244,831 | 41,954 | 50 | 3,795 |
| 4 Unaizah | 2024 | 876,372 | 0.9943 | 10,431,713 | 16,556,023 | 6,124,310 | 6,411,067 | -34,950 | 101 | 2,631 |
| 4 Unaizah | 2025 | 938,045 | 0.9933 | 10,888,711 | 18,202,932 | 7,314,221 | 5,759,653 | 3,206 | 133 | 1,728 |
| 4 Unaizah | 2026 | 770,085 | 0.9889 | 9,353,569 | 18,813,264 | 9,459,696 | 5,213,000 | 2,180 | 428 | 728 |
| 5 Madinah | 2022 | 604,819 | 0.9746 | 7,532,491 | 12,206,941 | 4,674,450 | 5,733,466 | 9,380 | 0 | 557 |
| 5 Madinah | 2023 | 888,445 | 0.9945 | 14,169,356 | 21,683,229 | 7,513,873 | 7,229,892 | 4,971 | 47 | 1,284 |
| 5 Madinah | 2024 | 870,172 | 0.9817 | 13,890,063 | 21,539,491 | 7,649,428 | 7,997,667 | 12,431 | 21 | 1,758 |
| 5 Madinah | 2025 | 776,392 | 0.9862 | 10,349,361 | 18,010,418 | 7,661,057 | 7,583,247 | -16,634 | 97 | 1,325 |
| 5 Madinah | 2026 | 672,324 | 0.9905 | 9,807,432 | 18,306,249 | 8,498,817 | 6,493,480 | 287 | 159 | 771 |
| 6 Abha | 2024 | 9,806 | 0.9637 | 100,282 | 173,598 | 73,317 | 98,265 | 521 | 0 | 6 |
| 6 Abha | 2025 | 336,253 | 0.9354 | 4,197,722 | 7,663,757 | 3,466,035 | 5,317,516 | 4,000 | 24 | 279 |
| 6 Abha | 2026 | 359,729 | 0.9592 | 5,006,847 | 8,976,808 | 3,969,962 | 7,098,863 | -11,666 | 272 | 565 |
| 7 Ghirnata | 2025 | 1 | 0.0000 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 7 Ghirnata | 2026 | 113,745 | 0.9834 | 1,357,660 | 2,426,522 | 1,068,863 | 695,658 | 112 | 107 | 62 |
| 8 Muhayil | 2026 | 12,766 | 0.6150 | 86,740 | 234,460 | 147,720 | 31,571 | 44 | 2,409 | 4 |


Of 2026 cost, 52,029,593 SAR sits on package-component dispenses whose revenue is on the package header; counted against drug revenue it would turn Abha's 2026 margin negative (package cost 7.10M against a charge-basis margin of 3.97M). Cancelled-only charges in 2026 net to near zero (dispense-and-return pairs). Muhayil's 2026 link rate is 0.615: 2,409 sale lines in 2026 have no charge, 2,402 of them in May. `medication_charges_without_cost` counts medication charge lines with no stock cost line; it is high in 2022 to 2024 (Al-Rabwa 558,612 in 2022) and small in 2026.


## 4. Stock against the GL (`gold.rec_inventory_gl_monthly`)

Fusion stock value (valuation layers), the GL balance of inventory accounts 115* (posted and including unposted), cost distribution lines, the accounted share, and the posted difference, from February 2026 (months with no stock and no GL balance are left out):

| Branch | Month | Fusion stock value | GL posted | GL incl. unposted | Dist. lines | Accounted share | Difference (posted) |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 2026-02 | 6,543,978 | 0 | 0 | 13,544 | 0.000 | 6,543,978 |
| 1 Al-Rabwa | 2026-03 | -468 | 0 | 0 | 20,436 | 0.000 | -468 |
| 1 Al-Rabwa | 2026-04 | 13 | 0 | 0 | 24 | 0.000 | 13 |
| 1 Al-Rabwa | 2026-05 | 13 | 0 | 0 | 0 |  | 13 |
| 1 Al-Rabwa | 2026-06 | 13 | 0 | 0 | 0 |  | 13 |
| 1 Al-Rabwa | 2026-07 | 13 | 0 | 0 | 0 |  | 13 |
| 1 Al-Rabwa | 2026-08 | 13 | 0 | 0 | 0 |  | 13 |
| 1 Al-Rabwa | 2026-09 | 13 | 0 | 0 | 0 |  | 13 |
| 1 Al-Rabwa | 2026-10 | 13 | 0 | 0 | 0 |  | 13 |
| 2 Khamis | 2026-08 | 9,035,245 | 0 | 6,550,918 | 16,514 | 0.000 | 9,035,245 |
| 2 Khamis | 2026-09 | 9,983,781 | 0 | 6,550,918 | 155,434 | 0.000 | 9,983,781 |
| 2 Khamis | 2026-10 | 10,168,005 | 0 | 6,550,918 | 0 |  | 10,168,005 |
| 3 Jazan | 2026-07 | 10,447,884 | 9,420,592 | 21,740,894 | 187,230 | 0.000 | 1,027,293 |
| 3 Jazan | 2026-08 | 12,263,322 | 6,727,240 | 19,047,524 | 280,570 | 0.000 | 5,536,082 |
| 3 Jazan | 2026-09 | 12,499,449 | 5,608,440 | 17,928,725 | 93,634 | 0.000 | 6,891,009 |
| 3 Jazan | 2026-10 | 11,180,191 | 5,608,440 | 17,928,725 | 0 |  | 5,571,750 |
| 4 Unaizah | 2026-07 | 8,056,871 | 7,299,208 | 7,299,208 | 14,320 | 0.000 | 757,662 |
| 4 Unaizah | 2026-08 | 7,662,143 | 8,272,676 | 8,272,676 | 193,252 | 0.000 | -610,533 |
| 4 Unaizah | 2026-09 | 9,215,534 | 8,272,676 | 8,272,676 | 156,752 | 0.000 | 942,858 |
| 4 Unaizah | 2026-10 | 9,513,674 | 8,272,676 | 8,272,676 | 0 |  | 1,240,999 |
| 5 Madinah | 2026-08 | 7,327,972 | 0 | 0 | 12,368 | 0.000 | 7,327,972 |
| 5 Madinah | 2026-09 | 5,990,514 | 0 | 0 | 137,322 | 0.000 | 5,990,514 |
| 5 Madinah | 2026-10 | 6,150,279 | 0 | 0 | 0 |  | 6,150,279 |
| 6 Abha | 2026-02 | 3,136,548 | -0 | -0 | 6,776 | 0.123 | 3,136,548 |
| 6 Abha | 2026-03 | -20,207 | -0 | -0 | 16,816 | 0.101 | -20,207 |
| 6 Abha | 2026-04 | 721 | 6,501,189 | 6,501,189 | 196 | 0.020 | -6,500,468 |
| 6 Abha | 2026-05 | 43,508,566 | 50,158,806 | 50,158,806 | 68,622 | 0.997 | -6,650,240 |
| 6 Abha | 2026-06 | 419,273,692 | 426,412,251 | 426,412,251 | 78,596 | 0.950 | -7,138,559 |
| 6 Abha | 2026-07 | 135,799,108 | 147,522,327 | 147,522,327 | 22,930 | 0.092 | -11,723,219 |
| 6 Abha | 2026-08 | 10,061,966 | 56,162,403 | 56,162,403 | 153,158 | 0.027 | -46,100,437 |
| 6 Abha | 2026-09 | 10,867,806 | 55,216,316 | 55,216,316 | 50,588 | 0.008 | -44,348,510 |
| 6 Abha | 2026-10 | 10,568,099 | 55,191,992 | 55,191,992 | 4,200 | 0.000 | -44,623,893 |
| 7 Ghirnata | 2026-02 | 0 | 1,807,468 | 1,807,468 | 0 |  | -1,807,468 |
| 7 Ghirnata | 2026-03 | 0 | 2,024,504 | 2,024,504 | 46 | 0.000 | -2,024,504 |
| 7 Ghirnata | 2026-04 | 17,306,842 | 19,575,424 | 19,575,424 | 34,620 | 0.999 | -2,268,582 |
| 7 Ghirnata | 2026-05 | 18,301,005 | 20,588,049 | 20,588,049 | 52,174 | 0.994 | -2,287,045 |
| 7 Ghirnata | 2026-06 | 16,575,051 | 20,588,049 | 20,626,655 | 159,232 | 0.509 | -4,012,999 |
| 7 Ghirnata | 2026-07 | 16,835,415 | 20,588,049 | 20,626,655 | 48,274 | 0.000 | -3,752,634 |
| 7 Ghirnata | 2026-08 | 17,284,192 | 20,588,049 | 20,626,655 | 41,454 | 0.000 | -3,303,858 |
| 7 Ghirnata | 2026-09 | 17,383,757 | 20,588,049 | 20,626,655 | 38,520 | 0.000 | -3,204,293 |
| 7 Ghirnata | 2026-10 | 17,325,651 | 20,588,049 | 20,626,655 | 0 |  | -3,262,399 |
| 8 Muhayil | 2026-07 | 952,463 | 0 | 0 | 14,266 | 0.000 | 952,463 |
| 8 Muhayil | 2026-08 | 999,104 | 0 | 0 | 9,388 | 0.000 | 999,104 |
| 8 Muhayil | 2026-09 | 7,723,577 | 0 | 0 | 13,454 | 0.000 | 7,723,577 |
| 8 Muhayil | 2026-10 | 7,791,080 | 0 | 0 | 0 |  | 7,791,079 |
| 100 Head Office | 2026-02 | 3,070,094 | 0 | 0 | 1,808 | 0.000 | 3,070,094 |
| 100 Head Office | 2026-04 | 0 | -948 | -948 | 4 | 0.000 | 948 |
| 100 Head Office | 2026-05 | 0 | -948 | -948 | 0 |  | 948 |
| 100 Head Office | 2026-06 | 0 | -948 | -948 | 0 |  | 948 |
| 100 Head Office | 2026-07 | 0 | -948 | -948 | 0 |  | 948 |
| 100 Head Office | 2026-08 | 0 | -948 | -948 | 0 |  | 948 |
| 100 Head Office | 2026-09 | 0 | -948 | -948 | 0 |  | 948 |
| 100 Head Office | 2026-10 | 0 | -948 | -948 | 0 |  | 948 |


From July 2026 the accounted share of cost distributions is 0 to 9% (Abha 0.009 in September), so the GL no longer follows stock and the difference is not expected to tie (O-P5-3). Abha carries CEFODOX: one write-off on 2026-06-20 at 6,241,137 SAR per bottle (374,468,220 SAR) puts Abha's June month-end stock at 419.3M against 10.1M in August (O-P5-2). Jazan June 2026 shows stock 0 against 12.3M of unposted GL inventory: its inventory go-live is 2026-07-12, so June has no Fusion stock while the Oasis feed had already booked the opening inventory in the GL. Posted GL inventory is 0 for Khamis, Madinah and Muhayil so far (Khamis has 6.55M unposted).


## 5. Purchasing against AP (`gold.rec_purchase_ap_monthly`)

Ordered and received value by system, AP spend matched to a PO schedule, AP spend without a PO, and Fusion received value not matched to AP, 2026:

| Branch | Month | Oasis ordered | Fusion ordered | Oasis received | Fusion received | AP PO-matched | AP non-PO | Fusion received not matched |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa | 2026-01 | 6,743,985 | 0 | 5,720,706 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-02 | 7,505,870 | 0 | 4,910,973 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-03 | 11,052,783 | 0 | 6,787,476 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-04 | 8,377,575 | 0 | 10,477,978 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-05 | 8,615,893 | 0 | 6,240,741 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-06 | 11,567,962 | 0 | 8,601,825 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-07 | 8,612,153 | 0 | 8,446,142 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-08 | 8,563,186 | 0 | 7,125,939 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-09 | 9,117,423 | 0 | 6,793,117 | 0 | 0 | 0 | 0 |
| 1 Al-Rabwa | 2026-10 | 762,789 | 0 | 195,960 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-01 | 4,295,463 | 0 | 3,286,230 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-02 | 3,770,411 | 0 | 2,950,070 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-03 | 7,731,853 | 0 | 4,052,717 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-04 | 7,767,349 | 0 | 7,350,740 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-05 | 4,929,421 | 0 | 4,449,613 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-06 | 7,189,332 | 0 | 3,814,692 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-07 | 7,036,857 | 0 | 7,581,353 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-08 | 5,447,945 | 0 | 4,076,895 | 0 | 0 | 0 | 0 |
| 2 Khamis | 2026-09 | 1,109,841 | 5,432,727 | 1,214,854 | 2,149,741 | 6,412 | 0 | 2,143,329 |
| 2 Khamis | 2026-10 | 0 | 488,568 | 0 | 472,946 | 0 | 0 | 472,946 |
| 3 Jazan | 2026-01 | 6,545,689 | 0 | 4,936,714 | 0 | 0 | 0 | 0 |
| 3 Jazan | 2026-02 | 5,755,354 | 0 | 4,601,138 | 0 | 0 | 0 | 0 |
| 3 Jazan | 2026-03 | 6,517,618 | 0 | 4,525,219 | 0 | 0 | 0 | 0 |
| 3 Jazan | 2026-04 | 8,385,665 | 0 | 7,562,428 | 0 | 0 | 0 | 0 |
| 3 Jazan | 2026-05 | 5,693,548 | 0 | 6,616,927 | 0 | 0 | 0 | 0 |
| 3 Jazan | 2026-06 | 7,204,070 | 0 | 5,171,498 | 0 | 5,800 | 33,113,986 | -5,800 |
| 3 Jazan | 2026-07 | 1,211,042 | 5,872,514 | 1,726,687 | 1,511,295 | 1,591,546 | 1,039,556 | -80,251 |
| 3 Jazan | 2026-08 | 0 | 6,714,348 | 0 | 4,594,568 | 2,209,491 | 570,783 | 2,385,077 |
| 3 Jazan | 2026-09 | 0 | 6,180,070 | 0 | 6,373,663 | 4,975,137 | 967,356 | 1,398,526 |
| 3 Jazan | 2026-10 | 0 | 452,275 | 0 | 404,703 | 101,014 | 0 | 303,690 |
| 4 Unaizah | 2026-01 | 4,152,370 | 0 | 3,097,465 | 0 | 0 | 0 | 0 |
| 4 Unaizah | 2026-02 | 2,640,338 | 0 | 2,415,824 | 0 | 0 | 0 | 0 |
| 4 Unaizah | 2026-03 | 6,075,977 | 0 | 3,596,553 | 0 | 0 | 0 | 0 |
| 4 Unaizah | 2026-04 | 3,451,189 | 0 | 5,019,241 | 0 | 0 | 0 | 0 |
| 4 Unaizah | 2026-05 | 3,419,369 | 0 | 2,976,694 | 0 | 0 | 0 | 0 |
| 4 Unaizah | 2026-06 | 3,383,443 | 0 | 2,276,990 | 0 | 0 | 0 | 0 |
| 4 Unaizah | 2026-07 | 3,084,525 | 0 | 3,672,274 | 0 | 0 | 22,603,728 | 0 |
| 4 Unaizah | 2026-08 | 0 | 4,660,986 | 71,700 | 973,467 | 824,776 | 913,300 | 148,691 |
| 4 Unaizah | 2026-09 | 0 | 6,918,614 | 0 | 2,949,602 | 417,897 | 0 | 2,531,705 |
| 4 Unaizah | 2026-10 | 0 | 532,225 | 0 | 585,793 | 0 | 0 | 585,793 |
| 5 Madinah | 2026-01 | 3,626,103 | 0 | 2,681,573 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-02 | 3,540,620 | 0 | 2,729,048 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-03 | 4,948,505 | 0 | 3,331,053 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-04 | 4,224,507 | 0 | 4,204,775 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-05 | 2,778,455 | 0 | 2,821,852 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-06 | 4,406,589 | 0 | 3,914,748 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-07 | 3,078,144 | 0 | 2,191,081 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-08 | 4,220,799 | 0 | 4,323,793 | 0 | 0 | 0 | 0 |
| 5 Madinah | 2026-09 | 75,781 | 4,360,739 | 277,338 | 991,452 | 811,271 | 201,887 | 180,181 |
| 5 Madinah | 2026-10 | 0 | 620,679 | 0 | 342,177 | 0 | 0 | 342,177 |
| 6 Abha | 2026-01 | 2,073,561 | 0 | 2,024,478 | 0 | 0 | 0 | 0 |
| 6 Abha | 2026-02 | 3,124,926 | 0 | 2,105,105 | 0 | 0 | 0 | 0 |
| 6 Abha | 2026-03 | 2,351,144 | 0 | 1,284,079 | 0 | 363 | 49,471 | -363 |
| 6 Abha | 2026-04 | 4,397,245 | 0 | 3,922,483 | 0 | 0 | 43,077 | 0 |
| 6 Abha | 2026-05 | 701,336 | 31,408,877 | 458,735 | 1,583,362 | 915,760 | 16,381,221 | 667,602 |
| 6 Abha | 2026-06 | 0 | 3,550,835 | 0 | 2,486,005 | 3,028,822 | 2,635,613 | -542,817 |
| 6 Abha | 2026-07 | 0 | 3,360,938 | 0 | 1,938,662 | 2,004,853 | 1,422,668 | -66,191 |
| 6 Abha | 2026-08 | 0 | 3,301,415 | 0 | 2,337,545 | 2,040,275 | 804,173 | 297,269 |
| 6 Abha | 2026-09 | 0 | 5,507,611 | 0 | 3,606,850 | 3,643,441 | -144,022 | -36,591 |
| 6 Abha | 2026-10 | 0 | 319,346 | 0 | 356,202 | 10,666 | 788 | 345,536 |
| 7 Ghirnata | 2026-02 | 291 | 0 | 0 | 0 | 0 | 0 | 0 |
| 7 Ghirnata | 2026-03 | 53,940 | 0 | 875 | 0 | 0 | 0 | 0 |
| 7 Ghirnata | 2026-04 | 723,620 | 465,523 | 232,283 | 1,300 | 0 | 0 | 1,300 |
| 7 Ghirnata | 2026-05 | 0 | 621,262 | 8,906 | 267,950 | 26,243 | 0 | 241,707 |
| 7 Ghirnata | 2026-06 | 0 | 754,010 | 0 | 234,773 | 223,489 | 0 | 11,284 |
| 7 Ghirnata | 2026-07 | 0 | 101,722 | 0 | 137,805 | 190,082 | 0 | -52,277 |
| 7 Ghirnata | 2026-08 | 0 | 655,733 | 0 | 255,424 | 381,144 | 55,790 | -125,720 |
| 7 Ghirnata | 2026-09 | 0 | 925,611 | 0 | 453,640 | 200,812 | 0 | 252,828 |
| 7 Ghirnata | 2026-10 | 0 | 270,793 | 0 | 120,867 | 56,996 | 0 | 63,871 |
| 8 Muhayil | 2026-07 | 0 | 0 | 0 | 0 | 0 | 8,700 | 0 |
| 8 Muhayil | 2026-08 | 0 | 987,169 | 0 | 45,239 | 26,639 | 74,452 | 18,600 |
| 8 Muhayil | 2026-09 | 0 | 1,126,242 | 0 | 725,652 | 676,757 | 63,209 | 48,896 |
| 8 Muhayil | 2026-10 | 0 | 187,686 | 0 | 13,400 | 0 | 0 | 13,400 |
| 100 Head Office | 2026-03 | 0 | 97,639,423 | 0 | 192,450 | 0 | 0 | 192,450 |
| 100 Head Office | 2026-04 | 0 | 0 | 0 | 0 | 0 | 97,224,132 | 0 |
| 100 Head Office | 2026-05 | 0 | 0 | 0 | 0 | 0 | 12,886,218 | 0 |
| 100 Head Office | 2026-06 | 0 | 268,146 | 0 | 0 | 70,650 | 0 | -70,650 |
| 100 Head Office | 2026-07 | 0 | 1,926,168 | 0 | 0 | 43,478 | 126,235 | -43,478 |
| 100 Head Office | 2026-08 | 0 | 17,226,370 | 0 | 233,950 | 67,500 | 114,251 | 166,450 |
| 100 Head Office | 2026-09 | 0 | 26,816,980 | 0 | 1,079,810 | 267,395 | 4,652,847 | 812,415 |
| 100 Head Office | 2026-10 | 0 | 69,026 | 0 | 894,000 | 0 | 6,235 | 894,000 |


Oasis PO lines are kept up to and including each branch's first Fusion purchasing month (1,439 lines in the overlap months). Non-PO AP spend is large where AP carries purchases without a PO or bulk loads (Jazan June 33.1M, Unaizah July 22.6M, Abha May 16.4M, Head Office April 97.2M and May 12.9M). The AP match uses Fusion AP only, so Oasis months show 0 matched.


## 6. Month-end stock sources (`gold.fact_stock_monthly`)

| Branch | Source | Rows | First month-end | Last month-end |
|---|---:|---:|---:|---:|
| 1 Al-Rabwa | oasis_batch | 98,428 | 2026-08-31 | 2026-10-31 |
| 2 Khamis | fusion_valuation | 15,327 | 2026-09-30 | 2026-10-31 |
| 2 Khamis | oasis_batch | 20,211 | 2026-08-31 | 2026-08-31 |
| 3 Jazan | fusion_valuation | 33,270 | 2026-07-31 | 2026-10-31 |
| 4 Unaizah | fusion_valuation | 22,797 | 2026-08-31 | 2026-10-31 |
| 5 Madinah | fusion_valuation | 11,648 | 2026-09-30 | 2026-10-31 |
| 5 Madinah | oasis_batch | 10,324 | 2026-08-31 | 2026-08-31 |
| 6 Abha | fusion_valuation | 40,462 | 2026-05-31 | 2026-10-31 |
| 7 Ghirnata | fusion_valuation | 31,030 | 2026-04-30 | 2026-10-31 |
| 8 Muhayil | fusion_valuation | 13,324 | 2026-07-31 | 2026-10-31 |


Only `oasis_batch` and `fusion_valuation` appear today. `snapshot` and `derived` appear only after `default.bal_product_base` is loaded and the next build has run (O-P5-5; `stg_ref__stock_snapshot` has 0 rows now); month-ends before 2026-08-31 for the Oasis-only branches then come from them. Source precedence (lowest rank wins, `argMin`): Fusion valuation (1), snapshot (2), Oasis batch (3), derived (4). Fusion is used for a branch's months from its go-live month, but only when it has valuation layers by that month-end; otherwise the month falls back to the snapshot, then the Oasis batch, then the derived value. Muhayil (8) has no stock source for the May and June 2026 month-ends (O-P5-7: its opening balance is dated after its first sales and its Fusion layers start in July), so those months are empty.

Month-end stock value (`is_expiry_store = 0`), 2026:

| Branch | 2026-04 | 2026-05 | 2026-06 | 2026-07 | 2026-08 | 2026-09 | 2026-10 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 Al-Rabwa |  |  |  |  | 22,109,312 | 21,983,476 | 20,090,706 |
| 2 Khamis |  |  |  |  | 11,978,049 | 9,979,962 | 10,168,005 |
| 3 Jazan |  |  |  | 10,447,884 | 12,263,322 | 12,497,961 | 11,180,191 |
| 4 Unaizah |  |  |  |  | 7,662,143 | 9,214,745 | 9,513,674 |
| 5 Madinah |  |  |  |  | 10,325,176 | 5,988,707 | 6,150,279 |
| 6 Abha |  | 43,508,566 | 419,273,692 | 135,799,108 | 10,061,966 | 10,663,539 | 10,568,099 |
| 7 Ghirnata | 17,306,842 | 18,301,005 | 16,575,051 | 16,835,415 | 17,284,192 | 17,383,376 | 17,325,651 |
| 8 Muhayil |  |  |  | 952,463 | 999,104 | 7,723,577 | 7,791,080 |


2026-10-31 is the open current month (`is_closed_month = 0`). Abha June 2026 (419.3M) and July (135.8M) include the CEFODOX cost.


## 7. Monitors at first build

All eleven supply monitors are `warn` severity (they never fail the run). Row counts from the full build:

| Monitor | Rows | Note |
|---|---:|---|
| `warn_fusion_interface_gap` | 538 | Closed days after go-live with more than 20% of Oasis lines not in Fusion (O-P5-1); no minimum-lines floor |
| `warn_unit_cost_outliers` | 371 | Cost above 20 times the item median, only rows of at least 10,000 SAR, transfers excluded; 22 rows hold almost all the value (CEFODOX and a few 3M to 5M unit costs) |
| `warn_cost_mismatch` | 20 | Branch-months where over 1% of Fusion-sourced rows have a Fusion cost that differs from the Oasis cost (the Fusion pack-cost error) |
| `warn_negative_month_end_stock` | 9 | Month-end stock below zero for a store and item |
| `warn_movements_unknown_item_or_store` | 8 | Movements with item -1 or an unmapped store |
| `warn_po_lines_without_supplier` | 8 | Fusion PO lines without supplier (INCOMPLETE drafts) |
| `warn_future_stock_dates` | 8 | Oasis movement dates after today |
| `warn_valuation_error_layers` | 5 | Valuation layers with `posted_flag` E (they carry real cost and are used) |
| `warn_stock_in_expired_lots` | 1 | Positive stock in an expired lot |
| `warn_opening_balance_after_first_sale` | 1 | Muhayil (branch 8): earliest opening balance dated after its first sale (O-P5-7) |
| `warn_deleted_items_with_movements` | 0 | `Deleted-` items with movements (passes) |


## 8. Known data findings

**Oasis to Fusion interface gap (O-P5-1).** From go-live, 480,846 of the 1,138,778 Oasis lines of the live branches (42%) are not in Fusion yet; the share is 26% to 67% by branch over the last 30 closed days (section 2), and Jazan's monthly coverage fell from 81% in July to 33% in September. Gap lines stay in the fact from Oasis and move to Fusion on a later build without changing date.

**CREDITAR and reversed invoices excluded.** CREDITAR is not a stock line; it credits invoices that were reversed (INVOICEAR with `gl_stk` R). Abha 2026: costed INVOICEAR is 28.74M = 12.51M live + 16.23M reversed (excluded); CREDITAR 2026 is -18.52M, which exceeds the reversed invoices by 2.29M (out of scope; raise with finance). Abha 2026 consumption in the fact is 17.4M against the 28.7M profile figure for that reason. On the Fusion side 209,893 integration transactions that reference reversed invoices (186,529) or CREDITAR (23,364) are dropped, so reversal pairs net as in Oasis; 1,679 other out-of-scope references are kept as Fusion-only lines.

**CEFODOX and the Abha write-off outliers (O-P5-2).** Abha item CEFODOX carries a unit cost of 6,241,137 SAR per bottle (write-off of 2026-06-20: 374.5M SAR; a second write-off on 2026-07-23 at 3,120,583 per unit: 187.2M). Four Abha write-off rows carry Fusion valuation costs of 1.6M to 6.2M SAR per unit. Costs are kept as recorded; `warn_unit_cost_outliers` lists them (371 rows). Other large single unit costs (Madinah 2023 and 2025, Jazan 2025, Unaizah 2022) are Oasis receipts and sales of 3.0M to 5.3M.

**Fusion pack-cost error.** In Khamis, Jazan, Unaizah, Madinah and Muhayil the Fusion valuation cost of a pack item equals the Oasis cost of one base unit (median ratio times units per primary = 1.000; September Fusion over Oasis value for pack items 0.09 to 0.12, all items 0.42 to 0.66, from the Task 6 measurement); Abha and Ghirnata agree with Oasis. cost_amount keeps the Fusion cost as recorded; `oasis_cost_amount` and `is_cost_mismatch` let SSAS show the Oasis cost. 260,133 rows are mismatched in total; in September 2026: Khamis 33,993 of 68,167 Fusion rows, Jazan 19,534 of 38,319, Unaizah 36,038 of 69,753, Madinah 30,616 of 63,722, Abha 1,059, Ghirnata 719, Muhayil 1,245. Until finance fixes the Fusion item costs, Fusion-sourced consumption and margin are understated by about 40% in those five branches. `warn_cost_mismatch` reports it monthly.

**Fusion stock value against Oasis at 2026-09-30.** Fusion month-end value is 17.38M for Ghirnata (section 6) against 6.29M in the Oasis batch snapshot (pack items held in base units but costed per pack: 13.64M against 0.46M), and 7.72M for Muhayil against 1.40M (one cuvette item is 5.78M: 2,410 units at 2,400 SAR). The Oasis-side figures and the pack-item split are from the Task 10 measurement; the Fusion values are re-measured above. Khamis, Unaizah, Madinah and Muhayil stock value is otherwise close to Oasis: pack items are held in base units at base cost, so the pack-cost error hits issue cost, not stock value. Fusion on-hand is split by subinventory only for September; in other months stock sits on the organisation-level `*` store.

**Package billing and margin.** 52.0M SAR of 2026 consumption cost (52,029,593) sits on package-component dispenses whose revenue is on the package header, not on a charge line. Counted against drug revenue it makes Abha's margin -3.12M; on revenue-bearing (`charge`) lines it is +3.97M. Package profitability is a separate analysis.

**Al-Hayat sister hospitals.** Oasis supplier accounts include Al-Hayat National Hospital sister hospitals: in Unaizah (4) 1,044 of 1,917 returns to supplier (-2.35M) go to them, and GRNs from Hayat accounts on branches 1 to 5 total 7,928 lines, 14.2M. These are intra-group flows inside the supplier facts; decide whether to flag them.

**PON-numbered POs and fill rate.** Abha has 11,723 Fusion PO schedules numbered PON (29.8M ordered, fill 0.03, mostly created 2026-05-05). They depress Abha's fill rate: 0.24 with them (re-measured), 0.71 without. Ask what the PON POs are before publishing supplier KPIs. 425 Fusion PO lines without a supplier are INCOMPLETE drafts. 390 Fusion RECEIVE rows have no PO line (internal transfer receipts; `is_po_receipt = 0`); 4 Fusion lines have a negative lead time (null); Oasis has 260 lines with lead times above 365 days.

**Muhayil May and June month-ends.** Muhayil has no stock source for the May and June 2026 month-ends: Fusion valuation starts in July, the opening balance is dated after its first sales (`warn_opening_balance_after_first_sale`, O-P5-7), and `bal_product_base` is not loaded. These months stay empty until the snapshot is loaded.

**Store and item-group drafts (O-P5-4).** `map_store_department` and `map_item_group` are drafts awaiting BI-manager review: 228 of 1,585 Oasis stores are Unmapped, 945 Oasis and 612 Fusion stores have the unified department Not Mapped, and more than 100 of the 228 Unmapped stores are typable by a better rule (O.R., ICU names, ware house, MAINTAINANCE, CHEMO and similar). Improve and reload before relying on department consumption.

**Near-zero Oasis quantities.** 1,926 Oasis lines have quantities of about 1e-38. The guard sets such a primary quantity to 0 with a null unit cost (cost kept as recorded); without it one line produced a -2.24e37 SAR row through the Fusion cost fallback. (Count from the Task 8 measurement.)

**Oasis units against Fusion packs.** `int_item_crosswalk.units_per_primary` is the modal ratio of the Oasis base-unit quantity to the Fusion primary quantity over the product's integration lines (bucketed to an integer or a reciprocal integer): 5,348 of 14,893 crosswalk pairs have a factor above 1 (packs). Quantities are in the item's primary unit; purchase quantities are in the ordering unit.

**Lines posted twice and error layers.** 3,483 Oasis lines are referenced by two or three Fusion transactions (nearly all issue, issue, return in Ghirnata: a double posting and its correction); they are summed into one row with `fusion_transaction_count`. Valuation layers with `posted_flag` E (39,612, nearly all in October) carry real cost and are used; `warn_valuation_error_layers` returns 5 rows. 92,302 layers with zero cost fall back to the Oasis line cost.

**Expiry dates.** Oasis batch expiry dates before 2000-01-01 (325,970 snapshot rows) and Fusion lots from 1930 mean no expiry and are null in the models.
