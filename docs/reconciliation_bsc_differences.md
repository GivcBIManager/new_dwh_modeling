# bsc views: old server against new (generated)

Generated 2026-10-12 16:40 by scripts/compare_bsc.ps1. Months: 2026-08-01, 2026-09-01 and the year 2025. Tolerance: 0.5% relative (absolute below 1). Attribution: docs/reconciliation_bsc.md.

## vw_customer

Keys (branch_id, period): old 89, new 112. Differences: 1417.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 4|2026-08-01 | non_moh_revenue | 9574878.15 | 9696816.12 | differs |
| 4|2026-08-01 | insurance_revenue | 7322431.09 | 7466821.12 | differs |
| 4|2026-08-01 | referrals_revenue | 1012342.35 | 998621.32 | differs |
| 4|2026-08-01 | new_op_census | 1716 | 1729 | differs |
| 4|2026-08-01 | op_episodes | 10063 | 9866 | differs |
| 4|2026-08-01 | er_census | 1771 | 1730 | differs |
| 4|2026-08-01 | available_slots | 25384 | 24794 | differs |
| 4|2026-08-01 | op_waiting_time_in_minutes | 358569 | 355644 | differs |
| 4|2026-08-01 | admissions | 605 | 681 | differs |
| 4|2026-08-01 | readmission_within_30days | 36 | 35 | differs |
| 4|2026-08-01 | readmitted_to_ICU_with_48hrs | 0 | 3 | differs |
| 4|2026-08-01 | insurance_admissions | 394 | 411 | differs |
| 4|2026-08-01 | discharges | 616 | 694 | differs |
| 4|2026-08-01 | icu_discharge | 78 | 79 | differs |
| 4|2026-08-01 | alos_non_ltc | 2.72140120415983 | 2.64222161572052 | differs |
| 5|2026-08-01 | non_moh_revenue | 13366494.58 | 13520180.52 | differs |
| 5|2026-08-01 | insurance_revenue | 10442116.91 | 10861698.87 | differs |
| 5|2026-08-01 | referrals_revenue | 671967.97 | 666465.65 | differs |
| 5|2026-08-01 | credit_revenue | 16193291.55 | 16548204.84 | differs |
| 5|2026-08-01 | op_episodes | 7308 | 7219 | differs |
| 5|2026-08-01 | referrals_volume | 250 | 245 | differs |
| 5|2026-08-01 | available_slots | 22518 | 23842 | differs |
| 5|2026-08-01 | op_waiting_time_in_minutes | 235713 | 230560 | differs |
| 5|2026-08-01 | admissions | 823 | 940 | differs |
| 5|2026-08-01 | readmission_within_30days | 64 | 70 | differs |
| 5|2026-08-01 | discharges | 841 | 957 | differs |
| 5|2026-08-01 | icu_discharge | 130 | 128 | differs |
| 5|2026-08-01 | alos_non_ltc | 2.43008385744235 | 2.31335147578973 | differs |
| 5|2025-08-01 | insurance_revenue | 7481557.11 | 7625253.64 | differs |
| 5|2025-08-01 | referrals_revenue | 1008057.11 | 1101738.44 | differs |
| 5|2025-08-01 | credit_revenue | 14304338.12 | 14457799.9 | differs |
| 5|2025-08-01 | op_episodes | 6994 | 6741 | differs |
| 5|2025-08-01 | er_census | 1354 | 1368 | differs |
| 5|2025-08-01 | available_slots | 20362 | 21010 | differs |
| 5|2025-08-01 | op_waiting_time_in_minutes | 311740 | 306252 | differs |
| 5|2025-08-01 | admissions | 647 | 748 | differs |
| 5|2025-08-01 | readmission_within_30days | 54 | 57 | differs |
| 5|2025-08-01 | readmitted_to_ICU_with_48hrs | 0 | 1 | differs |
| 5|2025-08-01 | discharges | 615 | 716 | differs |
| 5|2025-08-01 | icu_discharge | 83 | 81 | differs |
| 5|2025-08-01 | alos_non_ltc | 2.85178376906318 | 2.67056062022752 | differs |
| 6|2025-12-01 | non_ltc_ip_revenue | 7851341.55 | 7897033.34 | differs |
| 6|2025-12-01 | insurance_revenue | 2186224.82 | 2239312.33 | differs |
| 6|2025-12-01 | referrals_revenue | 802541.07 | 837447.73 | differs |
| 6|2025-12-01 | high_value_service_revenue | 2607133.04 | 2144027.42 | differs |
| 6|2025-12-01 | high_value_service_volume | 698 | 677 | differs |
| 6|2025-12-01 | er_census | 599 | 589 | differs |
| 6|2025-12-01 | available_slots | 16584 | 16716 | differs |
| 6|2025-12-01 | admissions | 379 | 399 | differs |
| 6|2025-12-01 | readmission_within_30days | 15 | 16 | differs |
| 6|2025-12-01 | readmitted_to_ICU_with_48hrs | 0 | 3 | differs |
| 6|2025-12-01 | discharges | 344 | 364 | differs |
| 6|2025-12-01 | icu_discharge | 127 | 132 | differs |
| 6|2025-12-01 | alos_non_ltc | 5.64956940222897 | 5.43193847500796 | differs |
| 7|2025-12-01 | census | 3 | 0 | differs |
| 7|2025-12-01 | op_census | 3 | 0 | differs |
| 7|2025-12-01 | distinct_patients | 3 | 0 | differs |
| 7|2025-12-01 | new_op_census | 2 | 0 | differs |
| 7|2025-12-01 | op_episodes | 3 | 0 | differs |
| 7|2025-12-01 | available_slots | 76 | 0 | differs |
| 7|2025-12-01 | op_waiting_time_in_minutes | 42 | 0 | differs |
| 3|2025-04-01 | revenue | 23967573.59 | 24094062.77 | differs |
| 3|2025-04-01 | non_ltc_ip_revenue | 10703389.99 | 10813812.69 | differs |
| 3|2025-04-01 | non_moh_revenue | 10647297.17 | 10704788.86 | differs |
| 3|2025-04-01 | insurance_revenue | 6543455.2 | 6601418.35 | differs |
| 3|2025-04-01 | referrals_revenue | 1145325.37 | 1158656.92 | differs |
| 3|2025-04-01 | credit_revenue | 20175813.01 | 20291010.89 | differs |
| 3|2025-04-01 | high_value_service_revenue | 1819530.22 | 1834168.82 | differs |
| 3|2025-04-01 | op_episodes | 9981 | 9781 | differs |
| 3|2025-04-01 | er_census | 1734 | 1723 | differs |
| 3|2025-04-01 | available_slots | 23244 | 23426 | differs |
| 3|2025-04-01 | op_waiting_time_in_minutes | 396935 | 334773 | differs |
| 3|2025-04-01 | admissions | 974 | 1103 | differs |
| 3|2025-04-01 | readmission_within_30days | 58 | 64 | differs |
| 3|2025-04-01 | readmitted_to_ICU_with_48hrs | 0 | 1 | differs |
| 3|2025-04-01 | insurance_admissions | 411 | 442 | differs |
| 3|2025-04-01 | discharges | 939 | 1065 | differs |
| 3|2025-04-01 | icu_discharge | 47 | 197 | differs |
| 3|2025-04-01 | alos_non_ltc | 2.48361170977011 | 2.36236493253215 | differs |
| 1|2025-04-01 | non_ltc_ip_revenue | 5827051.28 | 5937011.5 | differs |
| 1|2025-04-01 | non_moh_revenue | 10745645.71 | 10921764.97 | differs |
| 1|2025-04-01 | insurance_revenue | 7600684.12 | 7697538.63 | differs |
| 1|2025-04-01 | high_value_service_revenue | 2713041.12 | 2744576.97 | differs |
| 1|2025-04-01 | census | 15499 | 15336 | differs |
| 1|2025-04-01 | insurance_census | 12338 | 12214 | differs |
| 1|2025-04-01 | op_census | 13862 | 13755 | differs |
| 1|2025-04-01 | new_op_census | 1841 | 1827 | differs |
| 1|2025-04-01 | op_episodes | 10817 | 10476 | differs |
| 1|2025-04-01 | er_census | 1637 | 1581 | differs |
| 1|2025-04-01 | available_slots | 25384 | 26722 | differs |
| 1|2025-04-01 | op_waiting_time_in_minutes | 279455 | 277829 | differs |
| 1|2025-04-01 | admissions | 536 | 571 | differs |
| 1|2025-04-01 | readmission_within_30days | 63 | 66 | differs |
| 1|2025-04-01 | insurance_admissions | 390 | 408 | differs |
| 1|2025-04-01 | discharges | 526 | 561 | differs |
| 1|2025-04-01 | icu_discharge | 26 | 25 | differs |
| 1|2025-04-01 | alos_non_ltc | 2.40034448818898 | 2.38608804838048 | differs |
| 2|2025-06-01 | non_moh_revenue | 11312388.2 | 11060179.03 | differs |
| 2|2025-06-01 | insurance_revenue | 7270677.78 | 7401788.91 | differs |
| 2|2025-06-01 | referrals_revenue | 2168690.91 | 2255004.58 | differs |
| 2|2025-06-01 | credit_revenue | 22041769.83 | 22389678.48 | differs |
| 2|2025-06-01 | high_value_service_volume | 1463 | 316 | differs |
| 2|2025-06-01 | census | 13697 | 3658 | differs |
| 2|2025-06-01 | insurance_census | 7820 | 1922 | differs |
| 2|2025-06-01 | op_census | 11774 | 1733 | differs |
| 2|2025-06-01 | distinct_patients | 8073 | 3159 | differs |
| 2|2025-06-01 | returning_patients | 3633 | 1095 | differs |
| 2|2025-06-01 | new_op_census | 1808 | 252 | differs |
| 2|2025-06-01 | op_episodes | 9428 | 1365 | differs |
| 2|2025-06-01 | referrals_volume | 1147 | 377 | differs |
| 2|2025-06-01 | available_slots | 26314 | 4630 | differs |
| 2|2025-06-01 | op_waiting_time_in_minutes | 214408 | 36078 | differs |
| 2|2025-06-01 | admissions | 655 | 706 | differs |
| 2|2025-06-01 | readmission_within_30days | 36 | 41 | differs |
| 2|2025-06-01 | readmitted_to_ICU_with_48hrs | 0 | 3 | differs |
| 2|2025-06-01 | insurance_admissions | 400 | 411 | differs |
| 2|2025-06-01 | discharges | 610 | 661 | differs |
| 2|2025-06-01 | icu_discharge | 57 | 62 | differs |
| 2|2025-06-01 | alos_non_ltc | 2.92680555555556 | 2.83540279911248 | differs |
| 4|2025-12-01 | non_moh_revenue | 9704344.32 | 9758453.41 | differs |
| 4|2025-12-01 | insurance_revenue | 7648095.71 | 7752731.53 | differs |
| 4|2025-12-01 | referrals_revenue | 1208892.12 | 1217380.2 | differs |
| 4|2025-12-01 | high_value_service_revenue | 2080852.05 | 2100982.21 | differs |
| 4|2025-12-01 | op_episodes | 10305 | 10162 | differs |
| 4|2025-12-01 | er_census | 1107 | 1079 | differs |
| 4|2025-12-01 | available_slots | 27932 | 27744 | differs |
| 4|2025-12-01 | op_waiting_time_in_minutes | 285969 | 279700 | differs |
| 4|2025-12-01 | admissions | 693 | 757 | differs |
| 4|2025-12-01 | readmission_within_30days | 43 | 40 | differs |
| 4|2025-12-01 | readmitted_to_ICU_with_48hrs | 0 | 1 | differs |
| 4|2025-12-01 | insurance_admissions | 479 | 500 | differs |
| 4|2025-12-01 | discharges | 684 | 746 | differs |
| 4|2025-12-01 | icu_discharge | 92 | 93 | differs |
| 4|2025-12-01 | alos_non_ltc | 2.44821162444113 | 2.40418561467334 | differs |
| 7|2026-08-01 | non_moh_revenue | 2478895.7 | 2545789.16 | differs |
| 7|2026-08-01 | insurance_revenue | 1250208.48 | 1349752.96 | differs |
| 7|2026-08-01 | credit_revenue | 2752186.58 | 2786510.29 | differs |
| 7|2026-08-01 | insurance_census | 2235 | 2223 | differs |
| 7|2026-08-01 | returning_patients | 626 | 274 | differs |
| 7|2026-08-01 | new_op_census | 1636 | 1646 | differs |
| 7|2026-08-01 | op_episodes | 2555 | 2455 | differs |
| 7|2026-08-01 | er_census | 617 | 603 | differs |
| 7|2026-08-01 | available_slots | 18960 | 17834 | differs |
| 7|2026-08-01 | op_waiting_time_in_minutes | 116254 | 111375 | differs |
| 7|2026-08-01 | admissions | 293 | 316 | differs |
| 7|2026-08-01 | readmission_within_30days | 15 | 16 | differs |
| 7|2026-08-01 | insurance_admissions | 58 | 63 | differs |
| 7|2026-08-01 | discharges | 289 | 311 | differs |
| 7|2026-08-01 | icu_discharge | 18 | 45 | differs |
| 7|2026-08-01 | alos_non_ltc | 1.65657698056801 | 1.6946309687787 | differs |
| 6|2025-04-01 | revenue | 5855457.8 | 5887871.42 | differs |
| 6|2025-04-01 | non_ltc_ip_revenue | 2214382.48 | 2245837.1 | differs |
| 6|2025-04-01 | non_moh_revenue | 806075.79 | 847311.23 | differs |
| 6|2025-04-01 | high_value_service_revenue | 449649.1 | 458810.1 | differs |
| 6|2025-04-01 | census | 1064 | 1052 | differs |
| 6|2025-04-01 | insurance_census | 18 | 17 | differs |
| 6|2025-04-01 | returning_patients | 120 | 119 | differs |
| 6|2025-04-01 | er_census | 418 | 406 | differs |
| 6|2025-04-01 | admissions | 131 | 141 | differs |
| 6|2025-04-01 | discharges | 137 | 147 | differs |
| 6|2025-04-01 | alos_non_ltc | 5.50081699346405 | 5.28523685515873 | differs |
| 3|2025-12-01 | non_ltc_ip_revenue | 15334515.34 | 15490898.65 | differs |
| 3|2025-12-01 | non_moh_revenue | 13851155.09 | 13968321.16 | differs |
| 3|2025-12-01 | insurance_revenue | 9627022.9 | 9703673.55 | differs |
| 3|2025-12-01 | op_episodes | 11080 | 10738 | differs |
| 3|2025-12-01 | er_census | 2051 | 2024 | differs |
| 3|2025-12-01 | referrals_volume | 1375 | 1382 | differs |
| 3|2025-12-01 | op_waiting_time_in_minutes | 502687 | 471673 | differs |
| 3|2025-12-01 | admissions | 1049 | 1189 | differs |
| 3|2025-12-01 | readmission_within_30days | 70 | 77 | differs |
| 3|2025-12-01 | readmitted_to_ICU_with_48hrs | 0 | 2 | differs |
| 3|2025-12-01 | insurance_admissions | 542 | 579 | differs |
| 3|2025-12-01 | discharges | 1031 | 1179 | differs |
| 3|2025-12-01 | icu_discharge | 107 | 297 | differs |
| 3|2025-12-01 | alos_non_ltc | 3.00119165023011 | 2.81357871964047 | differs |
| 5|2025-06-01 | non_ltc_ip_revenue | 7132554.39 | 7183245.42 | differs |
| 5|2025-06-01 | non_moh_revenue | 6977155.12 | 6612750.69 | differs |
| 5|2025-06-01 | insurance_revenue | 4357656.02 | 4457353.1 | differs |
| 5|2025-06-01 | referrals_revenue | 439604.01 | 529133.91 | differs |
| 5|2025-06-01 | credit_revenue | 13902564.78 | 14389963.54 | differs |
| 5|2025-06-01 | high_value_service_revenue | 1258659.37 | 1283864.83 | differs |
| 5|2025-06-01 | op_episodes | 6220 | 6049 | differs |
| 5|2025-06-01 | available_slots | 17248 | 17936 | differs |
| 5|2025-06-01 | admissions | 537 | 643 | differs |
| 5|2025-06-01 | readmission_within_30days | 40 | 42 | differs |
| 5|2025-06-01 | readmitted_to_ICU_with_48hrs | 4 | 3 | differs |
| 5|2025-06-01 | discharges | 532 | 641 | differs |
| 5|2025-06-01 | icu_discharge | 81 | 84 | differs |
| 5|2025-06-01 | alos_non_ltc | 2.39456106870229 | 2.23133776549061 | differs |
| 1|2025-12-01 | non_ltc_ip_revenue | 7640610.46 | 7731527.57 | differs |
| 1|2025-12-01 | insurance_revenue | 10898709.42 | 11068258.28 | differs |
| 1|2025-12-01 | credit_revenue | 27038237.01 | 27348561.75 | differs |
| 1|2025-12-01 | census | 19731 | 19504 | differs |
| 1|2025-12-01 | insurance_census | 16477 | 16291 | differs |
| 1|2025-12-01 | op_census | 17933 | 17815 | differs |
| 1|2025-12-01 | new_op_census | 2350 | 2336 | differs |
| 1|2025-12-01 | op_episodes | 13646 | 13241 | differs |
| 1|2025-12-01 | er_census | 1798 | 1689 | differs |
| 1|2025-12-01 | referrals_volume | 191 | 190 | differs |
| 1|2025-12-01 | available_slots | 30802 | 33334 | differs |
| ... | 1217 more | | | |

