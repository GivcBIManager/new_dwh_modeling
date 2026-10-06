# Phase 4 reconciliation (workforce)

Run after a successful `dbt build --select tag:hnh`. Figures below are from the full build of 2026-10-06 (`Done. PASS=813 WARN=38 ERROR=0 SKIP=0 TOTAL=851`, about 12.5 minutes) and are measured against the live tables. Amounts are SAR. Months are `yyyymm`; Head Office is branch 100. Branches 1 (Al-Rabwa), 2 (Khamis) and 5 (Madinah) are still paid from Oasis; Jazan (3) moves to Fusion payroll in 202607, Unaizah (4) and Muhayil (8) in 202608, Abha (6) in 202605, Ghirnata (7) and Head Office in 202603.

Row counts of the workforce tables at this build: `fact_headcount_monthly` 43,498; `fact_payroll_monthly` 1,073,480; `fact_worker_movement` 10,592; `fact_absence` 3,658; `fact_absence_daily` 11,526; `fact_leave_balance_monthly` 68,057; `agg_staff_productivity_monthly` 26,630; `dim_employee` 4,788; `bridge_employee_staff` 4,426; `rec_payroll_monthly` 338; `rec_headcount_monthly` 90.

## 1. Payroll against the GL (`gold.rec_payroll_monthly`)

`payroll_cost` (from `fact_payroll_monthly`, parallel-run rows excluded) beside `gl_employee_cost` (DC_EMPLOYEE + GA_EMPLOYEE actual excluding opening-balance journals, unposted included) and `gl_payroll_journal_debit` / `gl_payroll_journal_credit` (Payroll-source journals on income-statement accounts; the credit column shows reversals). Differences are expected where payroll is posted in a later month or through accruals. Branches still paid from Oasis (1, 2, 5) have Oasis payroll and Fusion GL only from their GL go-live, so their GL columns are 0 before it. Branches 3 and 4 show a large GL catch-up in 202608 (24.0M and 17.5M against about 5M of payroll) with matching Payroll-journal debits; branch 2 shows 58.3M of `gl_employee_cost` in 202608 with no Payroll-source journals (the Khamis go-live batch is not categorised as an opening balance, open item O-P3-12). Months to 202609 are listed; 202610 rows exist (the spine runs to the current month) but are all 0.