## vw_financial

Keys (branch_id, month_date): old 85, new 88. Differences: 460.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 1|2026-09-01 | consumables_actual | 0 | -69912.74 | differs |
| 1|2026-09-01 | assets | 330670549.7 | 550863259.69 | differs |
| 1|2026-09-01 | assets_opening_balance | 338376255.4 | 563424258.86 | differs |
| 6|2025-11-01 | ebitda_actual | 3694519.889 | 3744455.89 | differs |
| 6|2025-11-01 | account_receivable_actual | 10024113.3 | 80948069.42 | differs |
| 6|2025-11-01 | account_receivable_actual_opening_balance | 3989343.29 | 70923956.12 | differs |
| 6|2025-11-01 | consumables_actual | 1038497.52 | 2451848.19 | differs |
| 6|2025-11-01 | assets | 6345263.29 | 89663833.76 | differs |
| 6|2025-11-01 | assets_opening_balance | 1349294.68 | 83318570.47 | differs |
| 4|2026-09-01 | net_revenue_actual | 2911534.58 | 0 | differs |
| 4|2026-09-01 | sub_revenue_actual | 2911534.58 | 0 | differs |
| 4|2026-09-01 | operating_expenses | 0 | 275756.1 | differs |
| 4|2026-09-01 | ebitda_actual | 2911534.58 | -275756.1 | differs |
| 4|2026-09-01 | account_receivable_actual | 181934872.5 | 168126058.8 | differs |
| 4|2026-09-01 | account_receivable_actual_opening_balance | 181980569.69 | 168123058.8 | differs |
| 4|2026-09-01 | ga_expenses_actual | 0 | 9638.39 | differs |
| 4|2026-09-01 | assets | 187732761.73 | 301383990.27 | differs |
| 4|2026-09-01 | assets_opening_balance | 192142881.943 | 301767538.98 | differs |
| 4|2026-09-01 | income | 2911534.58 | -275861.9 | differs |
| 3|2025-11-01 | operating_expenses | 16424789.42 | 16209267.42 | differs |
| 3|2025-11-01 | ebitda_actual | 11511075.85 | 11726597.85 | differs |
| 3|2025-11-01 | account_receivable_actual | 18999074.86 | 186411121.37 | differs |
| 3|2025-11-01 | account_receivable_actual_opening_balance | -7259357.17 | 167412046.51 | differs |
| 3|2025-11-01 | consumables_actual | 1573826.52 | 3401898.15 | differs |
| 3|2025-11-01 | assets | 19080659.38 | 565147561.31 | differs |
| 3|2025-11-01 | assets_opening_balance | 13315429.41 | 546066901.93 | differs |
| 1|2025-07-01 | ebitda_actual | 5893888.67 | 5940053.67 | differs |
| 1|2025-07-01 | account_receivable_actual | 12182234.5 | 153322891.14 | differs |
| 1|2025-07-01 | account_receivable_actual_opening_balance | 11980457.3 | 141140656.64 | differs |
| 1|2025-07-01 | consumables_actual | 1938666.39 | 4589553.96 | differs |
| 1|2025-07-01 | assets | -5776466.99 | 496326585.3 | differs |
| 1|2025-07-01 | assets_opening_balance | 2588151.45 | 502103052.29 | differs |
| 4|2025-07-01 | account_receivable_actual | 6780213.4 | 83670524.2 | differs |
| 4|2025-07-01 | account_receivable_actual_opening_balance | -2264435.24 | 76890310.8 | differs |
| 4|2025-07-01 | consumables_actual | 874919.7 | 1967232.25 | differs |
| 4|2025-07-01 | assets | 3901345.77 | 199380538.12 | differs |
| 4|2025-07-01 | assets_opening_balance | 1792801.52 | 195479192.35 | differs |
| 5|2025-04-01 | consumables_actual | 501034.91 | 1578882.87 | differs |
| 5|2025-04-01 | assets | -56324694.736 | 103637028.93 | differs |
| 5|2025-04-01 | assets_opening_balance | -55629984.196 | 104331739.47 | differs |
| 5|2025-10-01 | consumables_actual | 1040966.15 | 2131876.81 | differs |
| 5|2025-10-01 | assets | -43025514.466 | 115328755.58 | differs |
| 5|2025-10-01 | assets_opening_balance | -52697239.916 | 109672860.98 | differs |
| 1|2025-02-01 | ebitda_actual | 8669010.089 | 8731737.56 | differs |
| 1|2025-02-01 | account_receivable_actual | 14650392.62 | 133422823.17 | differs |
| 1|2025-02-01 | account_receivable_actual_opening_balance | -30416644.14 | 118772430.55 | differs |
| 1|2025-02-01 | consumables_actual | 1154616.86 | 4032338.17 | differs |
| 1|2025-02-01 | assets | 8746693.22 | 501723494.48 | differs |
| 1|2025-02-01 | assets_opening_balance | 2026924.64 | 492976801.26 | differs |
| 4|2025-02-01 | account_receivable_actual | -825233.28 | 96199890.12 | differs |
| 4|2025-02-01 | account_receivable_actual_opening_balance | 13412650.19 | 97025123.4 | differs |
| 4|2025-02-01 | consumables_actual | 1049253.88 | 2031798.52 | differs |
| 4|2025-02-01 | assets | 5599812.04 | 192328474.21 | differs |
| 4|2025-02-01 | assets_opening_balance | 8908064.1 | 186728662.17 | differs |
| 5|2025-03-01 | consumables_actual | 1082499.65 | 2233422.43 | differs |
| 5|2025-03-01 | assets | -55629984.196 | 104331739.47 | differs |
| 5|2025-03-01 | assets_opening_balance | -54928547.526 | 105033176.14 | differs |
| 1|2025-05-01 | ebitda_actual | 4211866.66 | 4258031.66 | differs |
| 1|2025-05-01 | account_receivable_actual | 16769201.58 | 129160199.34 | differs |
| 1|2025-05-01 | account_receivable_actual_opening_balance | 10907012.41 | 112390997.76 | differs |
| 1|2025-05-01 | consumables_actual | 1311525.19 | 4373664.99 | differs |
| 1|2025-05-01 | assets | 5931994.92 | 499514900.84 | differs |
| 1|2025-05-01 | assets_opening_balance | -3280045 | 493582905.92 | differs |
| 6|2025-08-01 | operating_expenses | 9822807.06 | 9772871.06 | differs |
| 6|2025-08-01 | ebitda_actual | 3020503.3 | 3070439.3 | differs |
| 6|2025-08-01 | account_receivable_actual | 3876166.74 | 56421119.19 | differs |
| 6|2025-08-01 | account_receivable_actual_opening_balance | 10909617.68 | 52544952.45 | differs |
| 6|2025-08-01 | consumables_actual | 1406945.13 | 2085817.01 | differs |
| 6|2025-08-01 | assets | 2580083.25 | 80280176.1 | differs |
| 6|2025-08-01 | assets_opening_balance | 3890935.41 | 77700092.85 | differs |
| 1|2025-12-01 | account_receivable_actual | 11261570.55 | 139848850.22 | differs |
| 1|2025-12-01 | account_receivable_actual_opening_balance | 11714529.31 | 128587279.67 | differs |
| 1|2025-12-01 | consumables_actual | 1786420.65 | 5087641.16 | differs |
| 1|2025-12-01 | assets | 1925899.59 | 512244913.92 | differs |
| 1|2025-12-01 | assets_opening_balance | 1825902.69 | 510319014.33 | differs |
| 3|2025-08-01 | operating_expenses | 13718244.53 | 13502722.53 | differs |
| 3|2025-08-01 | ebitda_actual | 12900264.98 | 13115786.98 | differs |
| 3|2025-08-01 | account_receivable_actual | 18925807.4 | 172420547.81 | differs |
| 3|2025-08-01 | account_receivable_actual_opening_balance | 16795732.36 | 153494740.41 | differs |
| 3|2025-08-01 | consumables_actual | 1462542.45 | 2942856.1 | differs |
| 3|2025-08-01 | assets | 14066176.91 | 518512610.85 | differs |
| 3|2025-08-01 | assets_opening_balance | 12227460.1 | 504446433.94 | differs |
| 4|2025-05-01 | account_receivable_actual | 10199584.87 | 79154746.04 | differs |
| 4|2025-05-01 | account_receivable_actual_opening_balance | -2431295.79 | 68955161.17 | differs |
| 4|2025-05-01 | consumables_actual | 1225195 | 2154094.09 | differs |
| 4|2025-05-01 | assets | 904682.07 | 193686390.83 | differs |
| 4|2025-05-01 | assets_opening_balance | 300445.25 | 192781708.76 | differs |
| 4|2025-12-01 | account_receivable_actual | 84333.01 | 103367189.03 | differs |
| 4|2025-12-01 | account_receivable_actual_opening_balance | 16445554.53 | 103282856.02 | differs |
| 4|2025-12-01 | consumables_actual | 1061306.13 | 2530779.6 | differs |
| 4|2025-12-01 | assets | 1240998.6 | 230706783.82 | differs |
| 4|2025-12-01 | assets_opening_balance | 10452578.28 | 229465785.22 | differs |
| 5|2025-06-01 | consumables_actual | 913002.81 | 1902822.07 | differs |
| 5|2025-06-01 | assets | -54444983.256 | 105553528.8 | differs |
| 5|2025-06-01 | assets_opening_balance | -54500613.816 | 105461109.85 | differs |
| 6|2025-09-01 | operating_expenses | 9077423.92 | 9027487.92 | differs |
| 6|2025-09-01 | ebitda_actual | 1661258.39 | 1711194.39 | differs |
| 6|2025-09-01 | account_receivable_actual | 10513493.64 | 66934612.83 | differs |
| 6|2025-09-01 | account_receivable_actual_opening_balance | 3876166.74 | 56421119.19 | differs |
| 6|2025-09-01 | consumables_actual | 657191.8 | 1219442.94 | differs |
| 6|2025-09-01 | assets | 1689099.69 | 81969275.79 | differs |
| 6|2025-09-01 | assets_opening_balance | 2580083.25 | 80280176.1 | differs |
| 8|2026-08-01 | net_revenue_actual | 402833.71 | 443974.03 | differs |
| 8|2026-08-01 | sub_revenue_actual | 402833.71 | 448930.69 | differs |
| 8|2026-08-01 | operating_expenses | 0 | 3576916.12 | differs |
| 8|2026-08-01 | ebitda_actual | 402833.71 | -3132942.09 | differs |
| 8|2026-08-01 | account_receivable_actual | 917.35 | 74783.77 | differs |
| 8|2026-08-01 | account_receivable_actual_opening_balance | 679.47 | 29763.77 | differs |
| 8|2026-08-01 | ga_expenses_actual | 0 | 26000 | differs |
| 8|2026-08-01 | assets | 606791.68 | -8535.07 | differs |
| 8|2026-08-01 | assets_opening_balance | 198098.17 | 223847.38 | differs |
| 8|2026-08-01 | income | 402833.71 | -3132959.34 | differs |
| 5|2025-01-01 | account_receivable_actual_opening_balance | 1487263.09 | 85028813.62 | differs |
| 5|2025-01-01 | consumables_actual | 1088046.85 | 2374234.18 | differs |
| 5|2025-01-01 | assets_opening_balance | -944961.17 | 94807087.57 | differs |
| 6|2026-08-01 | net_revenue_actual | 16914582.16 | 16022436.26 | differs |
| 6|2026-08-01 | sub_revenue_actual | 16914582.16 | 18778571.49 | differs |
| 6|2026-08-01 | operating_expenses | 4096417.24 | 15466538.21 | differs |
| 6|2026-08-01 | ebitda_actual | 12818164.92 | 555898.05 | differs |
| 6|2026-08-01 | account_receivable_actual | 178928882.94 | 154974331.09 | differs |
| 6|2026-08-01 | account_receivable_actual_opening_balance | 161728055.12 | 139132187.1 | differs |
| 6|2026-08-01 | ga_expenses_actual | 0 | 2340920.05 | differs |
| 6|2026-08-01 | consumables_actual | 0 | 136789.33 | differs |
| 6|2026-08-01 | assets | 188417363.56 | 105795998.62 | differs |
| 6|2026-08-01 | assets_opening_balance | 169367163.03 | 103467554.1 | differs |
| 6|2026-08-01 | income | 12818170.67 | -391962.48 | differs |
| 3|2025-09-01 | operating_expenses | 15671533.59 | 15456011.59 | differs |
| 3|2025-09-01 | ebitda_actual | 11590263.6 | 11805785.6 | differs |
| 3|2025-09-01 | account_receivable_actual | 2250855.87 | 174671403.68 | differs |
| 3|2025-09-01 | account_receivable_actual_opening_balance | 18925807.4 | 172420547.81 | differs |
| 3|2025-09-01 | consumables_actual | 1947653.19 | 3497649.93 | differs |
| 3|2025-09-01 | assets | 14238861.66 | 532751472.51 | differs |
| 3|2025-09-01 | assets_opening_balance | 14066176.91 | 518512610.85 | differs |
| 4|2025-01-01 | account_receivable_actual | 13412650.19 | 97025123.4 | differs |
| 4|2025-01-01 | account_receivable_actual_opening_balance | 11166377.92 | 83612473.21 | differs |
| 4|2025-01-01 | consumables_actual | 1240591.87 | 2304131.61 | differs |
| 4|2025-01-01 | assets | 8908064.1 | 186728662.17 | differs |
| 4|2025-01-01 | assets_opening_balance | 1504497.95 | 177820598.07 | differs |
| 3|2026-08-01 | net_revenue_actual | 3552019.66 | 40561310.51 | differs |
| 3|2026-08-01 | sub_revenue_actual | 3552019.66 | 43659200.94 | differs |
| 3|2026-08-01 | operating_expenses | -6908.32 | 24494339.74 | differs |
| 3|2026-08-01 | ebitda_actual | 3558927.98 | 16066970.77 | differs |
| 3|2026-08-01 | account_receivable_actual | 166370001.92 | 248977038.82 | differs |
| 3|2026-08-01 | account_receivable_actual_opening_balance | 251384632.23 | 293564622.34 | differs |
| 3|2026-08-01 | ga_expenses_actual | -6908.32 | 46297.51 | differs |
| 3|2026-08-01 | consumables_actual | 0 | 265978.81 | differs |
| 3|2026-08-01 | assets | 630651519.485 | 720209089.68 | differs |
| 3|2026-08-01 | assets_opening_balance | 578157532.551 | 688242909.13 | differs |
| 3|2026-08-01 | income | 3558927.98 | 16065305 | differs |
| 2|2025-09-01 | consumables_actual | 1710439.49 | 3334575.54 | differs |
| 2|2025-09-01 | assets | 671824868.116 | 758176855.8 | differs |
| 2|2025-09-01 | assets_opening_balance | 680027717.706 | 747492524.66 | differs |
| 2|2026-08-01 | consumables_actual | 2318081.57 | 4465328.28 | differs |
| 2|2026-08-01 | assets | 874489449.646 | 898860147.52 | differs |
| 2|2026-08-01 | assets_opening_balance | 877203031.826 | 886257136.26 | differs |
| 1|2025-01-01 | ebitda_actual | 7253983.93 | 7316711.4 | differs |
| 1|2025-01-01 | account_receivable_actual | -30416644.14 | 118772430.55 | differs |
| 1|2025-01-01 | account_receivable_actual_opening_balance | 3020992.14 | 149189074.69 | differs |
| 1|2025-01-01 | consumables_actual | 2098872.94 | 5480268.07 | differs |
| 1|2025-01-01 | assets | 2026924.64 | 492976801.26 | differs |
| 1|2025-01-01 | assets_opening_balance | -8629589.6 | 490949876.62 | differs |
| 1|2025-10-01 | ebitda_actual | 5831437.56 | 5877603.56 | differs |
| 1|2025-10-01 | account_receivable_actual | 1235717.77 | 116872750.36 | differs |
| 1|2025-10-01 | account_receivable_actual_opening_balance | -20964797.5 | 115637032.59 | differs |
| 1|2025-10-01 | consumables_actual | 2133158.98 | 5359916.57 | differs |
| 1|2025-10-01 | assets | 6162637.29 | 508493111.64 | differs |
| 1|2025-10-01 | assets_opening_balance | 2120883.39 | 502330474.35 | differs |
| 4|2025-10-01 | account_receivable_actual | 7836509.35 | 86837301.49 | differs |
| 4|2025-10-01 | account_receivable_actual_opening_balance | -11796656.11 | 79000792.14 | differs |
| 4|2025-10-01 | consumables_actual | 1090093.4 | 2522914.03 | differs |
| 4|2025-10-01 | assets | 10042083.74 | 219013206.94 | differs |
| 4|2025-10-01 | assets_opening_balance | 5010485.03 | 208971123.2 | differs |
| 5|2025-11-01 | consumables_actual | 1268514.38 | 2542689.42 | differs |
| 5|2025-11-01 | assets | -36748881.976 | 121559599.68 | differs |
| 5|2025-11-01 | assets_opening_balance | -43025514.466 | 115328755.58 | differs |
| 2|2026-09-01 | net_revenue_actual | 6199205.75 | 0 | differs |
| 2|2026-09-01 | sub_revenue_actual | 6199205.75 | 0 | differs |
| 2|2026-09-01 | operating_expenses | -4347.83 | 0 | differs |
| 2|2026-09-01 | ebitda_actual | 6203553.58 | 0 | differs |
| 2|2026-09-01 | account_receivable_actual | 248443261.169 | 317288577.42 | differs |
| 2|2026-09-01 | account_receivable_actual_opening_balance | 185679623.749 | 317288577.42 | differs |
| 2|2026-09-01 | assets | 881463855.486 | 1741000118.28 | differs |
| 2|2026-09-01 | assets_opening_balance | 874489449.646 | 1741000118.28 | differs |
| 2|2026-09-01 | income | 6203553.58 | 0 | differs |
| 2|2025-10-01 | consumables_actual | 2027320.87 | 3896034.63 | differs |
| 2|2025-10-01 | assets | 705186401.156 | 772651208.11 | differs |
| 2|2025-10-01 | assets_opening_balance | 671824868.116 | 758176855.8 | differs |
| 3|2025-01-01 | operating_expenses | 16364732.88 | 16149210.88 | differs |
| 3|2025-01-01 | ebitda_actual | 9442760.76 | 9658282.76 | differs |
| 3|2025-01-01 | account_receivable_actual | 3562252.56 | 128273513.42 | differs |
| 3|2025-01-01 | account_receivable_actual_opening_balance | 6218273.56 | 124711260.86 | differs |
| 3|2025-01-01 | consumables_actual | 1915046.18 | 3344515.78 | differs |
| 3|2025-01-01 | assets | 11857618.34 | 455697135.47 | differs |
| 3|2025-01-01 | assets_opening_balance | -4335047.7 | 443839517.13 | differs |
| 4|2025-09-01 | account_receivable_actual | -11796656.11 | 79000792.14 | differs |
| 4|2025-09-01 | account_receivable_actual_opening_balance | 7126924.05 | 90797448.25 | differs |
| 4|2025-09-01 | consumables_actual | 1191478.62 | 2363706.79 | differs |
| 4|2025-09-01 | assets | 5010485.03 | 208971123.2 | differs |
| 4|2025-09-01 | assets_opening_balance | 4580100.05 | 203960638.17 | differs |
| 1|2025-09-01 | ebitda_actual | 4774029.4 | 4820195.4 | differs |
| ... | 260 more | | | |

## vw_gl_transactions

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 7032, new 8581. Differences: 6951.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 1|2025-07-01|IS|expenses|general and administrative expenses|employee cost|employee cost | OpeningBalance | 0 | 1845138.38 | differs |
| 3|2025-10-01|IS|expenses|direct cost|employee costs|employee govt fees | OpeningBalance | 0 | 3553871.06 | differs |
| 4|2025-06-01|IS|expenses|direct cost|employee costs|employee costs | OpeningBalance | 0 | 25102392.29 | differs |
| 3|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|housing guarantee payable to employees | OpeningBalance | 0 | -37641.87 | differs |
| 3|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | * |  |  | missing in new |
| 3|2025-04-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|hopsitality | OpeningBalance | 0 | 39396.13 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 4|2025-02-01|IS|expenses|direct cost|employee costs|employee medical insurance | OpeningBalance | 0 | 161801.34 | differs |
| 1|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued doctors fee and commission | * |  |  | missing in new |
| 6|2025-07-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 0 | 946018.04 | differs |
| 3|2025-10-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 3|2025-04-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | 0 | -4486577.47 | differs |
| 3|2025-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | OpeningBalance | 0 | 15995102.56 | differs |
| 4|2025-07-01|IS|revenue|revenue - discounts|revenue - settlement discount|volume discount | OpeningBalance | 0 | 940391.6 | differs |
| 1|2025-02-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | 0 | -1976608 | differs |
| 3|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 1|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | 0 | -392324.23 | differs |
| 6|2025-04-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 3|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 389400 | differs |
| 2|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 3|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 270600 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | Transaction_Balance | -181092 | 0 | differs |
| 3|2025-06-01|IS|other income|other income, net|other income, net|support medical companies | OpeningBalance | 0 | -166666.67 | differs |
| 4|2025-03-01|BS|assets|non current assets|work in progress|cwip | OpeningBalance | 0 | 8853320.4 | differs |
| 1|2025-02-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | OpeningBalance | 0 | -51091631.91 | differs |
| 2|2026-09-01||||| | * |  |  | missing in new |
| 6|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | 0 | -4021004.88 | differs |
| 5|2026-08-01|IS|expenses|direct cost|medical consumables|medical consumables | OpeningBalance | 21319799.75 | 8585771.87 | differs |
| 1|2025-02-01|BS|assets|non current assets|intangible assets |software accm amortization | * |  |  | missing in new |
| 3|2025-04-01|BS|assets|non current assets|ppe cost|computers cost | OpeningBalance | 0 | 7398340.88 | differs |
| 1|2025-09-01|BS|assets|current assets|inventories, net|inventory - provision | OpeningBalance | 0 | -3462708.9 | differs |
| 1|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 11704.48 | differs |
| 6|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 154713.77 | differs |
| 3|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 157963666.9 | differs |
| 3|2025-12-01|IS|revenue|revenue|revenue out patient|revenue credit - op | OpeningBalance | 0 | -40330839.99 | differs |
| 6|2025-02-01|IS|expenses|direct cost|maintenance expense|maintenance expense | OpeningBalance | 0 | 175768.34 | differs |
| 3|2025-02-01|IS|expenses|direct cost|medical consumables|stock adjustments | OpeningBalance | 0 | 382663.93 | differs |
| 2|2025-11-01|IS|expenses|general and administrative expenses|repair & maintenance|kitchen expenses  | * |  |  | missing in new |
| 3|2025-02-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 4|2025-05-01|IS|expenses|direct cost|maintenance expense|medical equipment maintenance | OpeningBalance | 0 | 162923.82 | differs |
| 3|2025-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | 0 | -2069964.99 | differs |
| 1|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 0 | -40372523.1 | differs |
| 6|2025-09-01|IS|expenses|zakat|zakat|zakat expense | OpeningBalance | 0 | 463440 | differs |
| 2|2025-08-01|IS|expenses|general and administrative expenses|repair & maintenance|kitchen expenses  | * |  |  | missing in new |
| 3|2025-04-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | * |  |  | missing in new |
| 3|2025-05-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | 0 | 10135371.31 | differs |
| 3|2025-11-01|BS|assets|current assets|due from / ( due to) branch|due to branch | * |  |  | missing in new |
| 6|2025-06-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | 0 | -433629.88 | differs |
| 2|2025-04-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 1|2025-02-01|IS|expenses|general and administrative expenses|governmental fee|government fee | OpeningBalance | 0 | 117821.11 | differs |
| 1|2025-03-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 289.52 | differs |
| 6|2025-12-01|BS|assets|non current assets|intangible assets |software cost | * |  |  | missing in new |
| 3|2025-06-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 3|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 391953.98 | differs |
| 6|2025-03-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | OpeningBalance | 0 | 683420 | differs |
| 1|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | OpeningBalance | 0 | -150000 | differs |
| 4|2025-12-01|IS|expenses|direct cost|medical consumables|medical gases | OpeningBalance | 0 | 175890 | differs |
| 3|2025-10-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | OpeningBalance | 0 | 12958181.44 | differs |
| 3|2025-06-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | OpeningBalance | 0 | 79200 | differs |
| 5|2026-08-01|IS|expenses|general and administrative expenses|telephone, electricity and water|telephone, electricity and water | OpeningBalance | 3895692.09 | 1447689.51 | differs |
| 6|2025-03-01|IS|expenses|direct cost|other direct expenses|referral cost | OpeningBalance | 0 | 12646.25 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 117649.94 | 43274.19 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op | * |  |  | missing in new |
| 1|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | OpeningBalance | 0 | 3392626.82 | differs |
| 3|2025-01-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 0 | 8152083.28 | differs |
| 1|2025-07-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | OpeningBalance | 0 | 161237.97 | differs |
| 6|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | OpeningBalance | 0 | -216846.81 | differs |
| 3|2025-07-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | OpeningBalance | 0 | -14825967.79 | differs |
| 4|2025-06-01|BS|assets|non current assets|ppe cost|electrical devices cost | OpeningBalance | 0 | 16766738.35 | differs |
| 1|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | OpeningBalance | 0 | 3973953.39 | differs |
| 3|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 1342096.64 | differs |
| 6|2025-03-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | OpeningBalance | 0 | 312140 | differs |
| 1|2025-05-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | OpeningBalance | 0 | 10983854.9 | differs |
| 4|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | OpeningBalance | 0 | -1962335.18 | differs |
| 6|2025-07-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | OpeningBalance | 0 | 117591.8 | differs |
| 5|2025-07-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 1|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | 0 | -485284.77 | differs |
| 3|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued marketing and advertisement | OpeningBalance | 0 | -94488.46 | differs |
| 4|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | 0 | -1133342.63 | differs |
| 4|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | OpeningBalance | 0 | -257078.75 | differs |
| 1|2025-08-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | OpeningBalance | 0 | 20255818.82 | differs |
| 1|2025-10-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | OpeningBalance | 0 | -86007030.36 | differs |
| 6|2025-10-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 0 | -9908086.19 | differs |
| 1|2025-09-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | 0 | -2195994.35 | differs |
| 4|2025-05-01|IS|expenses|direct cost|maintenance expense|maintenance expense | OpeningBalance | 0 | 60387.04 | differs |
| 4|2025-10-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 0 | 9324467.88 | differs |
| 4|2025-10-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | OpeningBalance | 0 | 104095.97 | differs |
| 4|2025-05-01|IS|other income|other income, net|other income, net|education and training | OpeningBalance | 0 | -27241.77 | differs |
| 1|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued nafees portal fees | * |  |  | missing in new |
| 1|2025-07-01|IS|expenses|general and administrative expenses|telephone, electricity and water|telephone, electricity and water | * |  |  | missing in new |
| 6|2025-12-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | OpeningBalance | 0 | 6132903.59 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | Transaction_Balance | 2083808.77 | -1139740.16 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 80916.27 | 39916.27 | differs |
| 4|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 113371271.98 | differs |
| 6|2025-09-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 4|2025-02-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | OpeningBalance | 0 | 1852706.33 | differs |
| 6|2025-04-01|BS|assets|current assets|inventories, net|inventory - provision | OpeningBalance | 0 | -32879.48 | differs |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | * |  |  | missing in new |
| 3|2025-12-01|IS|other income|other income, net|other income, net|support medical companies | OpeningBalance | 0 | -266666.69 | differs |
| 1|2026-09-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 6|2025-05-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 0 | 1959159.71 | differs |
| 1|2025-06-01|IS|expenses|direct cost|maintenance expense|security and cleaning expenses | OpeningBalance | 0 | 37410.86 | differs |
| 6|2025-02-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 3|2025-07-01|IS|expenses|direct cost|employee costs|outsource expenses (givc) | OpeningBalance | 0 | 3602422.44 | differs |
| 4|2025-06-01|IS|expenses|direct cost|utilities|utilities | OpeningBalance | 0 | 714241.12 | differs |
| 3|2025-02-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | 0 | -14436415.34 | differs |
| 1|2025-10-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | OpeningBalance | 0 | -19359555.74 | differs |
| 1|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | * |  |  | missing in new |
| 4|2025-10-01|BS|assets|current assets|due from / ( due to) branch|due from branch | * |  |  | missing in new |
| 1|2025-12-01|BS|equity|equity|retained earnings|retained earnings | OpeningBalance | 0 | -412208791.99 | differs |
| 4|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 6|2025-04-01|IS|expenses|direct cost|insurance expenses|insurance expenses | OpeningBalance | 0 | 24884.56 | differs |
| 6|2025-10-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | OpeningBalance | 0 | 72618.71 | differs |
| 4|2025-11-01|IS|expenses|direct cost|employee costs|employee medical insurance | OpeningBalance | 0 | 1535850.36 | differs |
| 4|2025-12-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | OpeningBalance | 0 | 91642493.81 | differs |
| 4|2025-06-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 1|2025-03-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | OpeningBalance | 0 | 880189 | differs |
| 4|2025-12-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 0 | 9289304.39 | differs |
| 4|2025-05-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | OpeningBalance | 0 | 291802.95 | differs |
| 3|2025-05-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | OpeningBalance | 0 | 401838.16 | differs |
| 1|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | OpeningBalance | 0 | 3884826.98 | differs |
| 3|2025-05-01|IS|expenses|direct cost|maintenance expense|medical equipment maintenance | OpeningBalance | 0 | 250167.89 | differs |
| 1|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | 0 | -128265.93 | differs |
| 1|2025-11-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | 0 | -4345633 | differs |
| 6|2025-04-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | OpeningBalance | 0 | -28757099.71 | differs |
| 1|2025-06-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | 0 | -4151384.19 | differs |
| 4|2025-06-01|IS|expenses|direct cost|maintenance expense|building and facility maintenance | OpeningBalance | 0 | 45065.99 | differs |
| 4|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | 0 | -881595.78 | differs |
| 4|2025-05-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | 0 | 4010260.78 | differs |
| 1|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | 0 | -1186783.14 | differs |
| 1|2025-12-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | OpeningBalance | 0 | -31954198.37 | differs |
| 4|2025-10-01|IS|expenses|direct cost|maintenance expense|employee accommodation maintenance | OpeningBalance | 0 | 27988.75 | differs |
| 1|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid government fee | * |  |  | missing in new |
| 3|2025-06-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | OpeningBalance | 0 | 322478.42 | differs |
| 1|2025-11-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 0 | -92903201.96 | differs |
| 1|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 2006676.53 | differs |
| 6|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 16823.28 | differs |
| 4|2025-04-01|IS|expenses|general and administrative expenses|governmental fee|government fee | OpeningBalance | 0 | 361135.69 | differs |
| 4|2025-09-01|BS|assets|non current assets|ppe cost|building cost | OpeningBalance | 0 | 111898495.42 | differs |
| 6|2025-03-01|IS|expenses|finance cost|finance cost|bank charges | OpeningBalance | 0 | 1767039.95 | differs |
| 3|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | OpeningBalance | 0 | -311410.6 | differs |
| 3|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued marketing and advertisement | OpeningBalance | 0 | -447533.47 | differs |
| 1|2025-08-01|IS|expenses|direct cost|other direct expenses|cost of medicines | OpeningBalance | 0 | -1078.54 | differs |
| 4|2025-04-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 6|2025-04-01|IS|expenses|general and administrative expenses|telephone, electricity and water|telephone, electricity and water | OpeningBalance | 0 | 56358.27 | differs |
| 4|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | OpeningBalance | 0 | -12519.28 | differs |
| 4|2025-03-01|IS|expenses|direct cost|other direct expenses|referral cost | OpeningBalance | 0 | 145296.9 | differs |
| 4|2025-03-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | OpeningBalance | 0 | -44044996.94 | differs |
| 4|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 3|2025-03-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | OpeningBalance | 0 | -14667.65 | differs |
| 1|2025-04-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | 0 | -19975194.04 | differs |
| 6|2025-10-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 262751 | differs |
| 5|2026-09-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | * |  |  | missing in new |
| 3|2025-02-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | OpeningBalance | 0 | -27114237.57 | differs |
| 5|2026-09-01|IS|expenses|direct cost|medical consumables|stock adjustments | * |  |  | missing in new |
| 1|2025-10-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | OpeningBalance | 0 | -54544009.62 | differs |
| 3|2025-12-01|IS|expenses|zakat|zakat|zakat expense | OpeningBalance | 0 | 2337082 | differs |
| 1|2025-10-01|BS|assets|non current assets|intangible assets |software accm amortization | * |  |  | missing in new |
| 3|2025-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | OpeningBalance | 0 | 18531205.1 | differs |
| 3|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 642074.97 | differs |
| 4|2025-12-01|BS|assets|non current assets|ppe cost|vehicles cost | OpeningBalance | 0 | 678018.9 | differs |
| 1|2025-03-01|IS|expenses|general and administrative expenses|stationary|postage printing and stationary | OpeningBalance | 0 | 3031.74 | differs |
| 6|2025-05-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 25018964.87 | differs |
| 3|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | 0 | -2638345.17 | differs |
| 2|2025-09-01|IS|expenses|general and administrative expenses|repair & maintenance|kitchen expenses  | * |  |  | missing in new |
| 3|2025-03-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|housing guarantee payable to employees | OpeningBalance | 0 | -37641.87 | differs |
| 6|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 0 | -357320.02 | differs |
| 3|2025-07-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 231000 | differs |
| 1|2025-08-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | OpeningBalance | 0 | 13496669.43 | differs |
| 6|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | -123031.88 | differs |
| 6|2025-11-01|IS|expenses|direct cost|maintenance expense|maintenance expense | OpeningBalance | 0 | 1288525.43 | differs |
| 4|2025-10-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | OpeningBalance | 0 | 2993243 | differs |
| 3|2025-10-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | OpeningBalance | 0 | -14089595.46 | differs |
| 6|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | OpeningBalance | 0 | 514749.07 | differs |
| 6|2025-11-01|IS|expenses|zakat|zakat|zakat expense | OpeningBalance | 0 | 579300 | differs |
| 4|2025-04-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 0 | -21150537.37 | differs |
| 3|2025-10-01|BS|assets|current assets|due from related parties |due from related parties  | * |  |  | missing in new |
| 4|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|audit fee accrual | OpeningBalance | 0 | -439922.95 | differs |
| 4|2025-06-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | OpeningBalance | 0 | 271685.28 | differs |
| 4|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|audit fee accrual | OpeningBalance | 0 | -369922.95 | differs |
| 1|2025-11-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | 0 | -19530338.38 | differs |
| 6|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | OpeningBalance | 0 | -424610.04 | differs |
| 6|2025-03-01|IS|expenses|direct cost|maintenance expense|maintenance expense | OpeningBalance | 0 | 177438.38 | differs |
| 3|2025-02-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 149172086.29 | differs |
| 4|2025-01-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | 0 | 30953.11 | differs |
| 4|2025-08-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 6|2025-03-01|IS|expenses|direct cost|employee costs|staff training and recruitments | OpeningBalance | 0 | 14159.92 | differs |
| 1|2025-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | 0 | -20212635.37 | differs |
| 1|2025-05-01|IS|expenses|general and administrative expenses|professional fee and subscription|communication | OpeningBalance | 0 | 297383.58 | differs |
| 3|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | OpeningBalance | 0 | -41453.58 | differs |
| 4|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued marketing and advertisement | OpeningBalance | 0 | -359233.98 | differs |
| 1|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | 0 | -6022854.33 | differs |
| 6|2025-10-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | OpeningBalance | 0 | 273287.77 | differs |
| 1|2025-02-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | 0 | -20821242.95 | differs |
| 4|2025-02-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 1|2025-01-01|IS|expenses|direct cost|deprecition|depreciation expense | * |  |  | missing in new |
| 1|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|audit fee accrual | OpeningBalance | 0 | -326793 | differs |
| 3|2025-09-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | OpeningBalance | 0 | 873771.03 | differs |
| 4|2025-12-01|IS|expenses|general and administrative expenses|governmental fee|employee govt fees | OpeningBalance | 0 | 58689.18 | differs |
| ... | 6751 more | | | |