| Branch | Month | payroll_cost | gross_pay | gl_employee_cost | gl_payroll_journal_debit | gl_payroll_journal_credit |
|---|---|---:|---:|---:|---:|---:|
| 1 | 202601 | 7,908,508 | 7,690,846 | 0 | 0 | 0 |
| 1 | 202602 | 8,204,581 | 7,989,684 | 0 | 0 | 0 |
| 1 | 202603 | 8,508,343 | 8,276,005 | 0 | 0 | 0 |
| 1 | 202604 | 8,923,230 | 8,687,091 | 0 | 0 | 0 |
| 1 | 202605 | 9,038,469 | 8,786,324 | 0 | 0 | 0 |
| 1 | 202606 | 9,394,783 | 9,135,398 | 0 | 0 | 0 |
| 1 | 202607 | 9,241,498 | 8,974,320 | 0 | 0 | 0 |
| 1 | 202608 | 9,244,394 | 8,981,064 | 0 | 0 | 0 |
| 1 | 202609 | 980,499 | 980,499 | 0 | 0 | 0 |
| 2 | 202601 | 5,841,345 | 5,614,219 | 0 | 0 | 0 |
| 2 | 202602 | 5,714,673 | 5,493,114 | 0 | 0 | 0 |
| 2 | 202603 | 5,858,245 | 5,629,838 | 0 | 0 | 0 |
| 2 | 202604 | 5,866,573 | 5,633,699 | 0 | 0 | 0 |
| 2 | 202605 | 5,725,570 | 5,491,471 | 0 | 0 | 0 |
| 2 | 202606 | 6,625,943 | 6,394,022 | 0 | 0 | 0 |
| 2 | 202607 | 6,765,983 | 6,537,071 | 0 | 0 | 0 |
| 2 | 202608 | 5,746,464 | 5,531,015 | 58,298,674 | 0 | 0 |
| 2 | 202609 | 432,463 | 432,463 | 0 | 0 | 0 |
| 3 | 202601 | 5,337,439 | 5,185,930 | 0 | 0 | 0 |
| 3 | 202602 | 5,395,173 | 5,253,020 | 0 | 0 | 0 |
| 3 | 202603 | 5,544,640 | 5,389,530 | 0 | 0 | 0 |
| 3 | 202604 | 5,741,310 | 5,586,382 | 0 | 0 | 0 |
| 3 | 202605 | 5,798,139 | 5,635,862 | 0 | 0 | 0 |
| 3 | 202606 | 6,202,134 | 6,040,390 | 0 | 0 | 0 |
| 3 | 202607 | 6,009,183 | 5,780,225 | 938,023 | 0 | 0 |
| 3 | 202608 | 5,887,107 | 5,664,001 | 23,999,293 | 23,811,903 | 0 |
| 3 | 202609 | 5,957,934 | 5,737,761 | 0 | 0 | 0 |
| 4 | 202601 | 4,976,089 | 4,789,883 | 0 | 0 | 0 |
| 4 | 202602 | 5,096,785 | 4,912,012 | 0 | 0 | 0 |
| 4 | 202603 | 5,102,239 | 4,911,427 | 0 | 0 | 0 |
| 4 | 202604 | 5,280,581 | 5,093,712 | 0 | 0 | 0 |
| 4 | 202605 | 5,119,852 | 4,927,653 | 0 | 0 | 0 |
| 4 | 202606 | 5,206,443 | 5,016,774 | 0 | 0 | 0 |
| 4 | 202607 | 5,248,139 | 5,056,527 | 0 | 0 | 0 |
| 4 | 202608 | 4,964,613 | 4,780,547 | 17,491,861 | 17,494,606 | 0 |
| 4 | 202609 | 5,116,412 | 4,932,814 | 0 | 0 | 0 |
| 5 | 202601 | 4,913,401 | 4,729,018 | 0 | 0 | 0 |
| 5 | 202602 | 4,997,481 | 4,811,334 | 0 | 0 | 0 |
| 5 | 202603 | 5,215,576 | 5,025,281 | 0 | 0 | 0 |
| 5 | 202604 | 5,312,041 | 5,124,443 | 0 | 0 | 0 |
| 5 | 202605 | 5,034,792 | 4,843,879 | 0 | 0 | 0 |
| 5 | 202606 | 5,145,244 | 4,952,875 | 0 | 0 | 0 |
| 5 | 202607 | 5,206,106 | 5,017,328 | 0 | 0 | 0 |
| 5 | 202608 | 5,027,792 | 4,846,346 | 0 | 0 | 0 |
| 5 | 202609 | 228,979 | 228,979 | 0 | 0 | 0 |
| 6 | 202601 | 3,607,374 | 3,372,808 | 0 | 0 | 0 |
| 6 | 202602 | 3,484,965 | 3,245,443 | 0 | 0 | 0 |
| 6 | 202603 | 3,986,332 | 3,702,110 | 0 | 0 | 0 |
| 6 | 202604 | 4,326,256 | 4,040,844 | 0 | 0 | 0 |
| 6 | 202605 | 4,224,916 | 4,091,527 | 6,113,865 | 10,788,691 | 0 |
| 6 | 202606 | 3,967,871 | 3,836,403 | 5,578,726 | 4,846,996 | 72,191 |
| 6 | 202607 | 4,187,004 | 4,047,459 | 5,731,965 | 4,875,006 | 167,214 |
| 6 | 202608 | 4,106,689 | 3,965,300 | 9,612,802 | 4,926,658 | 213 |
| 6 | 202609 | 4,067,950 | 3,926,784 | 0 | 0 | 0 |
| 7 | 202601 | 1,376,076 | 1,252,906 | 2,094,344 | 0 | 0 |
| 7 | 202602 | 1,962,458 | 1,770,675 | 2,657,167 | 0 | 0 |
| 7 | 202603 | 2,715,886 | 2,635,030 | 2,897,350 | 0 | 0 |
| 7 | 202604 | 2,738,419 | 2,654,800 | 9,543,474 | 6,707,397 | 0 |
| 7 | 202605 | 2,847,504 | 2,756,597 | 5,978,444 | 3,309,849 | 927 |
| 7 | 202606 | 3,085,004 | 2,983,966 | 3,518,912 | 3,547,509 | 27,530 |
| 7 | 202607 | 3,014,401 | 2,909,692 | 3,657,325 | 3,718,352 | 61,027 |
| 7 | 202608 | 2,966,396 | 2,862,991 | -373,547 | 3,578,202 | 3,951,544 |
| 7 | 202609 | 2,972,618 | 2,870,438 | 0 | 0 | 0 |
| 8 | 202601 | 1,376,076 | 1,252,906 | 0 | 0 | 0 |
| 8 | 202602 | 1,962,458 | 1,770,675 | 0 | 0 | 0 |
| 8 | 202603 | 2,708,117 | 2,455,829 | 0 | 0 | 0 |
| 8 | 202604 | 2,798,744 | 2,546,537 | 0 | 0 | 0 |
| 8 | 202608 | 1,367,379 | 1,322,165 | 3,424,565 | 3,415,202 | 0 |
| 8 | 202609 | 1,488,215 | 1,438,905 | 0 | 0 | 0 |
| 100 | 202603 | 6,912,709 | 6,662,786 | 0 | 0 | 0 |
| 100 | 202604 | 7,703,100 | 7,435,723 | 19,626,098 | 19,625,253 | 0 |
| 100 | 202605 | 9,498,120 | 9,318,418 | 5,462,047 | 6,234,135 | 771,452 |
| 100 | 202606 | 4,873,874 | 4,717,071 | 5,379,638 | 5,431,194 | 50,955 |
| 100 | 202607 | 5,281,882 | 5,133,879 | 4,848,225 | 5,114,056 | 265,231 |
| 100 | 202608 | 10,110,833 | 9,962,522 | 4,936,071 | 4,991,294 | 54,623 |