## vw_gl_openning_balance

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 2690, new 8581. Differences: 8716.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 5|2025-12-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | -172027.3 | -867154.6 | differs |
| 5|2025-12-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | forwarded_balance | -695127.3 | 0 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|deferred revenue  | * |  |  | missing in new |
| 2|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | 0 | 20445.71 | differs |
| 2|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | forwarded_balance | 20445.71 | 0 | differs |
| 5|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued maintenance | OpeningBalance | -22522.33 | -522088.96 | differs |
| 5|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued maintenance | forwarded_balance | -499566.63 | 0 | differs |
| 5|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | * |  |  | missing in new |
| 5|2025-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 313864.19 | 492094.58 | differs |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 178230.394 | 0 | differs |
| 5|2026-08-01|IS|other income|other income, net|other income, net|hrdf income | * |  |  | missing in new |
| 2|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | -277404.089 | -13374426.86 | differs |
| 2|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | forwarded_balance | -13097022.774 | 0 | differs |
| 5|2025-11-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -36440710.4 | -71642128.02 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -2927200.141 | 0 | differs |
| 5|2025-03-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | OpeningBalance | -234.02 | -120552.45 | differs |
| 5|2025-03-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | forwarded_balance | -120318.43 | 0 | differs |
| 2|2025-02-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 631413.5 | 896222.22 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | forwarded_balance | 264808.72 | 0 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | OpeningBalance | 3401989.84 | 1061340.58 | differs |
| 2|2026-08-01||||| | * |  |  | missing in new |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | OpeningBalance | 302794.99 | 330640.37 | differs |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | forwarded_balance | 27845.38 | 0 | differs |
| 2|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | OpeningBalance | -36549.09 | 2252620.01 | differs |
| 2|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | forwarded_balance | 2289169.1 | 0 | differs |
| 2|2025-08-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | -1409381.34 | 2519661.12 | differs |
| 2|2025-08-01|BS|assets|current assets|cash and bank balances|bank | forwarded_balance | 3929042.46 | 0 | differs |
| 2|2025-05-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | -566734.35 | -15555665.61 | differs |
| 2|2025-05-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | forwarded_balance | -14988931.26 | 0 | differs |
| 5|2025-05-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | OpeningBalance | -923796.26 | -329896.67 | differs |
| 5|2025-05-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | forwarded_balance | 593899.59 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | * |  |  | missing in new |
| 5|2025-04-01|BS|assets|current assets|inventories, net|expired stock - sub store | OpeningBalance | 81853.86 | 370350.12 | differs |
| 5|2025-04-01|BS|assets|current assets|inventories, net|expired stock - sub store | forwarded_balance | 288496.26 | 0 | differs |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | -1114255.2 | -2271803.56 | differs |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | forwarded_balance | -1157548.36 | 0 | differs |
| 2|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | 1606316.146 | -11490706.63 | differs |
| 2|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | forwarded_balance | -13097022.774 | 0 | differs |
| 2|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | OpeningBalance | -83925.72 | -479062.46 | differs |
| 2|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | forwarded_balance | -395136.74 | 0 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -670523.86 | -1884923.74 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -1214399.88 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 1220741.42 | -7586447.22 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | forwarded_balance | -39223398.96 | 0 | differs |
| 5|2025-10-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | -5584496.04 | -230410.28 | differs |
| 5|2025-10-01|BS|assets|current assets|inventories, net|inventory - medical - main store | forwarded_balance | 5354085.76 | 0 | differs |
| 2|2025-05-01|BS|assets|non current assets|ppe accm depreciation|lhi accm dep | OpeningBalance | -42211.22 | -435919.82 | differs |
| 2|2025-05-01|BS|assets|non current assets|ppe accm depreciation|lhi accm dep | forwarded_balance | -393708.6 | 0 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | OpeningBalance | 23911 | -525759.66 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | forwarded_balance | -549670.66 | 0 | differs |
| 5|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | -181389.68 | -666810.23 | differs |
| 5|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | forwarded_balance | -485420.55 | 0 | differs |
| 2|2025-07-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | -8822 | -1489802.99 | differs |
| 2|2025-07-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | forwarded_balance | -1480980.99 | 0 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -14707601.11 | -24308522.2 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -9856671.437 | 0 | differs |
| 5|2025-06-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 54191821.51 | 229114221.99 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 174922400.48 | 0 | differs |
| 2|2025-08-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | -3566.44 | 12781.56 | differs |
| 2|2025-08-01|BS|assets|current assets|cash and bank balances|cash | forwarded_balance | 16347.997 | 0 | differs |
| 5|2025-12-01|BS|assets|current assets|inventories, net|inventory - medical - pharmacy | OpeningBalance | 8234766.91 | 9282031.58 | differs |
| 5|2025-12-01|BS|assets|current assets|inventories, net|inventory - medical - pharmacy | forwarded_balance | 1047264.67 | 0 | differs |
| 5|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | OpeningBalance | 1499105.05 | 1672530.28 | differs |
| 5|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | forwarded_balance | 173425.23 | 0 | differs |
| 2|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | OpeningBalance | 28441.42 | 32091.38 | differs |
| 2|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | forwarded_balance | 3649.96 | 0 | differs |
| 2|2025-06-01|IS|expenses|general and administrative expenses|repair & maintenance|kitchen expenses  | * |  |  | missing in new |
| 2|2025-08-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | 2028.18 | 42885.61 | differs |
| 2|2025-08-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | forwarded_balance | 40857.43 | 0 | differs |
| 5|2025-04-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | OpeningBalance | -827037.32 | -11904800.05 | differs |
| 5|2025-04-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | forwarded_balance | -11077762.73 | 0 | differs |
| 2|2025-12-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 5|2025-02-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | -8351102.16 | 91777498.19 | differs |
| 5|2025-02-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 100128600.35 | 0 | differs |
| 2|2025-09-01|BS|assets|non current assets|ppe cost|medical equip cost | OpeningBalance | 1837001.7 | 121796566.44 | differs |
| 2|2025-09-01|BS|assets|non current assets|ppe cost|medical equip cost | forwarded_balance | 119959564.74 | 0 | differs |
| 5|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | OpeningBalance | 267134.59 | 440559.82 | differs |
| 5|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | forwarded_balance | 173425.23 | 0 | differs |
| 5|2025-06-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 67120.92 | 6815022.8 | differs |
| 5|2025-06-01|BS|assets|non current assets|ppe cost|furniture cost | forwarded_balance | 6747901.88 | 0 | differs |
| 2|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | 787429.815 | -12309592.96 | differs |
| 2|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | forwarded_balance | -13097022.774 | 0 | differs |
| 5|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -2785164.53 | -3999564.41 | differs |
| 5|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -1214399.88 | 0 | differs |
| 2|2025-12-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | OpeningBalance | 442501.12 | 470346.5 | differs |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | forwarded_balance | 27845.38 | 0 | differs |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | OpeningBalance | -451093.92 | 1531391.08 | differs |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | forwarded_balance | 1982485 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | OpeningBalance | 3027457.52 | 3339281.23 | differs |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | forwarded_balance | 311823.71 | 0 | differs |
| 2|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 18715416.67 | 215842640.79 | differs |
| 2|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 197127224.119 | 0 | differs |
| 5|2025-06-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | -7675850.63 | -22775637.36 | differs |
| 5|2025-06-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | forwarded_balance | -15099786.73 | 0 | differs |
| 2|2025-03-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 5|2025-04-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | OpeningBalance | -1148603.7 | -11256899.58 | differs |
| 5|2025-04-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | forwarded_balance | -10108295.88 | 0 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | OpeningBalance | -449924 | -12475511 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | forwarded_balance | -12025587 | 0 | differs |
| 2|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 934365.08 | 2110643.01 | differs |
| 2|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 1176277.93 | 0 | differs |
| 2|2025-08-01|BS|assets|non current assets|ppe cost|computers cost | OpeningBalance | 77560.8 | 8338754.98 | differs |
| 2|2025-08-01|BS|assets|non current assets|ppe cost|computers cost | forwarded_balance | 8261194.18 | 0 | differs |
| 5|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | -226737.1 | -712157.65 | differs |
| 5|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | forwarded_balance | -485420.55 | 0 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | -158715.97 | -644136.52 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | forwarded_balance | -485420.55 | 0 | differs |
| 2|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | 10404.12 | 30849.83 | differs |
| 2|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | forwarded_balance | 20445.71 | 0 | differs |
| 5|2025-04-01|IS|other income|other income, net|other income, net|hrdf income | * |  |  | missing in new |
| 2|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 1814179.79 | 2990457.72 | differs |
| 2|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 1176277.93 | 0 | differs |
| 2|2025-01-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | OpeningBalance | -47963.5 | -71696.25 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | forwarded_balance | -23732.75 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | -554955.58 | -4963294.2 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | forwarded_balance | -4408338.62 | 0 | differs |
| 5|2025-05-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 5|2025-02-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 5|2025-05-01|IS|expenses|direct cost|deprecition|depreciation expense | * |  |  | missing in new |
| 5|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | OpeningBalance | -55000 | 76666.67 | differs |
| 5|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | forwarded_balance | 131666.67 | 0 | differs |
| 2|2025-04-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | OpeningBalance | -325488.05 | -29001180.26 | differs |
| 2|2025-04-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | forwarded_balance | -28675692.21 | 0 | differs |
| 2|2025-04-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 36182.38 | 10210203.82 | differs |
| 2|2025-04-01|BS|assets|non current assets|ppe cost|furniture cost | forwarded_balance | 10174021.44 | 0 | differs |
| 5|2025-03-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | -362184 | -1540947 | differs |
| 5|2025-03-01|BS|liabilities|current liabilities|zakat payable|zakat payable | forwarded_balance | -1178763 | 0 | differs |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | -26220991.22 | 256563486.04 | differs |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 230572199.28 | 0 | differs |
| 2|2025-05-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | 3533.15 | 44390.58 | differs |
| 2|2025-05-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | forwarded_balance | 40857.43 | 0 | differs |
| 2|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | OpeningBalance | 762114.14 | 930718.85 | differs |
| 2|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | forwarded_balance | 168604.71 | 0 | differs |
| 2|2026-08-01|IS|expenses|zakat|zakat|zakat expense | OpeningBalance | 5515186.85 | 2066057 | differs |
| 2|2026-08-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | OpeningBalance | 2352811.44 | 1004831.48 | differs |
| 2|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | OpeningBalance | 192306885.92 | 73833431.55 | differs |
| 5|2025-05-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 5|2025-06-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 2849783.25 | -15986967.5 | differs |
| 5|2025-06-01|BS|liabilities|current liabilities|trade payables|trade payables | forwarded_balance | -18836750.75 | 0 | differs |
| 8|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -12411.55 | -8449.98 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | -3621840 | -4800603 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | forwarded_balance | -1178763 | 0 | differs |
| 2|2026-09-01||||| | * |  |  | missing in new |
| 5|2026-08-01|IS|expenses|direct cost|medical consumables|medical consumables | OpeningBalance | 21319799.75 | 8585771.87 | differs |
| 2|2025-10-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | -101456.49 | 551172 | differs |
| 2|2025-10-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | forwarded_balance | 652628.49 | 0 | differs |
| 2|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 19256135.64 | 216383359.76 | differs |
| 2|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 197127224.119 | 0 | differs |
| 5|2026-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | OpeningBalance | 114505330.26 | 42336808.98 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | -90694.84 | -576115.39 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | forwarded_balance | -485420.55 | 0 | differs |
| 1|2026-08-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 5|2025-10-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 95674.25 | 6843576.13 | differs |
| 5|2025-10-01|BS|assets|non current assets|ppe cost|furniture cost | forwarded_balance | 6747901.88 | 0 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 2639518.33 | -61088.72 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | forwarded_balance | 133999.9 | 0 | differs |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid government fee | OpeningBalance | 8600 | 45355 | differs |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid government fee | forwarded_balance | 36755 | 0 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | -32115.67 | 146114.72 | differs |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 178230.394 | 0 | differs |
| 2|2025-12-01|BS|assets|non current assets|ppe cost|advertisement and electrical equip cost | OpeningBalance | -123109.28 | 1717378.74 | differs |
| 2|2025-12-01|BS|assets|non current assets|ppe cost|advertisement and electrical equip cost | forwarded_balance | 1840488.02 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | -85772.86 | -2327109.04 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | forwarded_balance | -2241336.18 | 0 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | -724368 | -1903131 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|zakat payable|zakat payable | forwarded_balance | -1178763 | 0 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 2914510.86 | -15922239.89 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|trade payables|trade payables | forwarded_balance | -18836750.75 | 0 | differs |
| 2|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 1302989.55 | differs |
| 2|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | forwarded_balance | 1302989.55 | 0 | differs |
| 2|2025-12-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 95340.01 | -30290805.51 | differs |
| 2|2025-12-01|BS|liabilities|current liabilities|trade payables|trade payables | forwarded_balance | -30386145.519 | 0 | differs |
| 2|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 5|2025-05-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | -220550.29 | -1378098.65 | differs |
| 5|2025-05-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | forwarded_balance | -1157548.36 | 0 | differs |
| 5|2025-12-01|BS|assets|non current assets|ppe cost|vehicles cost | OpeningBalance | 0 | 540732.26 | differs |
| 5|2025-12-01|BS|assets|non current assets|ppe cost|vehicles cost | forwarded_balance | 540732.26 | 0 | differs |
| 5|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | -11594.91 | 10823.2 | differs |
| 5|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | forwarded_balance | 22418.11 | 0 | differs |
| 5|2025-05-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 18818972.05 | -193573442.74 | differs |
| 5|2025-05-01|BS|assets|current assets|due from / ( due to) branch|due to branch | forwarded_balance | -212392414.79 | 0 | differs |
| 2|2025-03-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | OpeningBalance | 1811978.74 | 1980583.45 | differs |
| 2|2025-03-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | forwarded_balance | 168604.71 | 0 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -1136919.74 | -2351319.62 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -1214399.88 | 0 | differs |
| 5|2025-07-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | -51875.77 | -396213.79 | differs |
| 5|2025-07-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | forwarded_balance | -344338.02 | 0 | differs |
| 5|2025-03-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 24720723.27 | -187671691.52 | differs |
| 5|2025-03-01|BS|assets|current assets|due from / ( due to) branch|due to branch | forwarded_balance | -212392414.79 | 0 | differs |
| 5|2025-08-01|BS|assets|current assets|due from related parties |due from related parties  | * |  |  | missing in new |
| 5|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -5131008.58 | -6345408.46 | differs |
| 5|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -1214399.88 | 0 | differs |
| 5|2026-08-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | OpeningBalance | 8692146.26 | 3935643.38 | differs |
| ... | 8516 more | | | |

## vw_hospital_beds_utilization

Keys (hospital_id, period): old 88, new 88. Differences: 733.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 3|2025-06-01 | available_beds | 235 | 244 | differs |
| 3|2025-06-01 | census | 1060 | 1207 | differs |
| 3|2025-06-01 | ltc_census | 99 | 100 | differs |
| 3|2025-06-01 | alos | 32.2607704402516 | 2.79109484964811 | differs |
| 3|2025-06-01 | ltc_alos | 320.521885521885 | 61.032532051282 | differs |
| 3|2025-06-01 | non_ltc_alos | 2.56477627471384 | 2.05529437965663 | differs |
| 3|2025-06-01 | total_bed_nights | 4216 | 3847 | differs |
| 3|2025-06-01 | available_bed_nights | 7050 | 7320 | differs |
| 3|2025-06-01 | occupancy_rate | 0.598014184397163 | 0.525546448087432 | differs |
| 5|2026-08-01 | available_beds | 203 | 201 | differs |
| 5|2026-08-01 | census | 929 | 1049 | differs |
| 5|2026-08-01 | alos | 35.3004126300682 | 27.4782160687333 | differs |
| 5|2026-08-01 | ltc_alos | 467.969871794872 | 525.851947463768 | differs |
| 5|2026-08-01 | non_ltc_alos | 2.75004822530864 | 2.31335147578973 | differs |
| 5|2026-08-01 | available_bed_nights | 6293 | 6231 | differs |
| 2|2025-09-01 | available_beds | 249 | 311 | differs |
| 2|2025-09-01 | census | 1014 | 1080 | differs |
| 2|2025-09-01 | ltc_census | 131 | 132 | differs |
| 2|2025-09-01 | alos | 34.3311143984221 | 5.07281746031747 | differs |
| 2|2025-09-01 | ltc_alos | 244.224236641221 | 116.757098765432 | differs |
| 2|2025-09-01 | non_ltc_alos | 3.19181766704417 | 2.7077385620915 | differs |
| 2|2025-09-01 | total_bed_nights | 5393 | 5356 | differs |
| 2|2025-09-01 | available_bed_nights | 7470 | 9327 | differs |
| 2|2025-09-01 | occupancy_rate | 0.721954484605087 | 0.574246810335585 | differs |
| 3|2025-05-01 | census | 1225 | 1360 | differs |
| 3|2025-05-01 | ltc_census | 102 | 103 | differs |
| 3|2025-05-01 | alos | 27.7456462585034 | 2.9539949100703 | differs |
| 3|2025-05-01 | ltc_alos | 306.260620915033 | 62.9482638888889 | differs |
| 3|2025-05-01 | non_ltc_alos | 2.44864945087563 | 2.15473737163475 | differs |
| 3|2025-05-01 | total_bed_nights | 4651 | 4203 | differs |
| 3|2025-05-01 | occupancy_rate | 0.638435140700069 | 0.575832305795314 | differs |
| 1|2026-09-01 | available_beds | 462 | 452 | differs |
| 1|2026-09-01 | census | 1217 | 1292 | differs |
| 1|2026-09-01 | alos | 138.99941796768 | 6.59028164009392 | differs |
| 1|2026-09-01 | ltc_alos | 494.385014836795 | 139.725818452381 | differs |
| 1|2026-09-01 | non_ltc_alos | 2.90288825757576 | 2.31037919377472 | differs |
| 1|2026-09-01 | total_bed_nights | 11106 | 11351 | differs |
| 1|2026-09-01 | available_bed_nights | 13860 | 13556 | differs |
| 1|2026-09-01 | occupancy_rate | 0.801298701298701 | 0.837341398642667 | differs |
| 2|2025-11-01 | available_beds | 249 | 300 | differs |
| 2|2025-11-01 | census | 1070 | 1126 | differs |
| 2|2025-11-01 | ltc_census | 119 | 120 | differs |
| 2|2025-11-01 | alos | 29.3764018691589 | 6.26872072942278 | differs |
| 2|2025-11-01 | ltc_alos | 238.087535014006 | 123.623691239316 | differs |
| 2|2025-11-01 | non_ltc_alos | 3.26007711181213 | 2.96294691224269 | differs |
| 2|2025-11-01 | total_bed_nights | 5332 | 5239 | differs |
| 2|2025-11-01 | available_bed_nights | 7470 | 9000 | differs |
| 2|2025-11-01 | occupancy_rate | 0.713788487282463 | 0.582111111111111 | differs |
| 6|2025-03-01 | available_beds | 209 | 138 | differs |
| 6|2025-03-01 | census | 134 | 143 | differs |
| 6|2025-03-01 | alos | 65.7338308457712 | 13.2070337301587 | differs |
| 6|2025-03-01 | ltc_alos | 120.430147058824 | 53.5649305555556 | differs |
| 6|2025-03-01 | non_ltc_alos | 9.38005050505051 | 7.99956317204301 | differs |
| 6|2025-03-01 | total_bed_nights | 2165 | 1620 | differs |
| 6|2025-03-01 | available_bed_nights | 6479 | 4278 | differs |
| 6|2025-03-01 | occupancy_rate | 0.334156505633585 | 0.378681626928471 | differs |
| 5|2025-02-01 | available_beds | 203 | 237 | differs |
| 5|2025-02-01 | census | 819 | 933 | differs |
| 5|2025-02-01 | ltc_census | 90 | 101 | differs |
| 5|2025-02-01 | alos | 55.0536731786732 | 5.13216560509555 | differs |
| 5|2025-02-01 | ltc_alos | 472.127314814815 | 156.689141414141 | differs |
| 5|2025-02-01 | non_ltc_alos | 3.56310013717421 | 2.97825509618146 | differs |
| 5|2025-02-01 | total_bed_nights | 3921 | 3537 | differs |
| 5|2025-02-01 | available_bed_nights | 5684 | 6636 | differs |
| 5|2025-02-01 | occupancy_rate | 0.689831104855735 | 0.533001808318264 | differs |
| 6|2025-02-01 | available_beds | 209 | 138 | differs |
| 6|2025-02-01 | census | 152 | 163 | differs |
| 6|2025-02-01 | alos | 44.0233004385965 | 9.51257008154943 | differs |
| 6|2025-02-01 | ltc_alos | 113.767156862745 | 43.4032738095238 | differs |
| 6|2025-02-01 | non_ltc_alos | 8.80610561056105 | 7.18673747276688 | differs |
| 6|2025-02-01 | total_bed_nights | 1462 | 1356 | differs |
| 6|2025-02-01 | available_bed_nights | 5852 | 3872 | differs |
| 6|2025-02-01 | occupancy_rate | 0.249829118250171 | 0.350206611570248 | differs |
| 6|2025-01-01 | available_beds | 209 | 138 | differs |
| 6|2025-01-01 | census | 188 | 198 | differs |
| 6|2025-01-01 | alos | 26.4696365248227 | 7.17312119482496 | differs |
| 6|2025-01-01 | ltc_alos | 130.630952380952 | 37.2400462962963 | differs |
| 6|2025-01-01 | non_ltc_alos | 8.24140625 | 6.54234654234654 | differs |
| 6|2025-01-01 | total_bed_nights | 1505 | 1459 | differs |
| 6|2025-01-01 | available_bed_nights | 6479 | 4284 | differs |
| 6|2025-01-01 | occupancy_rate | 0.232288933477388 | 0.340569561157796 | differs |
| 5|2025-05-01 | available_beds | 203 | 217 | differs |
| 5|2025-05-01 | census | 622 | 723 | differs |
| 5|2025-05-01 | ltc_census | 95 | 107 | differs |
| 5|2025-05-01 | alos | 77.623258306538 | 3.72819540727903 | differs |
| 5|2025-05-01 | ltc_alos | 492.976315789474 | 132.038541666667 | differs |
| 5|2025-05-01 | non_ltc_alos | 2.74936748893106 | 2.37992556917689 | differs |
| 5|2025-05-01 | total_bed_nights | 3530 | 2643 | differs |
| 5|2025-05-01 | available_bed_nights | 6293 | 6735 | differs |
| 5|2025-05-01 | occupancy_rate | 0.560940727792786 | 0.392427616926503 | differs |
| 4|2025-09-01 | available_beds | 244 | 284 | differs |
| 4|2025-09-01 | census | 740 | 1041 | differs |
| 4|2025-09-01 | ltc_census | 74 | 294 | differs |
| 4|2025-09-01 | alos | 73.3085585585586 | 8.61532631954351 | differs |
| 4|2025-09-01 | ltc_alos | 713.054054054054 | 585.462760416667 | differs |
| 4|2025-09-01 | non_ltc_alos | 2.22572572572573 | 1.95619288119288 | differs |
| 4|2025-09-01 | total_bed_nights | 3138 | 3105 | differs |
| 4|2025-09-01 | available_bed_nights | 7320 | 8508 | differs |
| 4|2025-09-01 | occupancy_rate | 0.428688524590164 | 0.364950634696756 | differs |
| 5|2025-10-01 | available_beds | 203 | 206 | differs |
| 5|2025-10-01 | census | 889 | 1008 | differs |
| 5|2025-10-01 | ltc_census | 128 | 130 | differs |
| 5|2025-10-01 | alos | 58.2273153355831 | 2.93473585548738 | differs |
| 5|2025-10-01 | ltc_alos | 386.3271484375 | 134.832986111111 | differs |
| 5|2025-10-01 | non_ltc_alos | 3.04100963644328 | 2.61026291512915 | differs |
| 5|2025-10-01 | total_bed_nights | 5357 | 3198 | differs |
| 5|2025-10-01 | available_bed_nights | 6293 | 6372 | differs |
| 5|2025-10-01 | occupancy_rate | 0.851263308437947 | 0.501883239171375 | differs |
| 6|2025-05-01 | available_beds | 209 | 146 | differs |
| 6|2025-05-01 | census | 227 | 246 | differs |
| 6|2025-05-01 | alos | 52.7586270190896 | 10.4817933006536 | differs |
| 6|2025-05-01 | ltc_alos | 164.367307692308 | 53.5963541666667 | differs |
| 6|2025-05-01 | non_ltc_alos | 7.97736625514403 | 6.00235840548341 | differs |
| 6|2025-05-01 | total_bed_nights | 2299 | 1626 | differs |
| 6|2025-05-01 | available_bed_nights | 6479 | 4511 | differs |
| 6|2025-05-01 | occupancy_rate | 0.354838709677419 | 0.360452227887386 | differs |
| 6|2026-08-01 | available_beds | 209 | 192 | differs |
| 6|2026-08-01 | census | 454 | 480 | differs |
| 6|2026-08-01 | alos | 26.2838656387665 | 4.457757885763 | differs |
| 6|2026-08-01 | ltc_alos | 185.067708333333 | 80.2116898148148 | differs |
| 6|2026-08-01 | non_ltc_alos | 3.94242043551089 | 3.27717712842713 | differs |
| 6|2026-08-01 | total_bed_nights | 2735 | 2782 | differs |
| 6|2026-08-01 | available_bed_nights | 6479 | 5949 | differs |
| 6|2026-08-01 | occupancy_rate | 0.422133045223028 | 0.46764162044041 | differs |
| 3|2026-08-01 | available_beds | 235 | 247 | differs |
| 3|2026-08-01 | census | 1351 | 1548 | differs |
| 3|2026-08-01 | ltc_census | 141 | 142 | differs |
| 3|2026-08-01 | alos | 27.8101714779176 | 4.42257898210014 | differs |
| 3|2026-08-01 | ltc_alos | 239.015661938534 | 87.9346420940171 | differs |
| 3|2026-08-01 | non_ltc_alos | 3.19862258953168 | 2.77888962486332 | differs |
| 3|2026-08-01 | total_bed_nights | 6570 | 6135 | differs |
| 3|2026-08-01 | available_bed_nights | 7285 | 7672 | differs |
| 3|2026-08-01 | occupancy_rate | 0.901853122855182 | 0.79966110531804 | differs |
| 6|2025-06-01 | available_beds | 209 | 146 | differs |
| 6|2025-06-01 | census | 336 | 362 | differs |
| 6|2025-06-01 | alos | 40.4568452380952 | 7.60667571306939 | differs |
| 6|2025-06-01 | ltc_alos | 160.828828828829 | 60.9008207070707 | differs |
| 6|2025-06-01 | non_ltc_alos | 6.45865139949109 | 5.26173333333333 | differs |
| 6|2025-06-01 | total_bed_nights | 2720 | 1951 | differs |
| 6|2025-06-01 | available_bed_nights | 6270 | 4384 | differs |
| 6|2025-06-01 | occupancy_rate | 0.433811802232855 | 0.445027372262774 | differs |
| 2|2026-09-01 | available_beds | 249 | 276 | differs |
| 2|2026-09-01 | census | 1023 | 1131 | differs |
| 2|2026-09-01 | ltc_census | 244 | 304 | differs |
| 2|2026-09-01 | alos | 18.5708292603454 | 4.30641369562709 | differs |
| 2|2026-09-01 | ltc_alos | 68.3982240437159 | 11.1008333333333 | differs |
| 2|2026-09-01 | non_ltc_alos | 2.96378904578519 | 2.41155562933452 | differs |
| 2|2026-09-01 | total_bed_nights | 4442 | 4495 | differs |
| 2|2026-09-01 | available_bed_nights | 7470 | 8282 | differs |
| 2|2026-09-01 | occupancy_rate | 0.594645247657296 | 0.542743298720116 | differs |
| 1|2025-09-01 | available_beds | 462 | 451 | differs |
| 1|2025-09-01 | census | 952 | 1009 | differs |
| 1|2025-09-01 | alos | 197.757571778712 | 8.01007930576316 | differs |
| 1|2025-09-01 | ltc_alos | 640.960051546392 | 278.025297619048 | differs |
| 1|2025-09-01 | non_ltc_alos | 2.64120020171457 | 2.23876166242579 | differs |
| 1|2025-09-01 | total_bed_nights | 9301 | 9570 | differs |
| 1|2025-09-01 | available_bed_nights | 13860 | 13530 | differs |
| 1|2025-09-01 | occupancy_rate | 0.671067821067821 | 0.707317073170732 | differs |
| 3|2025-02-01 | available_beds | 235 | 237 | differs |
| 3|2025-02-01 | census | 1206 | 1337 | differs |
| 3|2025-02-01 | ltc_census | 98 | 99 | differs |
| 3|2025-02-01 | alos | 24.1096945826423 | 3.30246281437687 | differs |
| 3|2025-02-01 | ltc_alos | 265.71556122449 | 60.8283680555556 | differs |
| 3|2025-02-01 | non_ltc_alos | 2.74022262334537 | 2.31404519854906 | differs |
| 3|2025-02-01 | total_bed_nights | 4309 | 3807 | differs |
| 3|2025-02-01 | available_bed_nights | 6580 | 6624 | differs |
| 3|2025-02-01 | occupancy_rate | 0.654863221884499 | 0.574728260869565 | differs |
| 4|2025-04-01 | census | 682 | 973 | differs |
| 4|2025-04-01 | ltc_census | 66 | 287 | differs |
| 4|2025-04-01 | alos | 78.8938172043011 | 3.00937333864965 | differs |
| 4|2025-04-01 | ltc_alos | 794.022095959596 | 208.855787037037 | differs |
| 4|2025-04-01 | non_ltc_alos | 2.27293019480519 | 2.01972711894587 | differs |
| 4|2025-04-01 | total_bed_nights | 2956 | 2704 | differs |
| 4|2025-04-01 | available_bed_nights | 7320 | 7359 | differs |
| 4|2025-04-01 | occupancy_rate | 0.403825136612022 | 0.367441228427775 | differs |
| 2|2025-08-01 | available_beds | 249 | 312 | differs |
| 2|2025-08-01 | census | 997 | 1053 | differs |
| 2|2025-08-01 | ltc_census | 133 | 134 | differs |
| 2|2025-08-01 | alos | 35.2066198595787 | 4.18626398646891 | differs |
| 2|2025-08-01 | ltc_alos | 242.832393483709 | 80.1033333333333 | differs |
| 2|2025-08-01 | non_ltc_alos | 3.24570794753086 | 2.82898622698981 | differs |
| 2|2025-08-01 | total_bed_nights | 5698 | 5610 | differs |
| 2|2025-08-01 | available_bed_nights | 7719 | 9672 | differs |
| 2|2025-08-01 | occupancy_rate | 0.738178520533748 | 0.580024813895782 | differs |
| 5|2025-06-01 | available_beds | 203 | 218 | differs |
| 5|2025-06-01 | census | 665 | 789 | differs |
| 5|2025-06-01 | ltc_census | 105 | 117 | differs |
| 5|2025-06-01 | alos | 74.7962406015038 | 3.47555143872421 | differs |
| 5|2025-06-01 | ltc_alos | 458.903571428571 | 101.923958333333 | differs |
| 5|2025-06-01 | non_ltc_alos | 2.77611607142857 | 2.23133776549061 | differs |
| 5|2025-06-01 | total_bed_nights | 4014 | 2823 | differs |
| 5|2025-06-01 | available_bed_nights | 6090 | 6526 | differs |
| 5|2025-06-01 | occupancy_rate | 0.659113300492611 | 0.432577382776586 | differs |
| 7|2026-09-01 | available_beds | 128 | 127 | differs |
| 7|2026-09-01 | census | 326 | 361 | differs |
| 7|2026-09-01 | ltc_census | 65 | 68 | differs |
| 7|2026-09-01 | alos | 3.10288854805726 | 2.18087542087542 | differs |
| 7|2026-09-01 | ltc_alos | 6.17051282051282 | 2.5116711469534 | differs |
| 7|2026-09-01 | non_ltc_alos | 2.33892081736909 | 2.10434805140962 | differs |
| 7|2026-09-01 | available_bed_nights | 3840 | 3810 | differs |
| ... | 533 more | | | |