## 2. Cutover check

For each parallel-run month, `oasis_parallel_gross_pay` (Oasis rows in or after the branch's cutover month) beside `fusion_gross_pay`. A large gap means the cutover month in `map_payroll_cutover` is wrong. Months where Oasis stops early (202609 for branches 3, 4 and 6: Oasis holds only 356,585, 103,452 and 70,891) show a huge gap that is not a cutover error; the Oasis feed for September is partial (see section 5). Branches 3, 4 and 6 agree within 1.3% in the full parallel months of 202607 and 202608 (branch 6 runs 4.0 to 7.4% higher in Fusion); branch 7 is 1.5 to 7.3% higher in Fusion.

| Branch | Month | oasis_parallel_gross_pay | fusion_gross_pay | Gap (Fusion less Oasis) | Gap % |
|---|---|---:|---:|---:|---:|
| 3 | 202607 | 5,835,060 | 5,780,225 | -54,836 | -0.9% |
| 3 | 202608 | 5,689,251 | 5,664,001 | -25,250 | -0.4% |
| 3 | 202609 | 356,585 | 5,737,761 | 5,381,176 | 1509.1% |
| 4 | 202608 | 4,719,280 | 4,780,547 | 61,267 | 1.3% |
| 4 | 202609 | 103,452 | 4,932,814 | 4,829,362 | 4668.2% |
| 6 | 202605 | 3,809,713 | 4,091,527 | 281,814 | 7.4% |
| 6 | 202606 | 3,690,035 | 3,836,403 | 146,367 | 4.0% |
| 6 | 202607 | 3,867,425 | 4,047,459 | 180,034 | 4.7% |
| 6 | 202608 | 3,789,469 | 3,965,300 | 175,831 | 4.6% |
| 6 | 202609 | 70,891 | 3,926,784 | 3,855,893 | 5439.2% |
| 7 | 202603 | 2,455,829 | 2,635,030 | 179,200 | 7.3% |
| 7 | 202604 | 2,546,537 | 2,654,800 | 108,263 | 4.3% |
| 7 | 202605 | 2,708,670 | 2,756,597 | 47,927 | 1.8% |
| 7 | 202606 | 2,782,388 | 2,983,966 | 201,578 | 7.2% |
| 7 | 202607 | 2,857,498 | 2,909,692 | 52,194 | 1.8% |
| 7 | 202608 | 2,821,610 | 2,862,991 | 41,381 | 1.5% |

## 3. Headcount (`gold.rec_headcount_monthly`)

`fusion_headcount` and `fusion_fte` (non-contingent, month-end snapshot) beside paid headcount (distinct `payee_key` with positive Basic pay) from Oasis and from Fusion. Paid headcount is of the payroll month, so it can differ from the month-end snapshot by leavers, joiners and unpaid leave; before a branch's cutover the Fusion column is 0, in the parallel-run months the Oasis column keeps counting the Oasis rows, so the two sources sit side by side. 202609 Oasis paid headcount is partial for branches 1 to 6 (see section 5). The 2026-10-31 rows are the projected current month-end (`is_closed_month = 0`) and are left out below. Branch 8 paid headcount in 202601 to 202604 equals branch 7 (`warn_branch8_payroll_copies_branch7`, O-P4-3).

| Branch | Month-end | fusion_headcount | fusion_fte | oasis_paid_headcount | fusion_paid_headcount |
|---|---|---:|---:|---:|---:|
| 1 | 2026-01-31 | 917 | 917.0 | 912 | 0 |
| 1 | 2026-02-28 | 919 | 919.0 | 967 | 0 |
| 1 | 2026-03-31 | 944 | 944.0 | 945 | 0 |
| 1 | 2026-04-30 | 968 | 968.0 | 956 | 0 |
| 1 | 2026-05-31 | 974 | 974.0 | 959 | 0 |
| 1 | 2026-06-30 | 986 | 986.0 | 979 | 0 |
| 1 | 2026-07-31 | 993 | 993.0 | 966 | 0 |
| 1 | 2026-08-31 | 994 | 994.0 | 949 | 0 |
| 1 | 2026-09-30 | 989 | 989.0 | 59 | 0 |
| 2 | 2026-01-31 | 490 | 490.0 | 606 | 0 |
| 2 | 2026-02-28 | 516 | 516.0 | 597 | 0 |
| 2 | 2026-03-31 | 532 | 532.0 | 619 | 0 |
| 2 | 2026-04-30 | 548 | 548.0 | 639 | 0 |
| 2 | 2026-05-31 | 561 | 561.0 | 657 | 0 |
| 2 | 2026-06-30 | 589 | 589.0 | 670 | 0 |
| 2 | 2026-07-31 | 601 | 601.0 | 665 | 0 |
| 2 | 2026-08-31 | 601 | 601.0 | 628 | 0 |
| 2 | 2026-09-30 | 603 | 603.0 | 34 | 0 |
| 3 | 2026-01-31 | 607 | 607.0 | 618 | 0 |
| 3 | 2026-02-28 | 625 | 625.0 | 629 | 0 |
| 3 | 2026-03-31 | 657 | 657.0 | 646 | 0 |
| 3 | 2026-04-30 | 681 | 681.0 | 665 | 0 |
| 3 | 2026-05-31 | 700 | 700.0 | 682 | 0 |
| 3 | 2026-06-30 | 711 | 711.0 | 698 | 0 |
| 3 | 2026-07-31 | 715 | 715.0 | 708 | 707 |
| 3 | 2026-08-31 | 706 | 706.0 | 693 | 700 |
| 3 | 2026-09-30 | 696 | 696.0 | 19 | 693 |
| 4 | 2026-01-31 | 540 | 540.0 | 543 | 0 |
| 4 | 2026-02-28 | 558 | 558.0 | 538 | 0 |
| 4 | 2026-03-31 | 576 | 576.0 | 557 | 0 |
| 4 | 2026-04-30 | 588 | 588.0 | 550 | 0 |
| 4 | 2026-05-31 | 594 | 594.0 | 573 | 0 |
| 4 | 2026-06-30 | 603 | 603.0 | 574 | 0 |
| 4 | 2026-07-31 | 611 | 611.0 | 582 | 0 |
| 4 | 2026-08-31 | 614 | 614.0 | 554 | 561 |
| 4 | 2026-09-30 | 583 | 583.0 | 8 | 563 |
| 5 | 2026-01-31 | 469 | 469.0 | 525 | 0 |
| 5 | 2026-02-28 | 477 | 477.0 | 530 | 0 |
| 5 | 2026-03-31 | 486 | 486.0 | 526 | 0 |
| 5 | 2026-04-30 | 505 | 505.0 | 534 | 0 |
| 5 | 2026-05-31 | 509 | 509.0 | 549 | 0 |
| 5 | 2026-06-30 | 512 | 512.0 | 547 | 0 |
| 5 | 2026-07-31 | 514 | 514.0 | 540 | 0 |
| 5 | 2026-08-31 | 527 | 527.0 | 524 | 0 |
| 5 | 2026-09-30 | 528 | 528.0 | 19 | 0 |
| 6 | 2026-01-31 | 369 | 369.0 | 345 | 0 |
| 6 | 2026-02-28 | 392 | 392.0 | 345 | 0 |
| 6 | 2026-03-31 | 417 | 417.0 | 376 | 0 |
| 6 | 2026-04-30 | 429 | 429.0 | 398 | 0 |
| 6 | 2026-05-31 | 426 | 426.0 | 399 | 415 |
| 6 | 2026-06-30 | 433 | 433.0 | 402 | 420 |
| 6 | 2026-07-31 | 444 | 444.0 | 426 | 438 |
| 6 | 2026-08-31 | 430 | 430.0 | 416 | 433 |
| 6 | 2026-09-30 | 415 | 415.0 | 5 | 415 |
| 7 | 2026-01-31 | 205 | 205.0 | 139 | 0 |
| 7 | 2026-02-28 | 245 | 245.0 | 186 | 0 |
| 7 | 2026-03-31 | 259 | 259.0 | 234 | 255 |
| 7 | 2026-04-30 | 278 | 278.0 | 247 | 263 |
| 7 | 2026-05-31 | 299 | 299.0 | 270 | 279 |
| 7 | 2026-06-30 | 311 | 311.0 | 284 | 302 |
| 7 | 2026-07-31 | 309 | 309.0 | 293 | 305 |
| 7 | 2026-08-31 | 307 | 307.0 | 290 | 295 |
| 7 | 2026-09-30 | 303 | 303.0 | 0 | 289 |
| 8 | 2026-01-31 | 52 | 52.0 | 139 | 0 |
| 8 | 2026-02-28 | 56 | 56.0 | 186 | 0 |
| 8 | 2026-03-31 | 61 | 61.0 | 234 | 0 |
| 8 | 2026-04-30 | 67 | 67.0 | 247 | 0 |
| 8 | 2026-05-31 | 73 | 73.0 | 0 | 0 |
| 8 | 2026-06-30 | 95 | 95.0 | 0 | 0 |
| 8 | 2026-07-31 | 112 | 112.0 | 0 | 0 |
| 8 | 2026-08-31 | 138 | 138.0 | 0 | 131 |
| 8 | 2026-09-30 | 149 | 149.0 | 0 | 146 |
| 100 | 2026-01-31 | 128 | 128.0 | 0 | 0 |
| 100 | 2026-02-28 | 133 | 133.0 | 0 | 0 |
| 100 | 2026-03-31 | 140 | 140.0 | 0 | 141 |
| 100 | 2026-04-30 | 147 | 146.0 | 0 | 148 |
| 100 | 2026-05-31 | 145 | 144.0 | 0 | 150 |
| 100 | 2026-06-30 | 144 | 143.0 | 0 | 146 |
| 100 | 2026-07-31 | 144 | 143.0 | 0 | 150 |
| 100 | 2026-08-31 | 138 | 137.0 | 0 | 148 |
| 100 | 2026-09-30 | 138 | 137.0 | 0 | 141 |
## 4. Monitors at first build

Seven Task 9 monitors and two Task 8 monitors (the `assert_` names carry `severity: warn`). A PASS means 0 rows.

| Monitor | Rows | Note |
|---|---|---|
| warn_unmapped_pay_codes | 0 | Every paid code or element has a pay category |
| warn_employees_without_staff_link | 5 | Branch rows: 39 current hospital employees with no Oasis staff match (branch 1: 22, branch 4: 14, branches 3, 5, 7: 1 each) |
| warn_staff_linked_to_many_employees | 3 | Staff records shared by two employees (rehires or reused worker numbers) |
| warn_branch8_payroll_copies_branch7 | 4 | 202601 to 202604: branch 8 Oasis payroll equals branch 7 in payees and amount (O-P4-3) |
| warn_fte_out_of_range | 1 | 1,626 FTE work measures are 0 (replaced by 1 in the snapshot) |
| warn_absence_zero_days | 0 | No counted day-unit absence with zero days |
| warn_leave_without_salary | 8 | One row per branch: current annual-leave balances with no salary (51 on branch 4, 22 on branch 7, 20 on branch 8, 19 on Head Office, 14, 12, 8 and 5 on the others); liability null |
| assert_absence_daily_no_overlap (Task 8) | 1 | One employee-day with two counted absence rows (overlapping source entries) |
| assert_leave_balance_single_entry_per_period (Task 8) | 36 | Employee, plan and period combinations with two balance entries (parallel enrolments); the flags tie-break to the highest `accrual_entry_id` |

The hard workforce tests (`assert_workforce_facts_have_branch`, `assert_payroll_single_source_per_month` and the conservation tests) passed (ERROR=0).

## 5. Known data findings

These are source or extract facts the model reports honestly; none is a model error.

- **September 2026 repeated regular runs.** Fusion extract holds several full regular runs of the same month that were not rolled back (Jazan: actions 146197, 148235 and 150222, each about 690 people and 4.9M of basic). The rerun rule (latest regular action per person, element, legal employer and month, plus all QuickPay) removes, in Pay Value raw SAR (rows, people): 202603 0.03M (91, 13); 202607 under 0.01M (234, 234); 202608 under 0.01M (5, 3); 202609 89.36M (37,054, 1,936), of which 36.22M is Basic Salary. Without the rule September gross pay is about three times normal.
- **202603 differing regular runs.** 91 person-element groups have two regular runs with different values (action 33032 against 61320); the older value (about 26k SAR) is dropped and may be arrears.
- **Head Office end-of-service settlements.** Head Office payroll swings month to month because of end-of-service payments: 5.45M SAR for 7 people in 202608 (375,796 in 202607), not reruns.
- **Branch 8 has no payroll in 202605 to 202607.** Oasis stops after 202604 and Fusion starts at the 202608 cutover; the source has no rows for the three months.
- **Oasis 202609 is partial.** Oasis gross pay for 202609 is 980,499 for branch 1, 432,463 for branch 2 and 228,979 for branch 5 (about 9M a month before); branches 3, 4 and 6 hold only the parallel remainder.
- **Branch 1 Fusion absence balances stop after 2026-08.** About 799 people carry weekly balances from 202603 to 202608 and only 4 in 202609. `is_current_balance` therefore shows their August balance (7.15M SAR of liability on branch 1, 25.06K days). This is an extract gap.
- **Stale current balances of terminated employees.** 328 current balance rows of 219 terminated employees carry 3,254 days and 0.90M SAR of liability; they should be excluded in HR reporting if the employee is closed.
- **Future-dated movements and absence days.** 53 worker movements have an action date after today (up to 2027-12-30, 6 of them leavers) and 4,375 of the 11,526 `fact_absence_daily` rows are dated after today (up to 2027-02-23): planned leave. Year-to-date and trend measures must filter by date.
- **Paid headcount counts Basic above zero, the spec says gross pay.** `rec_headcount_monthly` follows the brief (Basic above zero). Counting people with any gross pay row gives 0 to 6 more people per branch-month (more in 33 of 76 branch-months, largest: branch 1 202609 with 65 against 59).
- **Payroll-source GL reversals.** `gl_payroll_journal_credit` shows reversals of Payroll-source journals, notably branch 7 202608 (3.95M credit against 3.58M debit, so `gl_employee_cost` is negative, -373,547).
- **21 CON contractors on branch 0 in `dim_employee` only.** They have no period of service, assignment or legal employer, so they never appear in a fact (fact tests reject branch 0).
- **Negative leave liabilities are kept.** 192 balance rows (11 current) are overdrawn (-530,514 SAR in total, -10,305 for the current ones); the current liability total is 25.55M SAR over 79,276 days.

## 6. Measurements for the hand-off

Latest closed month-end 2026-09-30, non-contingent. Headcount and FTE by branch (FTE equals headcount for every branch except Head Office, 137.0 for 138): branch 1 989, 2 603, 3 696, 4 583, 5 528, 6 415, 7 303, 8 149, 100 138; total 4,404 (FTE 4,403). Saudisation: 1 30.5%, 2 32.7%, 3 30.7%, 4 33.8%, 5 32.4%, 6 29.9%, 7 31.0%, 8 26.8%, Head Office 41.3%, total 31.7% (1,396 of 4,404).

Hires and leavers per month 2026 (month-end snapshot flags, non-contingent; leavers count only people active at a month-end): 202601 123 / 0, 202602 148 / 0, 202603 160 / 5, 202604 159 / 2, 202605 88 / 2, 202606 147 / 5, 202607 111 / 4, 202608 97 / 6, 202609 36 / 2.

Leave liability at the current balance (`is_current_balance = 1`), days and SAR: branch 1 25,060 / 7,147,818; 2 18 / 3,652; 3 21,839 / 6,362,024; 4 13,456 / 3,858,213; 6 8,832 / 2,738,550; 7 5,391 / 1,754,526; 8 1,166 / 385,365; Head Office 3,513 / 3,295,694. Branch 5 (Madinah) has no Fusion balances yet.

Gross pay by branch and month and source is in the `gross_pay` column of section 1 (source `oasis` before each cutover month, `fusion` from it).