## vw_rcm

Keys (hospital_id, period): old 88, new 88. Differences: 900.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 5|2025-06-01 | total_submitted_claims | 13012469.2500004 | 13278111.81 | differs |
| 5|2025-06-01 | not_submitted_claims | 259710.13 | 351404.31 | differs |
| 5|2025-06-01 | approved_amount | 10947421.6000001 | 10644651.48 | differs |
| 5|2025-06-01 | rejections | 2065047.64999999 | 2089743.52 | differs |
| 5|2025-06-01 | rejection_rate_pct | 15.87 | 14.53 | differs |
| 5|2025-06-01 | approval_rate_pct | 84.13 | 74.02 | differs |
| 5|2025-06-01 | total_orders | 9131 | 13393 | differs |
| 5|2025-06-01 | approved_orders | 6898 | 7376 | differs |
| 5|2025-06-01 | approved_not_done | 1626 | 1945 | differs |
| 5|2025-06-01 | approved_not_done_pct | 17.81 | 14.52 | differs |
| 5|2025-06-01 | avg_tat_minutes | 32.1 | 73.2 | differs |
| 6|2025-10-01 | not_submitted_claims | 28967.12 | 6860.28 | differs |
| 6|2025-10-01 | approved_amount | 9388807.13999993 | 8148589.41999999 | differs |
| 6|2025-10-01 | rejections | 437062.76 | 2038681.56 | differs |
| 6|2025-10-01 | rejection_rate_pct | 4.45 | 18.23 | differs |
| 6|2025-10-01 | approval_rate_pct | 95.55 | 72.88 | differs |
| 6|2025-10-01 | total_orders | 4688 | 6560 | differs |
| 6|2025-10-01 | approved_orders | 3547 | 3662 | differs |
| 6|2025-10-01 | approved_not_done | 1083 | 1292 | differs |
| 6|2025-10-01 | approved_not_done_pct | 23.1 | 19.7 | differs |
| 6|2025-10-01 | avg_tat_minutes | 39.9 | 90.9 | differs |
| 8|2026-08-01 | not_submitted_claims | 0 | 23746.02 | differs |
| 8|2026-08-01 | approved_amount | 23746.02 | 0 | differs |
| 8|2026-08-01 | approval_rate_pct | 100 | 0 | differs |
| 8|2026-08-01 | total_orders | 52 | 194 | differs |
| 8|2026-08-01 | approved_orders | 28 | 29 | differs |
| 8|2026-08-01 | approved_not_done | 11 | 13 | differs |
| 8|2026-08-01 | approved_not_done_pct | 21.15 | 6.7 | differs |
| 8|2026-08-01 | avg_tat_minutes | 39.3 | 52.9 | differs |
| 6|2025-09-01 | total_submitted_claims | 9465318.33999994 | 9824412.45999988 | differs |
| 6|2025-09-01 | not_submitted_claims | 1198.4 | 312660.2 | differs |
| 6|2025-09-01 | approved_amount | 9245407.72999994 | 7672116.8499999 | differs |
| 6|2025-09-01 | rejections | 219910.61 | 1985228.28999999 | differs |
| 6|2025-09-01 | rejection_rate_pct | 2.32 | 18.38 | differs |
| 6|2025-09-01 | approval_rate_pct | 97.68 | 71.02 | differs |
| 6|2025-09-01 | total_orders | 3502 | 5165 | differs |
| 6|2025-09-01 | approved_orders | 2716 | 2743 | differs |
| 6|2025-09-01 | approved_not_done | 890 | 1013 | differs |
| 6|2025-09-01 | approved_not_done_pct | 25.41 | 19.61 | differs |
| 6|2025-09-01 | avg_tat_minutes | 49 | 106.9 | differs |
| 6|2026-09-01 | not_submitted_claims | 439018.070000001 | 1515317.25 | differs |
| 6|2026-09-01 | approved_amount | 1535356.81 | 0 | differs |
| 6|2026-09-01 | approval_rate_pct | 100 | 0 | differs |
| 6|2026-09-01 | total_orders | 5258 | 10114 | differs |
| 6|2026-09-01 | approved_orders | 3709 | 3682 | differs |
| 6|2026-09-01 | approved_not_done | 983 | 1074 | differs |
| 6|2026-09-01 | approved_not_done_pct | 18.7 | 10.62 | differs |
| 6|2026-09-01 | avg_tat_minutes | 36.7 | 70.2 | differs |
| 1|2025-07-01 | total_submitted_claims | 14411909.0199998 | 14696414.1199998 | differs |
| 1|2025-07-01 | not_submitted_claims | 56092.62 | 82359.5599999999 | differs |
| 1|2025-07-01 | approved_amount | 12613102.3599998 | 12387626.9799997 | differs |
| 1|2025-07-01 | rejections | 1798807.88000001 | 1651618.31000001 | differs |
| 1|2025-07-01 | rejection_rate_pct | 12.48 | 10.36 | differs |
| 1|2025-07-01 | approval_rate_pct | 87.52 | 77.73 | differs |
| 1|2025-07-01 | total_orders | 16792 | 27826 | differs |
| 1|2025-07-01 | approved_orders | 12686 | 14690 | differs |
| 1|2025-07-01 | approved_not_done | 3018 | 3881 | differs |
| 1|2025-07-01 | approved_not_done_pct | 17.97 | 13.95 | differs |
| 1|2025-07-01 | avg_tat_minutes | 42.6 | 68 | differs |
| 2|2025-01-01 | not_submitted_claims | 50772.11 | 37575.02 | differs |
| 2|2025-01-01 | approved_amount | 4544842.70999999 | 4488975.19000005 | differs |
| 2|2025-01-01 | rejections | 2368147.10999995 | 1901224.38000004 | differs |
| 2|2025-01-01 | rejection_rate_pct | 34.26 | 26.55 | differs |
| 2|2025-01-01 | approval_rate_pct | 65.74 | 62.69 | differs |
| 2|2025-01-01 | total_orders | 17514 | 30107 | differs |
| 2|2025-01-01 | approved_orders | 12860 | 14031 | differs |
| 2|2025-01-01 | approved_not_done | 2997 | 3408 | differs |
| 2|2025-01-01 | approved_not_done_pct | 17.11 | 11.32 | differs |
| 2|2025-01-01 | avg_tat_minutes | 29.4 | 66.7 | differs |
| 1|2025-05-01 | total_submitted_claims | 15053524.2500008 | 15579635.5300005 | differs |
| 1|2025-05-01 | not_submitted_claims | 268355.33 | 294693.64 | differs |
| 1|2025-05-01 | approved_amount | 13359950.0600008 | 12953354.7500003 | differs |
| 1|2025-05-01 | rejections | 1693574.34999999 | 1651622.62999999 | differs |
| 1|2025-05-01 | rejection_rate_pct | 11.25 | 10.01 | differs |
| 1|2025-05-01 | approval_rate_pct | 88.75 | 78.47 | differs |
| 1|2025-05-01 | total_orders | 16878 | 27573 | differs |
| 1|2025-05-01 | approved_orders | 12632 | 14786 | differs |
| 1|2025-05-01 | approved_not_done | 2995 | 3802 | differs |
| 1|2025-05-01 | approved_not_done_pct | 17.74 | 13.79 | differs |
| 1|2025-05-01 | avg_tat_minutes | 36.5 | 57.9 | differs |
| 1|2025-06-01 | total_submitted_claims | 13407745.3999997 | 13677873.4799998 | differs |
| 1|2025-06-01 | not_submitted_claims | 13079.13 | 265698.07 | differs |
| 1|2025-06-01 | approved_amount | 11726232.3599997 | 11576148.5399999 | differs |
| 1|2025-06-01 | rejections | 1681513.20000001 | 1639772.38999999 | differs |
| 1|2025-06-01 | rejection_rate_pct | 12.54 | 11 | differs |
| 1|2025-06-01 | approval_rate_pct | 87.46 | 77.66 | differs |
| 1|2025-06-01 | total_orders | 15536 | 24788 | differs |
| 1|2025-06-01 | approved_orders | 11655 | 13820 | differs |
| 1|2025-06-01 | approved_not_done | 2955 | 3704 | differs |
| 1|2025-06-01 | approved_not_done_pct | 19.02 | 14.94 | differs |
| 1|2025-06-01 | avg_tat_minutes | 34.3 | 52.9 | differs |
| 4|2025-12-01 | total_submitted_claims | 17850224.6199997 | 18112267.3599998 | differs |
| 4|2025-12-01 | not_submitted_claims | 37687.45 | 304147.63 | differs |
| 4|2025-12-01 | approved_amount | 15834265.1799997 | 15713263.5699996 | differs |
| 4|2025-12-01 | rejections | 2015959.73000001 | 2047799.11000002 | differs |
| 4|2025-12-01 | rejection_rate_pct | 11.29 | 10.08 | differs |
| 4|2025-12-01 | approval_rate_pct | 88.71 | 77.38 | differs |
| 4|2025-12-01 | total_orders | 19429 | 28742 | differs |
| 4|2025-12-01 | approved_orders | 14014 | 14908 | differs |
| 4|2025-12-01 | approved_not_done | 2618 | 3379 | differs |
| 4|2025-12-01 | approved_not_done_pct | 13.47 | 11.76 | differs |
| 4|2025-12-01 | avg_tat_minutes | 27.1 | 41.4 | differs |
| 3|2025-03-01 | total_submitted_claims | 17732864.4500003 | 7181519.06000009 | differs |
| 3|2025-03-01 | not_submitted_claims | 11677417.3200002 | 1124753.89 | differs |
| 3|2025-03-01 | approved_amount | 15889611.9700003 | 4159767.07000003 | differs |
| 3|2025-03-01 | rejections | 1843252.91 | 1956925.28000002 | differs |
| 3|2025-03-01 | rejection_rate_pct | 10.39 | 28.67 | differs |
| 3|2025-03-01 | approval_rate_pct | 89.61 | 60.95 | differs |
| 3|2025-03-01 | total_orders | 11498 | 15373 | differs |
| 3|2025-03-01 | approved_orders | 8617 | 8389 | differs |
| 3|2025-03-01 | approved_not_done | 1690 | 2085 | differs |
| 3|2025-03-01 | approved_not_done_pct | 14.7 | 13.56 | differs |
| 3|2025-03-01 | avg_tat_minutes | 29.7 | 58.8 | differs |
| 3|2026-08-01 | total_submitted_claims | 34533461.6600029 | 35120773.7700039 | differs |
| 3|2026-08-01 | not_submitted_claims | 587.77 | 721809 | differs |
| 3|2026-08-01 | approved_amount | 26287239.2000006 | 25913006.0000007 | differs |
| 3|2026-08-01 | rejections | 8246223.5199995 | 9469748.52999998 | differs |
| 3|2026-08-01 | rejection_rate_pct | 23.88 | 24.1 | differs |
| 3|2026-08-01 | approval_rate_pct | 76.12 | 65.95 | differs |
| 3|2026-08-01 | total_orders | 17495 | 28094 | differs |
| 3|2026-08-01 | approved_orders | 13830 | 14384 | differs |
| 3|2026-08-01 | approved_not_done | 2326 | 2914 | differs |
| 3|2026-08-01 | approved_not_done_pct | 13.3 | 10.37 | differs |
| 3|2026-08-01 | avg_tat_minutes | 32.5 | 58.5 | differs |
| 4|2025-08-01 | total_submitted_claims | 13159436.97 | 13805359.7999999 | differs |
| 4|2025-08-01 | not_submitted_claims | 3458.26 | 696314.94 | differs |
| 4|2025-08-01 | approved_amount | 12078085.84 | 11580081.7899998 | differs |
| 4|2025-08-01 | rejections | 1081351.37 | 1571302.58999999 | differs |
| 4|2025-08-01 | rejection_rate_pct | 8.22 | 10.51 | differs |
| 4|2025-08-01 | approval_rate_pct | 91.78 | 77.44 | differs |
| 4|2025-08-01 | total_orders | 15243 | 21228 | differs |
| 4|2025-08-01 | approved_orders | 10141 | 10294 | differs |
| 4|2025-08-01 | approved_not_done | 2306 | 2388 | differs |
| 4|2025-08-01 | approved_not_done_pct | 15.13 | 11.25 | differs |
| 4|2025-08-01 | avg_tat_minutes | 26.5 | 47.9 | differs |
| 1|2025-10-01 | total_submitted_claims | 17560139.7099999 | 17859306.8499998 | differs |
| 1|2025-10-01 | not_submitted_claims | 24594.04 | 178754.53 | differs |
| 1|2025-10-01 | approved_amount | 15769118.8399999 | 15270892.7799999 | differs |
| 1|2025-10-01 | rejections | 1842719.96999999 | 2033650.02 | differs |
| 1|2025-10-01 | rejection_rate_pct | 10.49 | 10.29 | differs |
| 1|2025-10-01 | approval_rate_pct | 89.8 | 77.25 | differs |
| 1|2025-10-01 | total_orders | 18725 | 33222 | differs |
| 1|2025-10-01 | approved_orders | 14430 | 17153 | differs |
| 1|2025-10-01 | approved_not_done | 3802 | 4756 | differs |
| 1|2025-10-01 | approved_not_done_pct | 20.3 | 14.32 | differs |
| 1|2025-10-01 | avg_tat_minutes | 36 | 49.8 | differs |
| 1|2025-09-01 | total_submitted_claims | 14911107.4899993 | 15452252.9499996 | differs |
| 1|2025-09-01 | not_submitted_claims | 57196.26 | 573406.260000001 | differs |
| 1|2025-09-01 | approved_amount | 13129438.2099994 | 12754173.3099998 | differs |
| 1|2025-09-01 | rejections | 1801132.76000001 | 1757477.96000001 | differs |
| 1|2025-09-01 | rejection_rate_pct | 12.08 | 10.64 | differs |
| 1|2025-09-01 | approval_rate_pct | 88.05 | 77.23 | differs |
| 1|2025-09-01 | total_orders | 17192 | 28944 | differs |
| 1|2025-09-01 | approved_orders | 13265 | 15801 | differs |
| 1|2025-09-01 | approved_not_done | 3413 | 3916 | differs |
| 1|2025-09-01 | approved_not_done_pct | 19.85 | 13.53 | differs |
| 1|2025-09-01 | avg_tat_minutes | 40.4 | 53.6 | differs |
| 1|2026-09-01 | not_submitted_claims | 1570233.09999999 | 8092422.89999967 | differs |
| 1|2026-09-01 | approved_amount | 8424842.3900001 | 53613.72 | differs |
| 1|2026-09-01 | rejections | 16719.45 | 17609.8 | differs |
| 1|2026-09-01 | rejection_rate_pct | 0.2 | 24.01 | differs |
| 1|2026-09-01 | approval_rate_pct | 99.8 | 73.09 | differs |
| 1|2026-09-01 | total_orders | 26221 | 39707 | differs |
| 1|2026-09-01 | approved_orders | 19046 | 22077 | differs |
| 1|2026-09-01 | approved_not_done | 3807 | 5180 | differs |
| 1|2026-09-01 | approved_not_done_pct | 14.52 | 13.05 | differs |
| 1|2026-09-01 | avg_tat_minutes | 35.8 | 50.2 | differs |
| 6|2025-07-01 | not_submitted_claims | 280 | 16700.34 | differs |
| 6|2025-07-01 | rejections | 1378027.91 | 1460475.07 | differs |
| 6|2025-07-01 | rejection_rate_pct | 14.08 | 13.09 | differs |
| 6|2025-07-01 | approval_rate_pct | 85.92 | 75.43 | differs |
| 6|2025-07-01 | total_orders | 3017 | 4518 | differs |
| 6|2025-07-01 | approved_orders | 2289 | 2090 | differs |
| 6|2025-07-01 | approved_not_done | 615 | 772 | differs |
| 6|2025-07-01 | approved_not_done_pct | 20.38 | 17.09 | differs |
| 6|2025-07-01 | avg_tat_minutes | 51.5 | 110.6 | differs |
| 6|2025-05-01 | not_submitted_claims | 309.31 | 891.62 | differs |
| 6|2025-05-01 | rejections | 284299.39 | 322133.67 | differs |
| 6|2025-05-01 | rejection_rate_pct | 4.26 | 4.21 | differs |
| 6|2025-05-01 | approval_rate_pct | 95.74 | 83.52 | differs |
| 6|2025-05-01 | total_orders | 1807 | 2240 | differs |
| 6|2025-05-01 | approved_orders | 1504 | 1156 | differs |
| 6|2025-05-01 | approved_not_done | 333 | 331 | differs |
| 6|2025-05-01 | approved_not_done_pct | 18.43 | 14.78 | differs |
| 6|2025-05-01 | avg_tat_minutes | 80.9 | 142.1 | differs |
| 5|2025-01-01 | total_submitted_claims | 6078477.63000002 | 6253507.56999994 | differs |
| 5|2025-01-01 | not_submitted_claims | 548496.04 | 335407.77 | differs |
| 5|2025-01-01 | approved_amount | 4576746.71000004 | 4033967.38000004 | differs |
| 5|2025-01-01 | rejections | 1501731.01000001 | 1451807.93000002 | differs |
| 5|2025-01-01 | rejection_rate_pct | 24.71 | 24.24 | differs |
| 5|2025-01-01 | approval_rate_pct | 75.29 | 67.36 | differs |
| 5|2025-01-01 | total_orders | 11011 | 17108 | differs |
| 5|2025-01-01 | approved_orders | 8765 | 8857 | differs |
| 5|2025-01-01 | approved_not_done | 2328 | 2573 | differs |
| 5|2025-01-01 | approved_not_done_pct | 21.14 | 15.04 | differs |
| 5|2025-01-01 | avg_tat_minutes | 35.7 | 57.4 | differs |
| 3|2025-12-01 | total_submitted_claims | 27804646.9500017 | 28124480.0500006 | differs |
| 3|2025-12-01 | not_submitted_claims | 2801.75 | 415955.35 | differs |
| 3|2025-12-01 | approved_amount | 25209346.2400004 | 24688903.9099998 | differs |
| 3|2025-12-01 | rejections | 2854401.69999998 | 2758600.61000002 | differs |
| ... | 700 more | | | |

## vw_work_force

Keys (branch_id, period): old 112, new 112. Differences: 318.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 4|2026-08-01 | headcount | 623 | 631 | differs |
| 4|2026-08-01 | doctors_headcount | 136 | 137 | differs |
| 4|2026-08-01 | pt_doctors_headcount | 48 | 17 | differs |
| 4|2026-08-01 | FTE | 599 | 622.5 | differs |
| 5|2026-08-01 | headcount | 567 | 563 | differs |
| 5|2026-08-01 | medical_headcount | 358 | 354 | differs |
| 5|2026-08-01 | doctors_headcount | 130 | 129 | differs |
| 5|2026-08-01 | FTE | 549 | 545 | differs |
| 5|2025-08-01 | headcount | 552 | 563 | differs |
| 5|2025-08-01 | medical_headcount | 373 | 381 | differs |
| 5|2025-08-01 | pt_doctors_headcount | 34 | 33 | differs |
| 5|2025-08-01 | FTE | 535 | 546.5 | differs |
| 6|2025-12-01 | headcount | 422 | 414 | differs |
| 6|2025-12-01 | resignations | 2 | 0 | differs |
| 6|2025-12-01 | medical_headcount | 310 | 306 | differs |
| 6|2025-12-01 | doctors_headcount | 126 | 124 | differs |
| 6|2025-12-01 | FTE | 391 | 383 | differs |
| 7|2025-12-01 | headcount | 2 | 1 | differs |
| 7|2025-12-01 | FTE | 1.5 | 0.5 | differs |
| 1|2025-04-01 | headcount | 881 | 903 | differs |
| 1|2025-04-01 | medical_headcount | 578 | 587 | differs |
| 1|2025-04-01 | doctors_headcount | 154 | 155 | differs |
| 1|2025-04-01 | pt_doctors_headcount | 34 | 33 | differs |
| 1|2025-04-01 | FTE | 864 | 886.5 | differs |
| 2|2025-06-01 | headcount | 703 | 710 | differs |
| 2|2025-06-01 | FTE | 675 | 682 | differs |
| 4|2025-12-01 | doctors_headcount | 112 | 113 | differs |
| 7|2026-08-01 | headcount | 308 | 322 | differs |
| 7|2026-08-01 | resignations | 11 | 12 | differs |
| 7|2026-08-01 | medical_headcount | 226 | 232 | differs |
| 7|2026-08-01 | doctors_headcount | 103 | 107 | differs |
| 7|2026-08-01 | pt_doctors_headcount | 13 | 15 | differs |
| 7|2026-08-01 | FTE | 301.5 | 314.5 | differs |
| 6|2025-04-01 | resignations | 1 | 0 | differs |
| 5|2025-06-01 | headcount | 538 | 544 | differs |
| 5|2025-06-01 | medical_headcount | 367 | 370 | differs |
| 5|2025-06-01 | pt_doctors_headcount | 25 | 23 | differs |
| 5|2025-06-01 | FTE | 525.5 | 532.5 | differs |
| 1|2025-12-01 | headcount | 1010 | 966 | differs |
| 1|2025-12-01 | medical_headcount | 626 | 630 | differs |
| 1|2025-12-01 | doctors_headcount | 167 | 170 | differs |
| 1|2025-12-01 | pt_doctors_headcount | 46 | 45 | differs |
| 1|2025-12-01 | FTE | 987 | 943.5 | differs |
| 2|2025-08-01 | headcount | 697 | 709 | differs |
| 2|2025-08-01 | medical_headcount | 487 | 496 | differs |
| 2|2025-08-01 | FTE | 669.5 | 681.5 | differs |
| 2|2026-08-01 | headcount | 705 | 652 | differs |
| 2|2026-08-01 | medical_headcount | 490 | 445 | differs |
| 2|2026-08-01 | doctors_headcount | 145 | 141 | differs |
| 2|2026-08-01 | pt_doctors_headcount | 53 | 52 | differs |
| 2|2026-08-01 | FTE | 678.5 | 626 | differs |
| 4|2025-04-01 | headcount | 527 | 534 | differs |
| 4|2025-04-01 | medical_headcount | 373 | 380 | differs |
| 4|2025-04-01 | doctors_headcount | 106 | 107 | differs |
| 4|2025-04-01 | pt_doctors_headcount | 28 | 27 | differs |
| 4|2025-04-01 | FTE | 513 | 520.5 | differs |
| 3|2026-09-01 | headcount | 758 | 766 | differs |
| 3|2026-09-01 | medical_headcount | 500 | 526 | differs |
| 3|2026-09-01 | doctors_headcount | 159 | 156 | differs |
| 3|2026-09-01 | pt_doctors_headcount | 59 | 69 | differs |
| 1|2026-09-01 | headcount | 948 | 1034 | differs |
| 1|2026-09-01 | medical_headcount | 637 | 667 | differs |
| 1|2026-09-01 | doctors_headcount | 194 | 183 | differs |
| 1|2026-09-01 | pt_doctors_headcount | 51 | 45 | differs |
| 1|2026-09-01 | FTE | 922.5 | 1011.5 | differs |
| 1|2025-07-01 | headcount | 872 | 885 | differs |
| 1|2025-07-01 | medical_headcount | 587 | 593 | differs |
| 1|2025-07-01 | FTE | 853.5 | 866.5 | differs |
| 2|2025-05-01 | headcount | 701 | 706 | differs |
| 2|2025-05-01 | medical_headcount | 498 | 502 | differs |
| 2|2025-05-01 | doctors_headcount | 154 | 155 | differs |
| 2|2025-05-01 | pt_doctors_headcount | 56 | 55 | differs |
| 2|2025-05-01 | FTE | 673 | 678.5 | differs |
| 6|2026-09-01 | headcount | 441 | 475 | differs |
| 6|2026-09-01 | resignations | 0 | 2 | differs |
| 6|2026-09-01 | medical_headcount | 351 | 361 | differs |
| 6|2026-09-01 | doctors_headcount | 151 | 160 | differs |
| 6|2026-09-01 | pt_doctors_headcount | 68 | 60 | differs |
| 6|2026-09-01 | FTE | 407 | 445 | differs |
| 6|2025-07-01 | headcount | 337 | 343 | differs |
| 6|2025-07-01 | medical_headcount | 241 | 244 | differs |
| 6|2025-07-01 | doctors_headcount | 120 | 121 | differs |
| 6|2025-07-01 | FTE | 307 | 313 | differs |
| 5|2025-05-01 | headcount | 526 | 538 | differs |
| 5|2025-05-01 | medical_headcount | 355 | 360 | differs |
| 5|2025-05-01 | doctors_headcount | 106 | 109 | differs |
| 5|2025-05-01 | pt_doctors_headcount | 20 | 21 | differs |
| 5|2025-05-01 | FTE | 516 | 527.5 | differs |
| 8|2026-08-01 | headcount | 38 | 146 | differs |
| 8|2026-08-01 | resignations | 0 | 1 | differs |
| 8|2026-08-01 | medical_headcount | 37 | 122 | differs |
| 8|2026-08-01 | doctors_headcount | 37 | 87 | differs |
| 8|2026-08-01 | pt_doctors_headcount | 37 | 8 | differs |
| 8|2026-08-01 | FTE | 19.5 | 142 | differs |
| 4|2026-09-01 | medical_headcount | 412 | 418 | differs |
| 4|2026-09-01 | doctors_headcount | 128 | 133 | differs |
| 4|2026-09-01 | pt_doctors_headcount | 43 | 14 | differs |
| 4|2026-09-01 | FTE | 578.5 | 591 | differs |
| 4|2025-07-01 | medical_headcount | 377 | 382 | differs |
| 4|2025-07-01 | pt_doctors_headcount | 21 | 20 | differs |
| 4|2025-09-01 | medical_headcount | 374 | 383 | differs |
| 4|2025-09-01 | doctors_headcount | 101 | 102 | differs |
| 4|2025-09-01 | pt_doctors_headcount | 23 | 22 | differs |
| 3|2025-11-01 | doctors_headcount | 146 | 145 | differs |
| 2|2025-10-01 | headcount | 716 | 728 | differs |
| 2|2025-10-01 | medical_headcount | 485 | 496 | differs |
| 2|2025-10-01 | doctors_headcount | 145 | 150 | differs |
| 2|2025-10-01 | FTE | 689.5 | 701.5 | differs |
| 1|2025-11-01 | headcount | 958 | 969 | differs |
| 1|2025-11-01 | medical_headcount | 597 | 604 | differs |
| 1|2025-11-01 | doctors_headcount | 158 | 159 | differs |
| 1|2025-11-01 | FTE | 937 | 948 | differs |
| 5|2025-03-01 | headcount | 519 | 531 | differs |
| 5|2025-03-01 | FTE | 507 | 519 | differs |
| 6|2025-09-01 | headcount | 366 | 376 | differs |
| 6|2025-09-01 | resignations | 1 | 0 | differs |
| 6|2025-09-01 | medical_headcount | 266 | 270 | differs |
| 6|2025-09-01 | doctors_headcount | 117 | 118 | differs |
| 6|2025-09-01 | FTE | 337.5 | 347.5 | differs |
| 6|2025-11-01 | headcount | 406 | 412 | differs |
| 6|2025-11-01 | resignations | 1 | 0 | differs |
| 6|2025-11-01 | medical_headcount | 294 | 299 | differs |
| 6|2025-11-01 | doctors_headcount | 130 | 131 | differs |
| 6|2025-11-01 | FTE | 372 | 378 | differs |
| 2|2025-03-01 | headcount | 695 | 704 | differs |
| 2|2025-03-01 | medical_headcount | 499 | 503 | differs |
| 2|2025-03-01 | doctors_headcount | 158 | 159 | differs |
| 2|2025-03-01 | FTE | 665 | 674 | differs |
| 1|2025-09-01 | headcount | 903 | 930 | differs |
| 1|2025-09-01 | medical_headcount | 586 | 604 | differs |
| 1|2025-09-01 | doctors_headcount | 151 | 154 | differs |
| 1|2025-09-01 | pt_doctors_headcount | 33 | 32 | differs |
| 1|2025-09-01 | FTE | 886.5 | 914 | differs |
| 3|2025-09-01 | headcount | 687 | 697 | differs |
| 3|2025-09-01 | medical_headcount | 429 | 433 | differs |
| 3|2025-09-01 | doctors_headcount | 144 | 145 | differs |
| 3|2025-09-01 | FTE | 659.5 | 669.5 | differs |
| 4|2025-11-01 | headcount | 584 | 572 | differs |
| 4|2025-11-01 | doctors_headcount | 106 | 107 | differs |
| 4|2025-11-01 | pt_doctors_headcount | 28 | 29 | differs |
| 4|2025-11-01 | FTE | 570 | 557.5 | differs |
| 1|2025-01-01 | headcount | 868 | 877 | differs |
| 1|2025-01-01 | medical_headcount | 562 | 565 | differs |
| 1|2025-01-01 | FTE | 852 | 861 | differs |
| 5|2025-02-01 | headcount | 504 | 513 | differs |
| 5|2025-02-01 | medical_headcount | 327 | 334 | differs |
| 5|2025-02-01 | doctors_headcount | 105 | 106 | differs |
| 5|2025-02-01 | FTE | 491 | 500 | differs |
| 3|2025-01-01 | headcount | 624 | 661 | differs |
| 3|2025-01-01 | medical_headcount | 397 | 400 | differs |
| 3|2025-01-01 | doctors_headcount | 137 | 139 | differs |
| 3|2025-01-01 | FTE | 598 | 635 | differs |
| 4|2025-01-01 | headcount | 505 | 530 | differs |
| 4|2025-01-01 | medical_headcount | 350 | 357 | differs |
| 4|2025-01-01 | FTE | 491 | 516 | differs |
| 6|2025-01-01 | medical_headcount | 184 | 185 | differs |
| 6|2025-01-01 | doctors_headcount | 78 | 79 | differs |
| 2|2025-02-01 | headcount | 725 | 731 | differs |
| 2|2025-02-01 | pt_doctors_headcount | 62 | 60 | differs |
| 2|2025-02-01 | FTE | 694 | 701 | differs |
| 3|2025-02-01 | headcount | 648 | 655 | differs |
| 3|2025-02-01 | medical_headcount | 407 | 412 | differs |
| 3|2025-02-01 | doctors_headcount | 137 | 139 | differs |
| 3|2025-02-01 | FTE | 623 | 630 | differs |
| 1|2025-02-01 | headcount | 867 | 876 | differs |
| 1|2025-02-01 | medical_headcount | 564 | 570 | differs |
| 1|2025-02-01 | pt_doctors_headcount | 32 | 31 | differs |
| 1|2025-02-01 | FTE | 851 | 860.5 | differs |
| 5|2025-01-01 | headcount | 466 | 473 | differs |
| 5|2025-01-01 | medical_headcount | 290 | 295 | differs |
| 5|2025-01-01 | FTE | 453 | 460 | differs |
| 6|2025-02-01 | medical_headcount | 178 | 179 | differs |
| 6|2025-02-01 | doctors_headcount | 82 | 83 | differs |
| 2|2025-01-01 | headcount | 697 | 744 | differs |
| 2|2025-01-01 | pt_doctors_headcount | 60 | 58 | differs |
| 2|2025-01-01 | FTE | 667 | 715 | differs |
| 8|2025-11-01 | headcount | 0 | 1 | differs |
| 8|2025-11-01 | FTE | 0 | 1 | differs |
| 4|2025-02-01 | headcount | 527 | 536 | differs |
| 4|2025-02-01 | medical_headcount | 377 | 383 | differs |
| 4|2025-02-01 | pt_doctors_headcount | 25 | 24 | differs |
| 4|2025-02-01 | FTE | 514.5 | 524 | differs |
| 5|2025-11-01 | medical_headcount | 352 | 349 | differs |
| 5|2025-11-01 | doctors_headcount | 126 | 127 | differs |
| 6|2025-10-01 | headcount | 383 | 386 | differs |
| 6|2025-10-01 | resignations | 3 | 0 | differs |
| 6|2025-10-01 | medical_headcount | 273 | 276 | differs |
| 6|2025-10-01 | doctors_headcount | 121 | 123 | differs |
| 6|2025-10-01 | pt_doctors_headcount | 59 | 60 | differs |
| 6|2025-10-01 | FTE | 353.5 | 356 | differs |
| 2|2025-09-01 | headcount | 690 | 700 | differs |
| 2|2025-09-01 | medical_headcount | 489 | 495 | differs |
| 2|2025-09-01 | FTE | 660 | 670 | differs |
| 1|2025-03-01 | headcount | 872 | 891 | differs |
| 1|2025-03-01 | medical_headcount | 568 | 579 | differs |
| 1|2025-03-01 | FTE | 856 | 875 | differs |
| 3|2025-03-01 | headcount | 638 | 643 | differs |
| 3|2025-03-01 | medical_headcount | 400 | 403 | differs |
| 3|2025-03-01 | FTE | 615.5 | 620.5 | differs |
| 7|2025-11-01 | headcount | 0 | 1 | differs |
| ... | 118 more | | | |

## vw_income_statement_budget

Keys (branch_id, line_item_code, month_date): old 576, new 576. Differences: 0.

## vw_hospital

Keys (Id, Hospital, City): old 8, new 8. Differences: 2.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 2|Khamis|Asser | * |  |  | missing in new |
| 2|Khamis|Aseer | * |  |  | missing in old |

## vw_date_dim

Keys (Date): old 426, new 426. Differences: 0.

## targets

Keys (hospital_id, period_id, kpi_no, strategy_segment): old 2916, new 2916. Differences: 0.

## patient_satisfaction

Keys (hospital_id, period_id): old 56, new 56. Differences: 0.
