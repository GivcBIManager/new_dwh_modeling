# bsc views: old server against new (generated)

Generated 2026-10-13 12:40 by scripts/compare_bsc.ps1. Months: 2026-08-01, 2026-09-01 and the year 2025. Tolerance: 0.5% relative (absolute below 1). Attribution: docs/reconciliation_bsc.md.

## vw_customer

Keys (branch_id, period): old 89, new 112. Differences: 1414.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 4|2026-08-01 | oasis | non_moh_revenue | 9568303.15 | 9690241.12 | differs |
| 4|2026-08-01 | oasis | insurance_revenue | 7315856.09 | 7460246.12 | differs |
| 4|2026-08-01 | oasis | referrals_revenue | 1012342.35 | 998621.32 | differs |
| 4|2026-08-01 | oasis | new_op_census | 1716 | 1729 | differs |
| 4|2026-08-01 | oasis | op_episodes | 10063 | 9866 | differs |
| 4|2026-08-01 | oasis | er_census | 1771 | 1730 | differs |
| 4|2026-08-01 | oasis | available_slots | 25384 | 24794 | differs |
| 4|2026-08-01 | oasis | op_waiting_time_in_minutes | 358569 | 355644 | differs |
| 4|2026-08-01 | oasis | admissions | 605 | 681 | differs |
| 4|2026-08-01 | oasis | readmission_within_30days | 36 | 35 | differs |
| 4|2026-08-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 3 | differs |
| 4|2026-08-01 | oasis | insurance_admissions | 394 | 411 | differs |
| 4|2026-08-01 | oasis | discharges | 616 | 694 | differs |
| 4|2026-08-01 | oasis | icu_discharge | 78 | 79 | differs |
| 4|2026-08-01 | oasis | alos_non_ltc | 2.72140120415983 | 2.64222161572052 | differs |
| 5|2026-08-01 | oasis | non_moh_revenue | 13366494.58 | 13504139.93 | differs |
| 5|2026-08-01 | oasis | insurance_revenue | 10442116.91 | 10845658.28 | differs |
| 5|2026-08-01 | oasis | referrals_revenue | 671967.97 | 666465.65 | differs |
| 5|2026-08-01 | oasis | credit_revenue | 16193291.55 | 16525306.88 | differs |
| 5|2026-08-01 | oasis | op_episodes | 7308 | 7219 | differs |
| 5|2026-08-01 | oasis | referrals_volume | 250 | 245 | differs |
| 5|2026-08-01 | oasis | available_slots | 22518 | 23842 | differs |
| 5|2026-08-01 | oasis | op_waiting_time_in_minutes | 235713 | 230560 | differs |
| 5|2026-08-01 | oasis | admissions | 823 | 940 | differs |
| 5|2026-08-01 | oasis | readmission_within_30days | 64 | 70 | differs |
| 5|2026-08-01 | oasis | discharges | 841 | 957 | differs |
| 5|2026-08-01 | oasis | icu_discharge | 130 | 128 | differs |
| 5|2026-08-01 | oasis | alos_non_ltc | 2.43008385744235 | 2.31335147578973 | differs |
| 5|2025-08-01 | oasis | insurance_revenue | 7481557.11 | 7625253.64 | differs |
| 5|2025-08-01 | oasis | referrals_revenue | 1008057.11 | 1101738.44 | differs |
| 5|2025-08-01 | oasis | credit_revenue | 14304338.12 | 14457799.9 | differs |
| 5|2025-08-01 | oasis | op_episodes | 6994 | 6741 | differs |
| 5|2025-08-01 | oasis | er_census | 1354 | 1368 | differs |
| 5|2025-08-01 | oasis | available_slots | 20362 | 21010 | differs |
| 5|2025-08-01 | oasis | op_waiting_time_in_minutes | 311740 | 306252 | differs |
| 5|2025-08-01 | oasis | admissions | 647 | 748 | differs |
| 5|2025-08-01 | oasis | readmission_within_30days | 54 | 57 | differs |
| 5|2025-08-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 1 | differs |
| 5|2025-08-01 | oasis | discharges | 615 | 716 | differs |
| 5|2025-08-01 | oasis | icu_discharge | 83 | 81 | differs |
| 5|2025-08-01 | oasis | alos_non_ltc | 2.85178376906318 | 2.67056062022752 | differs |
| 6|2025-12-01 | oasis | non_ltc_ip_revenue | 7851341.55 | 7897033.34 | differs |
| 6|2025-12-01 | oasis | insurance_revenue | 2186224.82 | 2238187.43 | differs |
| 6|2025-12-01 | oasis | referrals_revenue | 802541.07 | 837447.73 | differs |
| 6|2025-12-01 | oasis | high_value_service_revenue | 2607133.04 | 2144027.42 | differs |
| 6|2025-12-01 | oasis | high_value_service_volume | 699 | 677 | differs |
| 6|2025-12-01 | oasis | er_census | 599 | 589 | differs |
| 6|2025-12-01 | oasis | available_slots | 16584 | 16716 | differs |
| 6|2025-12-01 | oasis | admissions | 379 | 399 | differs |
| 6|2025-12-01 | oasis | readmission_within_30days | 15 | 16 | differs |
| 6|2025-12-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 3 | differs |
| 6|2025-12-01 | oasis | discharges | 344 | 364 | differs |
| 6|2025-12-01 | oasis | icu_discharge | 127 | 132 | differs |
| 6|2025-12-01 | oasis | alos_non_ltc | 5.64956940222897 | 5.43193847500796 | differs |
| 7|2025-12-01 | oasis | census | 3 | 0 | differs |
| 7|2025-12-01 | oasis | op_census | 3 | 0 | differs |
| 7|2025-12-01 | oasis | distinct_patients | 3 | 0 | differs |
| 7|2025-12-01 | oasis | new_op_census | 2 | 0 | differs |
| 7|2025-12-01 | oasis | op_episodes | 3 | 0 | differs |
| 7|2025-12-01 | oasis | available_slots | 76 | 0 | differs |
| 7|2025-12-01 | oasis | op_waiting_time_in_minutes | 42 | 0 | differs |
| 3|2025-04-01 | oasis | revenue | 23967573.59 | 24094027.77 | differs |
| 3|2025-04-01 | oasis | non_ltc_ip_revenue | 10703389.99 | 10813812.69 | differs |
| 3|2025-04-01 | oasis | non_moh_revenue | 10647297.17 | 10704753.86 | differs |
| 3|2025-04-01 | oasis | insurance_revenue | 6543455.2 | 6601383.35 | differs |
| 3|2025-04-01 | oasis | referrals_revenue | 1145325.37 | 1158656.92 | differs |
| 3|2025-04-01 | oasis | credit_revenue | 20175813.01 | 20290975.89 | differs |
| 3|2025-04-01 | oasis | high_value_service_revenue | 1819530.22 | 1834168.82 | differs |
| 3|2025-04-01 | oasis | op_episodes | 9981 | 9781 | differs |
| 3|2025-04-01 | oasis | er_census | 1734 | 1723 | differs |
| 3|2025-04-01 | oasis | available_slots | 23244 | 23426 | differs |
| 3|2025-04-01 | oasis | op_waiting_time_in_minutes | 396935 | 334773 | differs |
| 3|2025-04-01 | oasis | admissions | 974 | 1103 | differs |
| 3|2025-04-01 | oasis | readmission_within_30days | 58 | 64 | differs |
| 3|2025-04-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 1 | differs |
| 3|2025-04-01 | oasis | insurance_admissions | 411 | 442 | differs |
| 3|2025-04-01 | oasis | discharges | 939 | 1065 | differs |
| 3|2025-04-01 | oasis | icu_discharge | 47 | 197 | differs |
| 3|2025-04-01 | oasis | alos_non_ltc | 2.48361170977011 | 2.36236493253215 | differs |
| 1|2025-04-01 | oasis | non_ltc_ip_revenue | 5827051.28 | 5937011.5 | differs |
| 1|2025-04-01 | oasis | non_moh_revenue | 10745645.71 | 10921764.97 | differs |
| 1|2025-04-01 | oasis | insurance_revenue | 7600684.12 | 7697538.63 | differs |
| 1|2025-04-01 | oasis | high_value_service_revenue | 2713041.12 | 2744576.97 | differs |
| 1|2025-04-01 | oasis | census | 15499 | 15336 | differs |
| 1|2025-04-01 | oasis | insurance_census | 12338 | 12214 | differs |
| 1|2025-04-01 | oasis | op_census | 13862 | 13755 | differs |
| 1|2025-04-01 | oasis | new_op_census | 1841 | 1827 | differs |
| 1|2025-04-01 | oasis | op_episodes | 10817 | 10476 | differs |
| 1|2025-04-01 | oasis | er_census | 1637 | 1581 | differs |
| 1|2025-04-01 | oasis | available_slots | 25384 | 26722 | differs |
| 1|2025-04-01 | oasis | op_waiting_time_in_minutes | 279455 | 277829 | differs |
| 1|2025-04-01 | oasis | admissions | 536 | 571 | differs |
| 1|2025-04-01 | oasis | readmission_within_30days | 63 | 66 | differs |
| 1|2025-04-01 | oasis | insurance_admissions | 390 | 408 | differs |
| 1|2025-04-01 | oasis | discharges | 526 | 561 | differs |
| 1|2025-04-01 | oasis | icu_discharge | 26 | 25 | differs |
| 1|2025-04-01 | oasis | alos_non_ltc | 2.40034448818898 | 2.38608804838048 | differs |
| 2|2025-06-01 | oasis | non_moh_revenue | 11312388.2 | 11060179.03 | differs |
| 2|2025-06-01 | oasis | insurance_revenue | 7270677.78 | 7401788.91 | differs |
| 2|2025-06-01 | oasis | referrals_revenue | 2168690.91 | 2255004.58 | differs |
| 2|2025-06-01 | oasis | credit_revenue | 22041769.83 | 22389678.48 | differs |
| 2|2025-06-01 | oasis | high_value_service_volume | 1464 | 316 | differs |
| 2|2025-06-01 | oasis | census | 13697 | 3658 | differs |
| 2|2025-06-01 | oasis | insurance_census | 7820 | 1922 | differs |
| 2|2025-06-01 | oasis | op_census | 11774 | 1733 | differs |
| 2|2025-06-01 | oasis | distinct_patients | 8073 | 3159 | differs |
| 2|2025-06-01 | oasis | returning_patients | 3633 | 1095 | differs |
| 2|2025-06-01 | oasis | new_op_census | 1808 | 252 | differs |
| 2|2025-06-01 | oasis | op_episodes | 9428 | 1365 | differs |
| 2|2025-06-01 | oasis | referrals_volume | 1147 | 377 | differs |
| 2|2025-06-01 | oasis | available_slots | 26314 | 4630 | differs |
| 2|2025-06-01 | oasis | op_waiting_time_in_minutes | 214408 | 36078 | differs |
| 2|2025-06-01 | oasis | admissions | 655 | 706 | differs |
| 2|2025-06-01 | oasis | readmission_within_30days | 36 | 41 | differs |
| 2|2025-06-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 3 | differs |
| 2|2025-06-01 | oasis | insurance_admissions | 400 | 411 | differs |
| 2|2025-06-01 | oasis | discharges | 610 | 661 | differs |
| 2|2025-06-01 | oasis | icu_discharge | 57 | 62 | differs |
| 2|2025-06-01 | oasis | alos_non_ltc | 2.92680555555556 | 2.83540279911248 | differs |
| 4|2025-12-01 | oasis | non_moh_revenue | 9704344.32 | 9758453.41 | differs |
| 4|2025-12-01 | oasis | insurance_revenue | 7648095.71 | 7752731.53 | differs |
| 4|2025-12-01 | oasis | referrals_revenue | 1208892.12 | 1217380.2 | differs |
| 4|2025-12-01 | oasis | high_value_service_revenue | 2080852.05 | 2100982.21 | differs |
| 4|2025-12-01 | oasis | op_episodes | 10305 | 10162 | differs |
| 4|2025-12-01 | oasis | er_census | 1107 | 1079 | differs |
| 4|2025-12-01 | oasis | available_slots | 27932 | 27744 | differs |
| 4|2025-12-01 | oasis | op_waiting_time_in_minutes | 285969 | 279700 | differs |
| 4|2025-12-01 | oasis | admissions | 693 | 757 | differs |
| 4|2025-12-01 | oasis | readmission_within_30days | 43 | 40 | differs |
| 4|2025-12-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 1 | differs |
| 4|2025-12-01 | oasis | insurance_admissions | 479 | 500 | differs |
| 4|2025-12-01 | oasis | discharges | 684 | 746 | differs |
| 4|2025-12-01 | oasis | icu_discharge | 92 | 93 | differs |
| 4|2025-12-01 | oasis | alos_non_ltc | 2.44821162444113 | 2.40418561467334 | differs |
| 7|2026-08-01 | oasis | non_moh_revenue | 2478895.7 | 2545789.16 | differs |
| 7|2026-08-01 | oasis | insurance_revenue | 1250208.48 | 1349752.96 | differs |
| 7|2026-08-01 | oasis | credit_revenue | 2752186.58 | 2786510.29 | differs |
| 7|2026-08-01 | oasis | insurance_census | 2236 | 2223 | differs |
| 7|2026-08-01 | oasis | returning_patients | 626 | 274 | differs |
| 7|2026-08-01 | oasis | new_op_census | 1636 | 1646 | differs |
| 7|2026-08-01 | oasis | op_episodes | 2555 | 2455 | differs |
| 7|2026-08-01 | oasis | er_census | 617 | 603 | differs |
| 7|2026-08-01 | oasis | available_slots | 18960 | 17834 | differs |
| 7|2026-08-01 | oasis | op_waiting_time_in_minutes | 116254 | 111375 | differs |
| 7|2026-08-01 | oasis | admissions | 293 | 316 | differs |
| 7|2026-08-01 | oasis | readmission_within_30days | 15 | 16 | differs |
| 7|2026-08-01 | oasis | insurance_admissions | 58 | 63 | differs |
| 7|2026-08-01 | oasis | discharges | 289 | 311 | differs |
| 7|2026-08-01 | oasis | icu_discharge | 18 | 45 | differs |
| 7|2026-08-01 | oasis | alos_non_ltc | 1.65657698056801 | 1.6946309687787 | differs |
| 6|2025-04-01 | oasis | revenue | 5855457.8 | 5889140.57 | differs |
| 6|2025-04-01 | oasis | non_ltc_ip_revenue | 2214382.48 | 2245837.1 | differs |
| 6|2025-04-01 | oasis | non_moh_revenue | 806075.79 | 847311.23 | differs |
| 6|2025-04-01 | oasis | high_value_service_revenue | 449649.1 | 458810.1 | differs |
| 6|2025-04-01 | oasis | census | 1064 | 1052 | differs |
| 6|2025-04-01 | oasis | insurance_census | 18 | 17 | differs |
| 6|2025-04-01 | oasis | returning_patients | 120 | 119 | differs |
| 6|2025-04-01 | oasis | er_census | 418 | 406 | differs |
| 6|2025-04-01 | oasis | admissions | 131 | 141 | differs |
| 6|2025-04-01 | oasis | discharges | 137 | 147 | differs |
| 6|2025-04-01 | oasis | alos_non_ltc | 5.50081699346405 | 5.28523685515873 | differs |
| 3|2025-12-01 | oasis | non_ltc_ip_revenue | 15334515.34 | 15490898.65 | differs |
| 3|2025-12-01 | oasis | non_moh_revenue | 13851155.09 | 13968062.12 | differs |
| 3|2025-12-01 | oasis | insurance_revenue | 9627022.9 | 9703414.51 | differs |
| 3|2025-12-01 | oasis | op_episodes | 11080 | 10738 | differs |
| 3|2025-12-01 | oasis | er_census | 2051 | 2024 | differs |
| 3|2025-12-01 | oasis | referrals_volume | 1375 | 1382 | differs |
| 3|2025-12-01 | oasis | op_waiting_time_in_minutes | 502687 | 471673 | differs |
| 3|2025-12-01 | oasis | admissions | 1049 | 1189 | differs |
| 3|2025-12-01 | oasis | readmission_within_30days | 70 | 77 | differs |
| 3|2025-12-01 | oasis | readmitted_to_ICU_with_48hrs | 0 | 2 | differs |
| 3|2025-12-01 | oasis | insurance_admissions | 542 | 579 | differs |
| 3|2025-12-01 | oasis | discharges | 1031 | 1179 | differs |
| 3|2025-12-01 | oasis | icu_discharge | 107 | 297 | differs |
| 3|2025-12-01 | oasis | alos_non_ltc | 3.00119165023011 | 2.81357871964047 | differs |
| 5|2025-06-01 | oasis | non_ltc_ip_revenue | 7132554.39 | 7183245.42 | differs |
| 5|2025-06-01 | oasis | non_moh_revenue | 6977155.12 | 6612750.69 | differs |
| 5|2025-06-01 | oasis | insurance_revenue | 4357656.02 | 4457353.1 | differs |
| 5|2025-06-01 | oasis | referrals_revenue | 439604.01 | 529133.91 | differs |
| 5|2025-06-01 | oasis | credit_revenue | 13902564.78 | 14389963.54 | differs |
| 5|2025-06-01 | oasis | high_value_service_revenue | 1258659.37 | 1283864.83 | differs |
| 5|2025-06-01 | oasis | op_episodes | 6220 | 6049 | differs |
| 5|2025-06-01 | oasis | available_slots | 17248 | 17936 | differs |
| 5|2025-06-01 | oasis | admissions | 537 | 643 | differs |
| 5|2025-06-01 | oasis | readmission_within_30days | 40 | 42 | differs |
| 5|2025-06-01 | oasis | readmitted_to_ICU_with_48hrs | 4 | 3 | differs |
| 5|2025-06-01 | oasis | discharges | 532 | 641 | differs |
| 5|2025-06-01 | oasis | icu_discharge | 81 | 84 | differs |
| 5|2025-06-01 | oasis | alos_non_ltc | 2.39456106870229 | 2.23133776549061 | differs |
| 1|2025-12-01 | oasis | non_ltc_ip_revenue | 7640610.46 | 7731527.57 | differs |
| 1|2025-12-01 | oasis | insurance_revenue | 10898709.42 | 11068258.28 | differs |
| 1|2025-12-01 | oasis | credit_revenue | 27038237.01 | 27276312.9 | differs |
| 1|2025-12-01 | oasis | census | 19731 | 19504 | differs |
| 1|2025-12-01 | oasis | insurance_census | 16477 | 16291 | differs |
| 1|2025-12-01 | oasis | op_census | 17933 | 17815 | differs |
| 1|2025-12-01 | oasis | new_op_census | 2350 | 2336 | differs |
| 1|2025-12-01 | oasis | op_episodes | 13646 | 13241 | differs |
| 1|2025-12-01 | oasis | er_census | 1798 | 1689 | differs |
| 1|2025-12-01 | oasis | referrals_volume | 191 | 190 | differs |
| 1|2025-12-01 | oasis | available_slots | 30802 | 33334 | differs |
| ... | | 1214 more | | | |

## vw_financial

Keys (branch_id, month_date): old 85, new 88. Differences: 447.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 1|2026-09-01 | oasis | assets | 326219094.13 | 549069964.72 | differs |
| 1|2026-09-01 | oasis | assets_opening_balance | 338376255.4 | 563424258.86 | differs |
| 1|2026-09-01 | oasis | consumables_budget | 5815112.28 | 2131192.98 | differs |
| 6|2025-11-01 | oasis | ebitda_actual | 3694519.889 | 3744455.89 | differs |
| 6|2025-11-01 | oasis | account_receivable_actual | 10024113.3 | 80948069.42 | differs |
| 6|2025-11-01 | oasis | account_receivable_actual_opening_balance | 3989343.29 | 70923956.12 | differs |
| 6|2025-11-01 | oasis | assets | 6345263.29 | 89663833.76 | differs |
| 6|2025-11-01 | oasis | assets_opening_balance | 1349294.68 | 83318570.47 | differs |
| 2|2025-04-01 | oasis | account_receivable_actual | 15293656.46 | 119464698.63 | differs |
| 2|2025-04-01 | oasis | account_receivable_actual_opening_balance | -75663483.02 | 104171042.17 | differs |
| 2|2025-04-01 | oasis | assets | 5912881.78 | 700727175.32 | differs |
| 2|2025-04-01 | oasis | assets_opening_balance | 1806715 | 694814293.54 | differs |
| 3|2025-12-01 | oasis | operating_expenses | 16499277.64 | 16190001.64 | differs |
| 3|2025-12-01 | oasis | ebitda_actual | 5365832.66 | 5675108.66 | differs |
| 3|2025-12-01 | oasis | account_receivable_actual | 4937678.95 | 191348800.32 | differs |
| 3|2025-12-01 | oasis | account_receivable_actual_opening_balance | 18999074.86 | 186411121.37 | differs |
| 3|2025-12-01 | oasis | assets | -4718550.78 | 560429010.53 | differs |
| 3|2025-12-01 | oasis | assets_opening_balance | 19080659.38 | 565147561.31 | differs |
| 2|2025-06-01 | oasis | account_receivable_actual | 257318.4 | 137404770.81 | differs |
| 2|2025-06-01 | oasis | account_receivable_actual_opening_balance | 17682753.78 | 137147452.41 | differs |
| 2|2025-06-01 | oasis | assets | 8167374.09 | 717949709.61 | differs |
| 2|2025-06-01 | oasis | assets_opening_balance | 9055160.2 | 709782335.52 | differs |
| 4|2025-08-01 | oasis | account_receivable_actual | 7126924.05 | 90797448.25 | differs |
| 4|2025-08-01 | oasis | account_receivable_actual_opening_balance | 6780213.4 | 83670524.2 | differs |
| 4|2025-08-01 | oasis | assets | 4580100.05 | 203960638.17 | differs |
| 4|2025-08-01 | oasis | assets_opening_balance | 3901345.77 | 199380538.12 | differs |
| 5|2025-05-01 | oasis | account_receivable_actual | 2118588.82 | 86970461.9 | differs |
| 5|2025-05-01 | oasis | account_receivable_actual_opening_balance | 9467902.76 | 84851873.08 | differs |
| 5|2025-05-01 | oasis | assets | 1824080.92 | 105461109.85 | differs |
| 5|2025-05-01 | oasis | assets_opening_balance | -694710.54 | 103637028.93 | differs |
| 2|2025-08-01 | oasis | account_receivable_actual | 510087.87 | 159221204.58 | differs |
| 2|2025-08-01 | oasis | account_receivable_actual_opening_balance | 21306345.9 | 158711116.71 | differs |
| 2|2025-08-01 | oasis | assets | 12240592.7 | 747492524.66 | differs |
| 2|2025-08-01 | oasis | assets_opening_balance | 17302222.35 | 735251931.96 | differs |
| 1|2025-06-01 | oasis | ebitda_actual | 5103605.75 | 5149770.75 | differs |
| 1|2025-06-01 | oasis | account_receivable_actual | 11980457.3 | 141140656.64 | differs |
| 1|2025-06-01 | oasis | account_receivable_actual_opening_balance | 16769201.58 | 129160199.34 | differs |
| 1|2025-06-01 | oasis | assets | 2588151.45 | 502103052.29 | differs |
| 1|2025-06-01 | oasis | assets_opening_balance | 5931994.92 | 499514900.84 | differs |
| 4|2025-04-01 | oasis | account_receivable_actual | -2431295.79 | 68955161.17 | differs |
| 4|2025-04-01 | oasis | account_receivable_actual_opening_balance | -24813433.16 | 71386456.96 | differs |
| 4|2025-04-01 | oasis | assets | 300445.25 | 192781708.76 | differs |
| 4|2025-04-01 | oasis | assets_opening_balance | 152789.3 | 192481263.51 | differs |
| 3|2025-09-01 | oasis | operating_expenses | 15671533.59 | 15456011.59 | differs |
| 3|2025-09-01 | oasis | ebitda_actual | 11590263.6 | 11805785.6 | differs |
| 3|2025-09-01 | oasis | account_receivable_actual | 2250855.87 | 174671403.68 | differs |
| 3|2025-09-01 | oasis | account_receivable_actual_opening_balance | 18925807.4 | 172420547.81 | differs |
| 3|2025-09-01 | oasis | assets | 14238861.66 | 532751472.51 | differs |
| 3|2025-09-01 | oasis | assets_opening_balance | 14066176.91 | 518512610.85 | differs |
| 6|2025-07-01 | oasis | operating_expenses | 8789040.17 | 8439488.17 | differs |
| 6|2025-07-01 | oasis | ebitda_actual | 2888567.12 | 3238119.12 | differs |
| 6|2025-07-01 | oasis | account_receivable_actual | 10909617.68 | 52544952.45 | differs |
| 6|2025-07-01 | oasis | account_receivable_actual_opening_balance | 9795566.13 | 41635334.77 | differs |
| 6|2025-07-01 | oasis | assets | 3890935.41 | 77700092.85 | differs |
| 6|2025-07-01 | oasis | assets_opening_balance | 1926185.66 | 73809157.44 | differs |
| 1|2025-08-01 | oasis | ebitda_actual | 4225117.88 | 4271283.88 | differs |
| 1|2025-08-01 | oasis | account_receivable_actual | -16721061.05 | 136601830.09 | differs |
| 1|2025-08-01 | oasis | account_receivable_actual_opening_balance | 12182234.5 | 153322891.14 | differs |
| 1|2025-08-01 | oasis | assets | 3883005.66 | 500209590.96 | differs |
| 1|2025-08-01 | oasis | assets_opening_balance | -5776466.99 | 496326585.3 | differs |
| 5|2025-02-01 | oasis | account_receivable_actual | 6213566.79 | 81607323.66 | differs |
| 5|2025-02-01 | oasis | account_receivable_actual_opening_balance | -9635056.75 | 75393756.87 | differs |
| 5|2025-02-01 | oasis | assets | 5021197.64 | 105033176.14 | differs |
| 5|2025-02-01 | oasis | assets_opening_balance | 5204890.93 | 100011978.5 | differs |
| 4|2025-03-01 | oasis | account_receivable_actual | -24813433.16 | 71386456.96 | differs |
| 4|2025-03-01 | oasis | account_receivable_actual_opening_balance | -825233.28 | 96199890.12 | differs |
| 4|2025-03-01 | oasis | assets | 152789.3 | 192481263.51 | differs |
| 4|2025-03-01 | oasis | assets_opening_balance | 5599812.04 | 192328474.21 | differs |
| 5|2025-12-01 | oasis | account_receivable_actual | 3378866.69 | 111366359.76 | differs |
| 5|2025-12-01 | oasis | account_receivable_actual_opening_balance | 13939610.59 | 107987493.07 | differs |
| 5|2025-12-01 | oasis | assets | -8027469.42 | 113532130.26 | differs |
| 5|2025-12-01 | oasis | assets_opening_balance | 6230844.1 | 121559599.68 | differs |
| 4|2025-06-01 | oasis | account_receivable_actual | -2264435.24 | 76890310.8 | differs |
| 4|2025-06-01 | oasis | account_receivable_actual_opening_balance | 10199584.87 | 79154746.04 | differs |
| 4|2025-06-01 | oasis | assets | 1792801.52 | 195479192.35 | differs |
| 4|2025-06-01 | oasis | assets_opening_balance | 904682.07 | 193686390.83 | differs |
| 1|2025-03-01 | oasis | account_receivable_actual | -31938837.82 | 101483985.35 | differs |
| 1|2025-03-01 | oasis | account_receivable_actual_opening_balance | 14650392.62 | 133422823.17 | differs |
| 1|2025-03-01 | oasis | assets | -4860543.56 | 496862950.92 | differs |
| 1|2025-03-01 | oasis | assets_opening_balance | 8746693.22 | 501723494.48 | differs |
| 1|2025-04-01 | oasis | ebitda_actual | 7346244.77 | 7392410.77 | differs |
| 1|2025-04-01 | oasis | account_receivable_actual | 10907012.41 | 112390997.76 | differs |
| 1|2025-04-01 | oasis | account_receivable_actual_opening_balance | -31938837.82 | 101483985.35 | differs |
| 1|2025-04-01 | oasis | assets | -3280045 | 493582905.92 | differs |
| 1|2025-04-01 | oasis | assets_opening_balance | -4860543.56 | 496862950.92 | differs |
| 6|2025-09-01 | oasis | operating_expenses | 9077423.92 | 9027487.92 | differs |
| 6|2025-09-01 | oasis | ebitda_actual | 1661258.39 | 1711194.39 | differs |
| 6|2025-09-01 | oasis | account_receivable_actual | 10513493.64 | 66934612.83 | differs |
| 6|2025-09-01 | oasis | account_receivable_actual_opening_balance | 3876166.74 | 56421119.19 | differs |
| 6|2025-09-01 | oasis | assets | 1689099.69 | 81969275.79 | differs |
| 6|2025-09-01 | oasis | assets_opening_balance | 2580083.25 | 80280176.1 | differs |
| 5|2025-04-01 | oasis | account_receivable_actual | 9467902.76 | 84851873.08 | differs |
| 5|2025-04-01 | oasis | account_receivable_actual_opening_balance | -6223353.34 | 75383970.32 | differs |
| 5|2025-04-01 | oasis | assets | -694710.54 | 103637028.93 | differs |
| 5|2025-04-01 | oasis | assets_opening_balance | -701436.67 | 104331739.47 | differs |
| 1|2025-02-01 | oasis | ebitda_actual | 8669010.089 | 8731737.56 | differs |
| 1|2025-02-01 | oasis | account_receivable_actual | 14650392.62 | 133422823.17 | differs |
| 1|2025-02-01 | oasis | account_receivable_actual_opening_balance | -30416644.14 | 118772430.55 | differs |
| 1|2025-02-01 | oasis | assets | 8746693.22 | 501723494.48 | differs |
| 1|2025-02-01 | oasis | assets_opening_balance | 2026924.64 | 492976801.26 | differs |
| 4|2025-07-01 | oasis | account_receivable_actual | 6780213.4 | 83670524.2 | differs |
| 4|2025-07-01 | oasis | account_receivable_actual_opening_balance | -2264435.24 | 76890310.8 | differs |
| 4|2025-07-01 | oasis | assets | 3901345.77 | 199380538.12 | differs |
| 4|2025-07-01 | oasis | assets_opening_balance | 1792801.52 | 195479192.35 | differs |
| 1|2025-05-01 | oasis | ebitda_actual | 4211866.66 | 4258031.66 | differs |
| 1|2025-05-01 | oasis | account_receivable_actual | 16769201.58 | 129160199.34 | differs |
| 1|2025-05-01 | oasis | account_receivable_actual_opening_balance | 10907012.41 | 112390997.76 | differs |
| 1|2025-05-01 | oasis | assets | 5931994.92 | 499514900.84 | differs |
| 1|2025-05-01 | oasis | assets_opening_balance | -3280045 | 493582905.92 | differs |
| 5|2025-03-01 | oasis | account_receivable_actual | -6223353.34 | 75383970.32 | differs |
| 5|2025-03-01 | oasis | account_receivable_actual_opening_balance | 6213566.79 | 81607323.66 | differs |
| 5|2025-03-01 | oasis | assets | -701436.67 | 104331739.47 | differs |
| 5|2025-03-01 | oasis | assets_opening_balance | 5021197.64 | 105033176.14 | differs |
| 6|2025-08-01 | oasis | operating_expenses | 9822807.06 | 9772871.06 | differs |
| 6|2025-08-01 | oasis | ebitda_actual | 3020503.3 | 3070439.3 | differs |
| 6|2025-08-01 | oasis | account_receivable_actual | 3876166.74 | 56421119.19 | differs |
| 6|2025-08-01 | oasis | account_receivable_actual_opening_balance | 10909617.68 | 52544952.45 | differs |
| 6|2025-08-01 | oasis | assets | 2580083.25 | 80280176.1 | differs |
| 6|2025-08-01 | oasis | assets_opening_balance | 3890935.41 | 77700092.85 | differs |
| 8|2026-08-01 | fusion | net_revenue_actual | 402833.71 | 443974.03 | differs |
| 8|2026-08-01 | fusion | sub_revenue_actual | 402833.71 | 448930.69 | differs |
| 8|2026-08-01 | fusion | operating_expenses | 0 | 3576916.12 | differs |
| 8|2026-08-01 | fusion | ebitda_actual | 402833.71 | -3132942.09 | differs |
| 8|2026-08-01 | fusion | account_receivable_actual | 917.35 | 74783.77 | differs |
| 8|2026-08-01 | fusion | account_receivable_actual_opening_balance | 679.47 | 29763.77 | differs |
| 8|2026-08-01 | fusion | ga_expenses_actual | 0 | 26000 | differs |
| 8|2026-08-01 | fusion | assets | 606791.68 | -8535.07 | differs |
| 8|2026-08-01 | fusion | assets_opening_balance | 198098.17 | 223847.38 | differs |
| 8|2026-08-01 | fusion | income | 402833.71 | -3132959.34 | differs |
| 2|2026-08-01 | oasis | assets | 874489449.646 | 898860147.52 | differs |
| 2|2026-08-01 | oasis | assets_opening_balance | 877203031.826 | 886257136.26 | differs |
| 2|2026-08-01 | oasis | consumables_budget | 5513311.24 | 2594499.41 | differs |
| 1|2025-01-01 | oasis | ebitda_actual | 7253983.93 | 7316711.4 | differs |
| 1|2025-01-01 | oasis | account_receivable_actual | -30416644.14 | 118772430.55 | differs |
| 1|2025-01-01 | oasis | account_receivable_actual_opening_balance | 3020992.14 | 149189074.69 | differs |
| 1|2025-01-01 | oasis | assets | 2026924.64 | 492976801.26 | differs |
| 1|2025-01-01 | oasis | assets_opening_balance | -8629589.6 | 490949876.62 | differs |
| 4|2025-02-01 | oasis | account_receivable_actual | -825233.28 | 96199890.12 | differs |
| 4|2025-02-01 | oasis | account_receivable_actual_opening_balance | 13412650.19 | 97025123.4 | differs |
| 4|2025-02-01 | oasis | assets | 5599812.04 | 192328474.21 | differs |
| 4|2025-02-01 | oasis | assets_opening_balance | 8908064.1 | 186728662.17 | differs |
| 4|2025-05-01 | oasis | account_receivable_actual | 10199584.87 | 79154746.04 | differs |
| 4|2025-05-01 | oasis | account_receivable_actual_opening_balance | -2431295.79 | 68955161.17 | differs |
| 4|2025-05-01 | oasis | assets | 904682.07 | 193686390.83 | differs |
| 4|2025-05-01 | oasis | assets_opening_balance | 300445.25 | 192781708.76 | differs |
| 1|2025-12-01 | oasis | account_receivable_actual | 11261570.55 | 139848850.22 | differs |
| 1|2025-12-01 | oasis | account_receivable_actual_opening_balance | 11714529.31 | 128587279.67 | differs |
| 1|2025-12-01 | oasis | assets | 1925899.59 | 512244913.92 | differs |
| 1|2025-12-01 | oasis | assets_opening_balance | 1825902.69 | 510319014.33 | differs |
| 5|2025-10-01 | oasis | account_receivable_actual | 2300156.36 | 94047882.48 | differs |
| 5|2025-10-01 | oasis | account_receivable_actual_opening_balance | -18302122.44 | 91747726.12 | differs |
| 5|2025-10-01 | oasis | assets | 5655894.6 | 115328755.58 | differs |
| 5|2025-10-01 | oasis | assets_opening_balance | 1416746.01 | 109672860.98 | differs |
| 6|2025-12-01 | oasis | operating_expenses | 7574747.19 | 7524811.19 | differs |
| 6|2025-12-01 | oasis | ebitda_actual | 3981013.67 | 4030949.67 | differs |
| 6|2025-12-01 | oasis | account_receivable_actual | 2312571.4 | 83260640.82 | differs |
| 6|2025-12-01 | oasis | account_receivable_actual_opening_balance | 10024113.3 | 80948069.42 | differs |
| 6|2025-12-01 | oasis | assets | -2762767.63 | 86901066.13 | differs |
| 6|2025-12-01 | oasis | assets_opening_balance | 6345263.29 | 89663833.76 | differs |
| 6|2025-12-01 | oasis | income | 888048.78 | 699215.78 | differs |
| 2|2025-11-01 | oasis | account_receivable_actual | 18658132.88 | 187701332.71 | differs |
| 2|2025-11-01 | oasis | account_receivable_actual_opening_balance | 6802898.38 | 169043199.83 | differs |
| 2|2025-11-01 | oasis | assets | 15022628.48 | 787673836.59 | differs |
| 2|2025-11-01 | oasis | assets_opening_balance | 14474352.31 | 772651208.11 | differs |
| 5|2026-09-01 | fusion | net_revenue_actual | 2859115.41 | 0 | differs |
| 5|2026-09-01 | fusion | sub_revenue_actual | 2859115.41 | 0 | differs |
| 5|2026-09-01 | fusion | operating_expenses | 6505070.49 | 3520 | differs |
| 5|2026-09-01 | fusion | ebitda_actual | -3645955.08 | -3520 | differs |
| 5|2026-09-01 | fusion | account_receivable_actual | 149835989.59 | 146414657.08 | differs |
| 5|2026-09-01 | fusion | account_receivable_actual_opening_balance | 100337841.04 | 146414657.08 | differs |
| 5|2026-09-01 | fusion | ga_expenses_actual | 102574.63 | 1920 | differs |
| 5|2026-09-01 | fusion | consumables_actual | 1394546.13 | 0 | differs |
| 5|2026-09-01 | fusion | assets | 12190338.584 | 147067206.9 | differs |
| 5|2026-09-01 | fusion | assets_opening_balance | -14820670.306 | 147248948.18 | differs |
| 5|2026-09-01 | fusion | income | -3830686.03 | -3031.91 | differs |
| 5|2026-09-01 | fusion | consumables_budget | 3111851.87 | 1396343.79 | differs |
| 4|2025-01-01 | oasis | account_receivable_actual | 13412650.19 | 97025123.4 | differs |
| 4|2025-01-01 | oasis | account_receivable_actual_opening_balance | 11166377.92 | 83612473.21 | differs |
| 4|2025-01-01 | oasis | assets | 8908064.1 | 186728662.17 | differs |
| 4|2025-01-01 | oasis | assets_opening_balance | 1504497.95 | 177820598.07 | differs |
| 1|2025-10-01 | oasis | ebitda_actual | 5831437.56 | 5877603.56 | differs |
| 1|2025-10-01 | oasis | account_receivable_actual | 1235717.77 | 116872750.36 | differs |
| 1|2025-10-01 | oasis | account_receivable_actual_opening_balance | -20964797.5 | 115637032.59 | differs |
| 1|2025-10-01 | oasis | assets | 6162637.29 | 508493111.64 | differs |
| 1|2025-10-01 | oasis | assets_opening_balance | 2120883.39 | 502330474.35 | differs |
| 3|2026-08-01 | fusion | net_revenue_actual | 3552019.66 | 40561310.51 | differs |
| 3|2026-08-01 | fusion | sub_revenue_actual | 3552019.66 | 43659200.94 | differs |
| 3|2026-08-01 | fusion | operating_expenses | -6908.32 | 24496140.32 | differs |
| 3|2026-08-01 | fusion | ebitda_actual | 3558927.98 | 16065170.19 | differs |
| 3|2026-08-01 | fusion | account_receivable_actual | 166370001.92 | 248977038.82 | differs |
| 3|2026-08-01 | fusion | account_receivable_actual_opening_balance | 251384632.23 | 293564622.34 | differs |
| 3|2026-08-01 | fusion | ga_expenses_actual | -6908.32 | 46297.51 | differs |
| 3|2026-08-01 | fusion | assets | 630651519.485 | 720207289.1 | differs |
| 3|2026-08-01 | fusion | assets_opening_balance | 578157532.551 | 688242909.13 | differs |
| 3|2026-08-01 | fusion | income | 3558927.98 | 16063504.42 | differs |
| 3|2026-08-01 | fusion | consumables_budget | 3499002.11 | 1841874.71 | differs |
| 4|2025-12-01 | oasis | account_receivable_actual | 84333.01 | 103367189.03 | differs |
| 4|2025-12-01 | oasis | account_receivable_actual_opening_balance | 16445554.53 | 103282856.02 | differs |
| 4|2025-12-01 | oasis | assets | 1240998.6 | 230706783.82 | differs |
| 4|2025-12-01 | oasis | assets_opening_balance | 10452578.28 | 229465785.22 | differs |
| ... | | 247 more | | | |

## vw_gl_transactions

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 7042, new 8580. Differences: 8759.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | Transaction_Balance | -371469.24 | 221.4 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -39367910.541 | -71642128.02 | differs |
| 5|2025-03-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | OpeningBalance | 0 | -120552.45 | differs |
| 4|2025-11-01|BS|assets|non current assets|work in progress|cwip | oasis | OpeningBalance | 0 | 1047207.13 | differs |
| 6|2025-07-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | oasis | OpeningBalance | 0 | 2304450 | differs |
| 1|2025-06-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | oasis | OpeningBalance | 0 | 3834873.09 | differs |
| 2|2025-02-01|IS|expenses|general and administrative expenses|insurance |insurance  |  | * |  |  | missing in new |
| 5|2025-10-01|IS|other income|other income, net|other income, net|rental income | oasis | OpeningBalance | 0 | -63858.58 | differs |
| 2|2025-01-01|BS|assets|current assets|due from / ( due to) branch|due from branch | oasis | OpeningBalance | 0 | 411582755.03 | differs |
| 6|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | oasis | OpeningBalance | 0 | 161584.12 | differs |
| 6|2025-07-01|BS|assets|non current assets|ppe cost|computers cost | oasis | OpeningBalance | 0 | 3292305.74 | differs |
| 5|2025-01-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued maintenance | oasis | OpeningBalance | 0 | -499566.63 | differs |
| 6|2025-05-01|IS|expenses|direct cost|utilities|utilities | oasis | OpeningBalance | 0 | 1135436.89 | differs |
| 3|2025-07-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | oasis | OpeningBalance | 0 | -15273745.39 | differs |
| 4|2025-02-01|BS|assets|non current assets|work in progress|cwip | oasis | OpeningBalance | 0 | 8385063.92 | differs |
| 2|2026-08-01||||| |  | * |  |  | missing in new |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | oasis | OpeningBalance | 0 | 330640.37 | differs |
| 2|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | oasis | OpeningBalance | 0 | 2252620.01 | differs |
| 3|2025-06-01|IS|revenue|revenue|revenue out patient|revenue credit - op | oasis | OpeningBalance | 0 | -16718435.04 | differs |
| 6|2025-07-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 4|2025-04-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | oasis | OpeningBalance | 0 | 250847.32 | differs |
| 1|2025-01-01|BS|assets|current assets|inventories, net|inventory - provision | oasis | OpeningBalance | 0 | -2110796 | differs |
| 3|2025-10-01|IS|revenue|revenue|revenue out patient|revenue credit - op | oasis | OpeningBalance | 0 | -30858874.37 | differs |
| 5|2025-12-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | oasis | OpeningBalance | 0 | -867154.6 | differs |
| 4|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 3|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | oasis | OpeningBalance | 0 | -13086.13 | differs |
| 4|2025-08-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | oasis | OpeningBalance | 0 | 305132.55 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|deferred revenue  |  | * |  |  | missing in new |
| 2|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | oasis | OpeningBalance | 0 | 20445.71 | differs |
| 2|2025-11-01|IS|expenses|direct cost|employee costs|employee medical insurance | oasis | OpeningBalance | 0 | 1891085.6 | differs |
| 3|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | 0 | -2100403.67 | differs |
| 4|2025-10-01|BS|assets|non current assets|ppe cost|electrical devices cost | oasis | OpeningBalance | 0 | 23016773.55 | differs |
| 5|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued maintenance | oasis | OpeningBalance | 0 | -522088.96 | differs |
| 3|2025-12-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | oasis | OpeningBalance | 0 | 765095.29 | differs |
| 4|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | oasis | OpeningBalance | 0 | 346870.64 | differs |
| 5|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|other receivables |  | * |  |  | missing in new |
| 3|2025-12-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|housing guarantee payable to employees | oasis | OpeningBalance | 0 | -37641.87 | differs |
| 5|2025-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 5|2025-10-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | oasis | OpeningBalance | 0 | 54699771.55 | differs |
| 5|2025-05-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | oasis | OpeningBalance | 0 | 1267194 | differs |
| 6|2025-03-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | OpeningBalance | 0 | -115860 | differs |
| 5|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | oasis | OpeningBalance | 0 | 492094.58 | differs |
| 1|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | oasis | OpeningBalance | 0 | -70000 | differs |
| 6|2025-01-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 4|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | oasis | OpeningBalance | 0 | -246326.4 | differs |
| 5|2026-08-01|IS|other income|other income, net|other income, net|hrdf income |  | * |  |  | missing in new |
| 2|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | oasis | OpeningBalance | 0 | -13374426.86 | differs |
| 3|2025-01-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | oasis | OpeningBalance | 0 | -12695862.27 | differs |
| 6|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | 0 | -1274345.21 | differs |
| 3|2025-05-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | oasis | OpeningBalance | 0 | 9171760.34 | differs |
| 5|2025-11-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 2|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | OpeningBalance | 0 | 2698054.9 | differs |
| 5|2025-02-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 0 | 91777498.19 | differs |
| 2|2025-07-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | oasis | OpeningBalance | 0 | -172470538.54 | differs |
| 2|2025-05-01|IS|expenses|direct cost|employee costs|staff training and recruitments | oasis | OpeningBalance | 0 | 32042.4 | differs |
| 2|2025-01-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | OpeningBalance | 0 | -8292567.06 | differs |
| 1|2025-03-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 0 | 8549149.33 | differs |
| 3|2025-07-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | oasis | OpeningBalance | 0 | -1271698.59 | differs |
| 1|2025-11-01|IS|expenses|direct cost|maintenance expense|maintenance expense | oasis | OpeningBalance | 0 | 3680361.09 | differs |
| 2|2025-09-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | OpeningBalance | 0 | 121796566.44 | differs |
| 5|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | oasis | OpeningBalance | 0 | 440559.82 | differs |
| 1|2025-12-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | oasis | OpeningBalance | 0 | -35918723.38 | differs |
| 6|2025-01-01|IS|expenses|direct cost|cost of goods sold|stock adjustments |  | * |  |  | missing in new |
| 5|2025-06-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 0 | 6815022.8 | differs |
| 2|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | oasis | OpeningBalance | 0 | -12309592.96 | differs |
| 4|2025-12-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  |  | * |  |  | missing in new |
| 6|2025-07-01|IS|expenses|general and administrative expenses|stationary|postage printing and stationary | oasis | OpeningBalance | 0 | 24345.91 | differs |
| 4|2025-11-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 0 | 151931.7 | differs |
| 6|2025-02-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 0 | 2061728.17 | differs |
| 4|2025-03-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | oasis | OpeningBalance | 0 | 84513.47 | differs |
| 1|2025-10-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 5|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | 0 | -3999564.41 | differs |
| 1|2025-05-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 0 | 159572355.15 | differs |
| 6|2025-10-01|IS|expenses|direct cost|deprecition|depreciation expense |  | * |  |  | missing in new |
| 4|2025-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op | oasis | OpeningBalance | 0 | -17942058.75 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | OpeningBalance | 0 | -525759.66 | differs |
| 4|2025-07-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | oasis | OpeningBalance | 0 | 11378488 | differs |
| 3|2025-03-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | oasis | OpeningBalance | 0 | 6388969.66 | differs |
| 5|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | oasis | OpeningBalance | 0 | -666810.23 | differs |
| 6|2025-11-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | OpeningBalance | 0 | -579300 | differs |
| 2|2025-07-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | OpeningBalance | 0 | -1489802.99 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | Transaction_Balance | -67139.23 | 3406.55 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -24564272.547 | -24315272.2 | differs |
| 5|2025-06-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 2|2025-06-01|IS|other income|other income, net|other income, net|hr support program | oasis | OpeningBalance | 0 | -275070 | differs |
| 5|2025-01-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | oasis | OpeningBalance | 0 | 3087085.44 | differs |
| 2|2025-03-01|IS|expenses|direct cost|employee costs|employee medical insurance | oasis | OpeningBalance | 0 | 366144.09 | differs |
| 2|2025-06-01|IS|expenses|general and administrative expenses|repair & maintenance|security and cleaning expenses | oasis | OpeningBalance | 0 | 118941.63 | differs |
| 1|2025-04-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | oasis | OpeningBalance | 0 | 52258899.55 | differs |
| 2|2025-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 0 | 12781.56 | differs |
| 4|2025-07-01|BS|assets|non current assets|ppe accm depreciation|accm dep | oasis | OpeningBalance | 0 | -53920529.4 | differs |
| 5|2025-08-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | oasis | OpeningBalance | 0 | 243191.94 | differs |
| 3|2025-08-01|IS|revenue|revenue - discounts|revenue - settlement discount|volume discount | oasis | OpeningBalance | 0 | 1621165.85 | differs |
| 1|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | oasis | OpeningBalance | 0 | 54149.35 | differs |
| 6|2025-11-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | oasis | OpeningBalance | 0 | 250653.2 | differs |
| 3|2025-07-01|IS|revenue|revenue - discounts|revenue - settlement discount|patient referral discount | oasis | OpeningBalance | 0 | 143542.3 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | fusion | Transaction_Balance | 21451.4 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | fusion | OpeningBalance | -38002657.54 | -7586447.22 | differs |
| 4|2025-01-01|IS|expenses|general and administrative expenses|insurance |insurance  |  | * |  |  | missing in new |
| 1|2025-11-01|IS|expenses|direct cost|utilities|utilities | oasis | OpeningBalance | 0 | 2449783.94 | differs |
| 1|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | oasis | OpeningBalance | 0 | 2810219.18 | differs |
| 3|2025-04-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 0 | 117829.4 | differs |
| 4|2025-02-01|BS|assets|current assets|due from / ( due to) branch|due from branch |  | * |  |  | missing in new |
| 1|2025-06-01|IS|revenue|revenue|revenue out patient|revenue cash - op | oasis | OpeningBalance | 0 | -8853121.27 | differs |
| 1|2025-01-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | OpeningBalance | 0 | -3776893.63 | differs |
| 3|2025-02-01|IS|expenses|general and administrative expenses|management fees|board of directors expenses | oasis | OpeningBalance | 0 | 510222 | differs |
| 5|2025-10-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | 0 | -230410.28 | differs |
| 4|2025-02-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 0 | 117523551.78 | differs |
| 1|2025-03-01|IS|expenses|direct cost|maintenance expense|maintenance expense | oasis | OpeningBalance | 0 | 880930.35 | differs |
| 1|2025-02-01|IS|expenses|direct cost|utilities|utilities | oasis | OpeningBalance | 0 | 186616.8 | differs |
| 1|2025-04-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | OpeningBalance | 0 | -13065640 | differs |
| 3|2025-06-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | oasis | OpeningBalance | 0 | 503818.9 | differs |
| 2|2025-10-01|IS|expenses|direct cost|maintenance expense|medical equipment maintenance | oasis | OpeningBalance | 0 | 2025225.96 | differs |
| 3|2025-12-01|IS|expenses|direct cost|employee costs|employee govt fees | oasis | OpeningBalance | 0 | 4307298.58 | differs |
| 1|2025-10-01|IS|expenses|direct cost|amortization of intangible assets|amortization expense | oasis | OpeningBalance | 0 | 12162.39 | differs |
| 2|2025-05-01|BS|assets|non current assets|ppe accm depreciation|lhi accm dep | oasis | OpeningBalance | 0 | -435919.82 | differs |
| 5|2026-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | fusion | Transaction_Balance | 5275675.35 | 0 | differs |
| 1|2025-10-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | OpeningBalance | 0 | -2677616 | differs |
| 1|2025-08-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | oasis | OpeningBalance | 0 | 776608.46 | differs |
| 6|2025-06-01|IS|expenses|direct cost|deprecition|depreciation expense |  | * |  |  | missing in new |
| 5|2025-06-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | oasis | OpeningBalance | 0 | 183432.01 | differs |
| 6|2025-02-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 0 | 39189.64 | differs |
| 4|2025-06-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | oasis | OpeningBalance | 0 | 38339217.58 | differs |
| 4|2025-11-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 0 | 3517660.31 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | oasis | OpeningBalance | 0 | -576115.39 | differs |
| 4|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 6|2025-03-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | OpeningBalance | 0 | -363246114.32 | differs |
| 1|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued nafees portal fees | oasis | OpeningBalance | 0 | -100000 | differs |
| 5|2025-06-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | oasis | OpeningBalance | 0 | 324534.85 | differs |
| 1|2026-08-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  |  | * |  |  | missing in new |
| 3|2025-05-01|IS|expenses|direct cost|medical consumables|stock adjustments | oasis | OpeningBalance | 0 | 326839.49 | differs |
| 4|2025-05-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | oasis | OpeningBalance | 0 | 206606.27 | differs |
| 5|2025-10-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 0 | 6843576.13 | differs |
| 4|2025-10-01|IS|revenue|revenue - discounts|revenue - settlement discount|rejection | oasis | OpeningBalance | 0 | 10068065.89 | differs |
| 5|2025-12-01|IS|expenses|direct cost|maintenance expense|employee accommodation maintenance | oasis | OpeningBalance | 0 | 53474.17 | differs |
| 1|2025-03-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 0 | -50608.81 | differs |
| 4|2025-12-01|IS|expenses|direct cost|maintenance expense|building and facility maintenance | oasis | OpeningBalance | 0 | 89587.02 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | Transaction_Balance | 3024371 | -2936664.17 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | OpeningBalance | 2773518.23 | -61088.72 | differs |
| 1|2025-07-01|IS|expenses|general and administrative expenses|employee cost|employee cost | oasis | OpeningBalance | 0 | 1845138.38 | differs |
| 3|2025-10-01|IS|expenses|direct cost|employee costs|employee govt fees | oasis | OpeningBalance | 0 | 3553871.06 | differs |
| 4|2025-06-01|IS|expenses|direct cost|employee costs|employee costs | oasis | OpeningBalance | 0 | 25102392.29 | differs |
| 3|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|housing guarantee payable to employees | oasis | OpeningBalance | 0 | -37641.87 | differs |
| 3|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|other receivables |  | * |  |  | missing in new |
| 3|2025-04-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|hopsitality | oasis | OpeningBalance | 0 | 39396.13 | differs |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid government fee | oasis | OpeningBalance | 0 | 45355 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 4|2025-02-01|IS|expenses|direct cost|employee costs|employee medical insurance | oasis | OpeningBalance | 0 | 161801.34 | differs |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | oasis | OpeningBalance | 0 | 146114.72 | differs |
| 2|2025-12-01|BS|assets|non current assets|ppe cost|advertisement and electrical equip cost | oasis | OpeningBalance | 0 | 1717378.74 | differs |
| 1|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued doctors fee and commission |  | * |  |  | missing in new |
| 5|2025-03-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | oasis | OpeningBalance | 0 | -40266115.09 | differs |
| 2|2025-10-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | oasis | OpeningBalance | 0 | 14186164.92 | differs |
| 6|2025-07-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 0 | 946018.04 | differs |
| 3|2025-10-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 5|2025-05-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | OpeningBalance | 0 | -1903131 | differs |
| 2|2025-03-01|IS|expenses|general and administrative expenses|governmental fee|government fee | oasis | OpeningBalance | 0 | 220188.23 | differs |
| 3|2025-04-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | OpeningBalance | 0 | -4486577.47 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | OpeningBalance | 0 | -15922239.89 | differs |
| 3|2025-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | oasis | OpeningBalance | 0 | 15995102.56 | differs |
| 2|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | oasis | OpeningBalance | 0 | 1302989.55 | differs |
| 4|2025-07-01|IS|revenue|revenue - discounts|revenue - settlement discount|volume discount | oasis | OpeningBalance | 0 | 940391.6 | differs |
| 1|2025-02-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | OpeningBalance | 0 | -1976608 | differs |
| 2|2025-12-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | OpeningBalance | 0 | -30290805.51 | differs |
| 3|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 1|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | oasis | OpeningBalance | 0 | -392324.23 | differs |
| 6|2025-04-01|IS|expenses|general and administrative expenses|insurance |insurance  |  | * |  |  | missing in new |
| 3|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | oasis | OpeningBalance | 0 | 389400 | differs |
| 2|2025-02-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | oasis | OpeningBalance | 0 | -27582178.1 | differs |
| 5|2025-08-01|IS|expenses|direct cost|employee costs|doctor commission - incentive | oasis | OpeningBalance | 0 | 1151204.4 | differs |
| 5|2025-02-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | oasis | OpeningBalance | 0 | 157781.53 | differs |
| 2|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | OpeningBalance | 0 | 61090.92 | differs |
| 5|2025-05-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | OpeningBalance | 0 | -1378098.65 | differs |
| 3|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | oasis | OpeningBalance | 0 | 270600 | differs |
| 1|2025-02-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | OpeningBalance | 0 | -92834458.31 | differs |
| 4|2025-10-01|IS|expenses|direct cost|maintenance expense|general maintenance | oasis | OpeningBalance | 0 | 422740.7 | differs |
| 1|2025-12-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | oasis | OpeningBalance | 0 | 1287027.96 | differs |
| 6|2025-09-01|IS|expenses|general and administrative expenses|governmental fee|employee govt fees | oasis | OpeningBalance | 0 | 723641.38 | differs |
| 4|2025-06-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | OpeningBalance | 0 | -18728318.23 | differs |
| 1|2025-09-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | oasis | OpeningBalance | 0 | 14786935.56 | differs |
| 5|2025-12-01|BS|assets|non current assets|ppe cost|vehicles cost | oasis | OpeningBalance | 0 | 540732.26 | differs |
| 4|2025-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | 0 | 3260460.36 | differs |
| 6|2025-04-01|IS|expenses|direct cost|medical consumables|medical consumables | oasis | OpeningBalance | 0 | 753912.8 | differs |
| 4|2025-07-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 6|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | oasis | OpeningBalance | 0 | 761344.32 | differs |
| 3|2025-01-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 0 | 16723729.62 | differs |
| 1|2025-11-01|IS|expenses|direct cost|medical consumables|stock adjustments | oasis | OpeningBalance | 0 | 655781.91 | differs |
| 3|2025-09-01|IS|expenses|direct cost|maintenance expense|medical equipment maintenance | oasis | OpeningBalance | 0 | 632142.14 | differs |
| 1|2025-07-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | oasis | OpeningBalance | 0 | -19751526.66 | differs |
| 1|2025-08-01|IS|other income|other income, net|other income, net|education and training | oasis | OpeningBalance | 0 | -39482.9 | differs |
| 6|2025-04-01|IS|expenses|direct cost|cost of goods sold|stock adjustments |  | * |  |  | missing in new |
| 5|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | oasis | OpeningBalance | 0 | 10823.2 | differs |
| 1|2025-03-01|BS|assets|non current assets|ppe cost|computers cost | oasis | OpeningBalance | 0 | 7184026.58 | differs |
| 5|2025-05-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | OpeningBalance | 0 | -193573442.74 | differs |
| 3|2025-06-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 0 | 330837.65 | differs |
| 6|2025-07-01|IS|expenses|direct cost|utilities|utilities | oasis | OpeningBalance | 0 | 1509008.89 | differs |
| 4|2025-02-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | oasis | OpeningBalance | 0 | 254943 | differs |
| 3|2025-01-01|BS|assets|non current assets|ppe cost|vehicles cost | oasis | OpeningBalance | 0 | 1900574.13 | differs |
| 6|2025-09-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| ... | | 8559 more | | | |

## vw_gl_openning_balance

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 476, new 8580. Differences: 8707.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | fusion | OpeningBalance | 43428468 | -155588073.75 | differs |
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | fusion | forwarded_balance | -199016541.75 | 0 | differs |
| 1|2026-08-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  |  | * |  |  | missing in new |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | OpeningBalance | 2639518.33 | -61088.72 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | forwarded_balance | 133999.9 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | fusion | OpeningBalance | 1220741.42 | -7586447.22 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | fusion | forwarded_balance | -39223398.96 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip |  | * |  |  | missing in new |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | OpeningBalance | -405499.5 | -2271803.56 | differs |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | forwarded_balance | -1866304.06 | 0 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | OpeningBalance | -85772.86 | -2327109.04 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | forwarded_balance | -2241336.18 | 0 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | fusion | OpeningBalance | -1448736 | -4800603 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | fusion | forwarded_balance | -3351867 | 0 | differs |
| 2|2026-09-01||||| |  | * |  |  | missing in new |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | OpeningBalance | -449924 | -12475511 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | forwarded_balance | -12025587 | 0 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -14707601.11 | -24315272.2 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -9856671.437 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 54191821.51 | 229114221.99 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | forwarded_balance | 174922400.48 | 0 | differs |
| 5|2026-08-01|IS|other income|other income, net|other income, net|hrdf income |  | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -22688596.38 | -71642128.02 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -16679314.161 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 183743.59 | 896222.22 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | forwarded_balance | 712478.63 | 0 | differs |
| 2|2026-08-01||||| |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | OpeningBalance | -276996 | -3093110 | differs |
| 1|2026-08-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | forwarded_balance | -2816114 | 0 | differs |
| 5|2026-08-01||||| |  | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 4|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | fusion | OpeningBalance | -597382.54 | -8072472.9 | differs |
| 4|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | fusion | forwarded_balance | -8890643.362 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | OpeningBalance | 38018.09 | 296505.32 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | forwarded_balance | 258487.23 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | OpeningBalance | -75941.96 | 181832.2 | differs |
| 3|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | forwarded_balance | 233959.445 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 6|2026-08-01|IS|revenue|revenue|revenue out patient|revenue credit - op |  | * |  |  | missing in new |
| 2|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | OpeningBalance | -551157.81 | -1252605.71 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | forwarded_balance | -701447.9 | 0 | differs |
| 3|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | OpeningBalance | -44679.34 | 225716.5 | differs |
| 3|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | forwarded_balance | 233959.445 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | OpeningBalance | -5456199.07 | -34495731.41 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | forwarded_balance | -29039532.341 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | -870290.74 | 2679108.57 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | forwarded_balance | 3549399.31 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | OpeningBalance | 401639 | -257899 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | forwarded_balance | -659538 | 0 | differs |
| 2|2026-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | fusion | OpeningBalance | -159659.98 | -283956.96 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | fusion | forwarded_balance | 2784.06 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | 1126162.48 | 149669980.4 | differs |
| 5|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 148543337.06 | 0 | differs |
| 5|2026-09-01|IS|expenses|direct cost|employee costs|employee medical insurance |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | OpeningBalance | 47602.19 | -92855599.77 | differs |
| 1|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | forwarded_balance | -92903201.96 | 0 | differs |
| 4|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | 54316657.15 | 181034546.93 | differs |
| 4|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 127663912.54 | 0 | differs |
| 5|2026-09-01|IS|expenses|direct cost|employee costs|employee costs | fusion | OpeningBalance | 39131555.701 | 44819161.04 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 2|2026-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 1|2026-09-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  |  | * |  |  | missing in new |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | OpeningBalance | 6295.27 | 39916.27 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | forwarded_balance | 74621 | 0 | differs |
| 5|2026-09-01|IS|expenses|general and administrative expenses|insurance |insurance  |  | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|direct cost|medical consumables|stock adjustments |  | * |  |  | missing in new |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | OpeningBalance | 3107206.29 | 106215874.42 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | forwarded_balance | 103108668.13 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | OpeningBalance | -115320.07 | -242542.71 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | forwarded_balance | -127222.64 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|computers cost | oasis | OpeningBalance | 633126.74 | 7886896.63 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|computers cost | oasis | forwarded_balance | 7253769.89 | 0 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|advertisement and electrical equip accm dep | oasis | OpeningBalance | 0 | -12917185.83 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|advertisement and electrical equip accm dep | oasis | forwarded_balance | -12917185.83 | 0 | differs |
| 5|2026-09-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 261176.98 | 291249.98 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | forwarded_balance | 30073 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|bank | fusion | OpeningBalance | 1860499.36 | 5536613.55 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|bank | fusion | forwarded_balance | 3691019.76 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | -19172352.21 | -35851666.37 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | forwarded_balance | -16679314.161 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | OpeningBalance | 13597.46 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | forwarded_balance | -13597.46 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | fusion | OpeningBalance | 919468.98 | 1317624.19 | differs |
| 2|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | 4634899.67 | 432652964.66 | differs |
| 2|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 241275023.709 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | oasis | OpeningBalance | -963770.68 | 767964.71 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | oasis | forwarded_balance | 1731735.39 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | fusion | OpeningBalance | 60640830.44 | 66459792.31 | differs |
| 1|2026-09-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | OpeningBalance | -524617 | -12550204 | differs |
| 1|2026-09-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | forwarded_balance | -12025587 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 1686064.63 | 7160689.52 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | forwarded_balance | 5474624.89 | 0 | differs |
| 8|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -6551.75 | -5502.04 | differs |
| 2|2026-08-01|BS|assets|current assets|due from / ( due to) branch|due from branch | oasis | OpeningBalance | 125169882 | 624867439.48 | differs |
| 2|2026-08-01|BS|assets|current assets|due from / ( due to) branch|due from branch | oasis | forwarded_balance | 499697557.48 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store | fusion | OpeningBalance | 858823.15 | 4821843.25 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store | fusion | forwarded_balance | 3549399.31 | 0 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | OpeningBalance | -165604.16 | -6922450.83 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | forwarded_balance | -6756846.67 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | OpeningBalance | 142940.5 | 2425232.23 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | forwarded_balance | 2282291.73 | 0 | differs |
| 1|2026-09-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | OpeningBalance | -323162 | -3139276 | differs |
| 1|2026-09-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | forwarded_balance | -2816114 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | fusion | OpeningBalance | 6842538.28 | 3825480.46 | differs |
| 2|2026-08-01|IS|expenses|direct cost|deprecition|depreciation expense |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|current assets|inventories, net|inventory - provision | oasis | OpeningBalance | 601241.89 | -1203120.36 | differs |
| 1|2026-08-01|BS|assets|current assets|inventories, net|inventory - provision | oasis | forwarded_balance | -1804362.25 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 1549338.1 | 2084958.29 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | forwarded_balance | 535620.19 | 0 | differs |
| 4|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -12015858.46 | -21872529.9 | differs |
| 4|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -9856671.437 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | OpeningBalance | -554955.58 | -4963294.2 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | forwarded_balance | -4408338.62 | 0 | differs |
| 8|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -12411.55 | -8449.98 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 1223432.93 | 51132692.85 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | forwarded_balance | 49909259.92 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | oasis | OpeningBalance | 3027457.52 | 3339281.23 | differs |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | oasis | forwarded_balance | 311823.71 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued nafees portal fees |  | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|general and administrative expenses|telephone, electricity and water|telephone, electricity and water |  | * |  |  | missing in new |
| 8|2026-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | -26220991.22 | 256563486.04 | differs |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 230572199.28 | 0 | differs |
| 4|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | OpeningBalance | 599689.37 | 750539.6 | differs |
| 4|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | forwarded_balance | 150850.232 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | OpeningBalance | -2105800 | -6977883 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | forwarded_balance | -4872083 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities |  | * |  |  | missing in new |
| 2|2026-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | fusion | OpeningBalance | 3247733 | 6495466 | differs |
| 5|2026-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 5|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | OpeningBalance | 523306.15 | -39.8 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | forwarded_balance | -523345.95 | 0 | differs |
| 3|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 2|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due from branch |  | * |  |  | missing in new |
| 5|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | fusion | OpeningBalance | -932257.851 | -6737776.27 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | fusion | forwarded_balance | -5103236.7 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | fusion | OpeningBalance | 677527.72 | 11207552.48 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | fusion | forwarded_balance | 1731735.39 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | OpeningBalance | -38299.29 | 117524565.27 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | forwarded_balance | 117562864.56 | 0 | differs |
| 2|2026-09-01|IS|expenses|direct cost|maintenance expense|vehicle maintenance | fusion | OpeningBalance | 36942.59 | 73885.18 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip |  | * |  |  | missing in new |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | OpeningBalance | -319151.52 | -1097212.52 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | forwarded_balance | -778061 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | oasis | OpeningBalance | 9900.92 | -722.12 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | oasis | forwarded_balance | -10623.04 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | OpeningBalance | -1586543.02 | -30733172.69 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | forwarded_balance | -29146629.669 | 0 | differs |
| 3|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | fusion | OpeningBalance | -6029887.04 | 6043460.88 | differs |
| 3|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | fusion | forwarded_balance | -5011410.151 | 0 | differs |
| 8|2026-08-01|BS|assets|current assets|cash and bank balances|cash | fusion | OpeningBalance | 197418.7 | 48139.03 | differs |
| 5|2026-08-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 289785.77 | 329615.36 | differs |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | forwarded_balance | 39829.587 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | oasis | OpeningBalance | 841607.66 | 2475725.25 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | oasis | forwarded_balance | 1634117.59 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | oasis | OpeningBalance | -1357341.202 | -6557988.94 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | oasis | forwarded_balance | -5200647.739 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | -1247642.83 | 3896819.49 | differs |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | forwarded_balance | 5144462.32 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | oasis | OpeningBalance | 567505.07 | -190000 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | oasis | forwarded_balance | -757505.07 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | oasis | OpeningBalance | -75334.78 | -63834.78 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | oasis | forwarded_balance | 11500 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|deferred revenue  |  | * |  |  | missing in new |
| 2|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | 1372141.6 | 9117704.27 | differs |
| 2|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | forwarded_balance | 7745562.67 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | -10707605.39 | -19192594.05 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | forwarded_balance | -8484988.66 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 1120031.31 | 1655651.5 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | forwarded_balance | 535620.19 | 0 | differs |
| 2|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | oasis | OpeningBalance | -984915.028 | -17433277.3 | differs |
| 2|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | oasis | forwarded_balance | -16448362.27 | 0 | differs |
| 3|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -16662195.68 | -31099341.21 | differs |
| 3|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -16352207.459 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | oasis | OpeningBalance | -13249681.88 | -13893453.97 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | oasis | forwarded_balance | -643772.09 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | oasis | OpeningBalance | 22725.81 | 27000.02 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | oasis | forwarded_balance | 4274.21 | 0 | differs |
| 2|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 2|2026-08-01|IS|expenses|general and administrative expenses|insurance |insurance  |  | * |  |  | missing in new |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | oasis | OpeningBalance | 16756.94 | -383352.41 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | oasis | forwarded_balance | -400109.35 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | OpeningBalance | 401639 | -257899 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | forwarded_balance | -659538 | 0 | differs |
| 5|2026-09-01|IS|other income|other income, net|other income, net|other income | fusion | OpeningBalance | -901669.73 | -89455.96 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 1|2026-09-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 8|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|direct cost|deprecition|depreciation expense |  | * |  |  | missing in new |
| 4|2026-08-01|IS|expenses|general and administrative expenses|employee cost|employee cost |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | OpeningBalance | -4045.68 | 254441.55 | differs |
| ... | | 8507 more | | | |

## vw_hospital_beds_utilization

Keys (hospital_id, period): old 88, new 88. Differences: 735.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 2|2025-09-01 | oasis | available_beds | 256 | 311 | differs |
| 2|2025-09-01 | oasis | census | 1014 | 1080 | differs |
| 2|2025-09-01 | oasis | ltc_census | 131 | 132 | differs |
| 2|2025-09-01 | oasis | alos | 34.3327580539119 | 5.07281746031747 | differs |
| 2|2025-09-01 | oasis | ltc_alos | 244.236959287532 | 116.757098765432 | differs |
| 2|2025-09-01 | oasis | non_ltc_alos | 3.19181766704417 | 2.7077385620915 | differs |
| 2|2025-09-01 | oasis | total_bed_nights | 5393 | 5356 | differs |
| 2|2025-09-01 | oasis | available_bed_nights | 7680 | 9327 | differs |
| 2|2025-09-01 | oasis | occupancy_rate | 0.702213541666667 | 0.574246810335585 | differs |
| 3|2025-05-01 | oasis | census | 1225 | 1360 | differs |
| 3|2025-05-01 | oasis | ltc_census | 102 | 103 | differs |
| 3|2025-05-01 | oasis | alos | 27.7667346938775 | 2.9539949100703 | differs |
| 3|2025-05-01 | oasis | ltc_alos | 306.513888888889 | 62.9482638888889 | differs |
| 3|2025-05-01 | oasis | non_ltc_alos | 2.44864945087563 | 2.15473737163475 | differs |
| 3|2025-05-01 | oasis | total_bed_nights | 4651 | 4203 | differs |
| 3|2025-05-01 | oasis | occupancy_rate | 0.638435140700069 | 0.575832305795314 | differs |
| 1|2026-09-01 | oasis | available_beds | 463 | 452 | differs |
| 1|2026-09-01 | oasis | census | 1217 | 1292 | differs |
| 1|2026-09-01 | oasis | alos | 139.217200766913 | 6.59028164009392 | differs |
| 1|2026-09-01 | oasis | ltc_alos | 495.119559841741 | 139.725818452381 | differs |
| 1|2026-09-01 | oasis | non_ltc_alos | 2.92277462121212 | 2.31037919377472 | differs |
| 1|2026-09-01 | oasis | total_bed_nights | 11106 | 11351 | differs |
| 1|2026-09-01 | oasis | available_bed_nights | 13890 | 13556 | differs |
| 1|2026-09-01 | oasis | occupancy_rate | 0.799568034557235 | 0.837341398642667 | differs |
| 6|2026-08-01 | oasis | available_beds | 209 | 192 | differs |
| 6|2026-08-01 | oasis | census | 454 | 480 | differs |
| 6|2026-08-01 | oasis | alos | 26.3499449339207 | 4.457757885763 | differs |
| 6|2026-08-01 | oasis | ltc_alos | 185.603422619048 | 80.2116898148148 | differs |
| 6|2026-08-01 | oasis | non_ltc_alos | 3.94242043551089 | 3.27717712842713 | differs |
| 6|2026-08-01 | oasis | total_bed_nights | 2735 | 2782 | differs |
| 6|2026-08-01 | oasis | available_bed_nights | 6479 | 5949 | differs |
| 6|2026-08-01 | oasis | occupancy_rate | 0.422133045223028 | 0.46764162044041 | differs |
| 3|2025-06-01 | oasis | available_beds | 235 | 244 | differs |
| 3|2025-06-01 | oasis | census | 1060 | 1207 | differs |
| 3|2025-06-01 | oasis | ltc_census | 99 | 100 | differs |
| 3|2025-06-01 | oasis | alos | 32.285141509434 | 2.79109484964811 | differs |
| 3|2025-06-01 | oasis | ltc_alos | 320.782828282828 | 61.032532051282 | differs |
| 3|2025-06-01 | oasis | non_ltc_alos | 2.56477627471384 | 2.05529437965663 | differs |
| 3|2025-06-01 | oasis | total_bed_nights | 4216 | 3847 | differs |
| 3|2025-06-01 | oasis | available_bed_nights | 7050 | 7320 | differs |
| 3|2025-06-01 | oasis | occupancy_rate | 0.598014184397163 | 0.525546448087432 | differs |
| 5|2026-08-01 | oasis | available_beds | 203 | 201 | differs |
| 5|2026-08-01 | oasis | census | 929 | 1049 | differs |
| 5|2026-08-01 | oasis | alos | 35.3120739146035 | 27.4782160687333 | differs |
| 5|2026-08-01 | oasis | ltc_alos | 468.136538461539 | 525.851947463768 | differs |
| 5|2026-08-01 | oasis | non_ltc_alos | 2.75004822530864 | 2.31335147578973 | differs |
| 5|2026-08-01 | oasis | available_bed_nights | 6293 | 6231 | differs |
| 2|2025-12-01 | oasis | available_beds | 256 | 300 | differs |
| 2|2025-12-01 | oasis | census | 1162 | 1220 | differs |
| 2|2025-12-01 | oasis | ltc_census | 105 | 106 | differs |
| 2|2025-12-01 | oasis | alos | 25.0127294893861 | 22.2781939541042 | differs |
| 2|2025-12-01 | oasis | ltc_alos | 247.313492063492 | 254.009316479401 | differs |
| 2|2025-12-01 | oasis | non_ltc_alos | 2.92987228003784 | 2.52333772349936 | differs |
| 2|2025-12-01 | oasis | total_bed_nights | 5148 | 4919 | differs |
| 2|2025-12-01 | oasis | available_bed_nights | 7936 | 9300 | differs |
| 2|2025-12-01 | oasis | occupancy_rate | 0.648689516129032 | 0.528924731182796 | differs |
| 4|2025-01-01 | oasis | available_beds | 244 | 231 | differs |
| 4|2025-01-01 | oasis | census | 804 | 1100 | differs |
| 4|2025-01-01 | oasis | ltc_census | 87 | 304 | differs |
| 4|2025-01-01 | oasis | alos | 71.0532234660033 | 5.18522256143526 | differs |
| 4|2025-01-01 | oasis | ltc_alos | 629.173850574713 | 163.637689393939 | differs |
| 4|2025-01-01 | oasis | non_ltc_alos | 3.33147373314737 | 2.78442760942761 | differs |
| 4|2025-01-01 | oasis | total_bed_nights | 4047 | 3744 | differs |
| 4|2025-01-01 | oasis | available_bed_nights | 7564 | 7165 | differs |
| 4|2025-01-01 | oasis | occupancy_rate | 0.535034373347435 | 0.522540125610607 | differs |
| 5|2025-11-01 | oasis | census | 906 | 1015 | differs |
| 5|2025-11-01 | oasis | ltc_census | 143 | 145 | differs |
| 5|2025-11-01 | oasis | alos | 59.1282192788815 | 4.04178485162181 | differs |
| 5|2025-11-01 | oasis | ltc_alos | 356.131118881119 | 132.409548611111 | differs |
| 5|2025-11-01 | oasis | non_ltc_alos | 3.46450415028397 | 2.75327530322041 | differs |
| 5|2025-11-01 | oasis | total_bed_nights | 5725 | 3506 | differs |
| 5|2025-11-01 | oasis | available_bed_nights | 6090 | 6051 | differs |
| 5|2025-11-01 | oasis | occupancy_rate | 0.940065681444992 | 0.579408362254173 | differs |
| 1|2025-03-01 | oasis | available_beds | 463 | 503 | differs |
| 1|2025-03-01 | oasis | census | 797 | 839 | differs |
| 1|2025-03-01 | oasis | ltc_census | 322 | 324 | differs |
| 1|2025-03-01 | oasis | alos | 248.715809284818 | 37.4135945463812 | differs |
| 1|2025-03-01 | oasis | ltc_alos | 611.039855072464 | 339.293390376984 | differs |
| 1|2025-03-01 | oasis | non_ltc_alos | 3.09824561403509 | 2.84249318336742 | differs |
| 1|2025-03-01 | oasis | total_bed_nights | 9631 | 9494 | differs |
| 1|2025-03-01 | oasis | available_bed_nights | 14353 | 15578 | differs |
| 1|2025-03-01 | oasis | occupancy_rate | 0.671009545042848 | 0.609449223263577 | differs |
| 1|2025-01-01 | oasis | available_beds | 463 | 493 | differs |
| 1|2025-01-01 | oasis | census | 1061 | 1101 | differs |
| 1|2025-01-01 | oasis | alos | 190.446826892868 | 7.9904879014021 | differs |
| 1|2025-01-01 | oasis | ltc_alos | 588.85779252704 | 134.129737103175 | differs |
| 1|2025-01-01 | oasis | non_ltc_alos | 3.38129039704525 | 3.00896607114873 | differs |
| 1|2025-01-01 | oasis | total_bed_nights | 10927 | 10791 | differs |
| 1|2025-01-01 | oasis | available_bed_nights | 14353 | 15278 | differs |
| 1|2025-01-01 | oasis | occupancy_rate | 0.761304256949767 | 0.70630972640398 | differs |
| 2|2025-10-01 | oasis | available_beds | 256 | 298 | differs |
| 2|2025-10-01 | oasis | census | 1257 | 1328 | differs |
| 2|2025-10-01 | oasis | ltc_census | 127 | 128 | differs |
| 2|2025-10-01 | oasis | alos | 27.1916600371254 | 5.14922266430887 | differs |
| 2|2025-10-01 | oasis | ltc_alos | 240.790354330709 | 154.022183641975 | differs |
| 2|2025-10-01 | oasis | non_ltc_alos | 3.18543510324484 | 2.74157369971049 | differs |
| 2|2025-10-01 | oasis | total_bed_nights | 6070 | 6005 | differs |
| 2|2025-10-01 | oasis | available_bed_nights | 7936 | 9240 | differs |
| 2|2025-10-01 | oasis | occupancy_rate | 0.764868951612903 | 0.649891774891775 | differs |
| 6|2025-11-01 | oasis | available_beds | 209 | 191 | differs |
| 6|2025-11-01 | oasis | census | 464 | 484 | differs |
| 6|2025-11-01 | oasis | alos | 33.5821659482759 | 9.04792556980057 | differs |
| 6|2025-11-01 | oasis | ltc_alos | 183.763310185185 | 94.3948688271605 | differs |
| 6|2025-11-01 | oasis | non_ltc_alos | 5.99787414965987 | 4.91823476702509 | differs |
| 6|2025-11-01 | oasis | total_bed_nights | 3300 | 2894 | differs |
| 6|2025-11-01 | oasis | available_bed_nights | 6270 | 5738 | differs |
| 6|2025-11-01 | oasis | occupancy_rate | 0.526315789473684 | 0.504356918787034 | differs |
| 2|2025-03-01 | oasis | available_beds | 256 | 315 | differs |
| 2|2025-03-01 | oasis | census | 788 | 843 | differs |
| 2|2025-03-01 | oasis | ltc_census | 109 | 110 | differs |
| 2|2025-03-01 | oasis | alos | 39.3785956006768 | 3.84261283497884 | differs |
| 2|2025-03-01 | oasis | ltc_alos | 264.164755351682 | 58.5421085858586 | differs |
| 2|2025-03-01 | oasis | non_ltc_alos | 3.29363033873343 | 2.98058639764406 | differs |
| 2|2025-03-01 | oasis | total_bed_nights | 4635 | 4386 | differs |
| 2|2025-03-01 | oasis | available_bed_nights | 7936 | 9765 | differs |
| 2|2025-03-01 | oasis | occupancy_rate | 0.584047379032258 | 0.449155145929339 | differs |
| 4|2025-12-01 | oasis | census | 830 | 1114 | differs |
| 4|2025-12-01 | oasis | ltc_census | 92 | 310 | differs |
| 4|2025-12-01 | oasis | alos | 66.2795682730924 | 5.33844764670837 | differs |
| 4|2025-12-01 | oasis | ltc_alos | 575.427083333333 | 170.785683760684 | differs |
| 4|2025-12-01 | oasis | non_ltc_alos | 2.80860433604336 | 2.40418561467334 | differs |
| 4|2025-12-01 | oasis | total_bed_nights | 3910 | 3953 | differs |
| 4|2025-12-01 | oasis | occupancy_rate | 0.516922263352723 | 0.522607086197779 | differs |
| 2|2025-01-01 | oasis | available_beds | 256 | 316 | differs |
| 2|2025-01-01 | oasis | census | 1032 | 1077 | differs |
| 2|2025-01-01 | oasis | ltc_census | 102 | 103 | differs |
| 2|2025-01-01 | oasis | alos | 28.4597868217054 | 3.15694444444445 | differs |
| 2|2025-01-01 | oasis | ltc_alos | 255.589052287582 | 33.5458333333333 | differs |
| 2|2025-01-01 | oasis | non_ltc_alos | 3.54883512544803 | 3.05485411223093 | differs |
| 2|2025-01-01 | oasis | total_bed_nights | 5346 | 5032 | differs |
| 2|2025-01-01 | oasis | available_bed_nights | 7936 | 9807 | differs |
| 2|2025-01-01 | oasis | occupancy_rate | 0.673639112903226 | 0.513102885693892 | differs |
| 5|2025-12-01 | oasis | available_beds | 203 | 201 | differs |
| 5|2025-12-01 | oasis | census | 989 | 1118 | differs |
| 5|2025-12-01 | oasis | ltc_census | 141 | 143 | differs |
| 5|2025-12-01 | oasis | alos | 53.8933265925177 | 19.8606375621048 | differs |
| 5|2025-12-01 | oasis | ltc_alos | 357.646572104019 | 185.873458485959 | differs |
| 5|2025-12-01 | oasis | non_ltc_alos | 3.38718553459119 | 2.9433176247356 | differs |
| 5|2025-12-01 | oasis | total_bed_nights | 4916 | 3758 | differs |
| 5|2025-12-01 | oasis | available_bed_nights | 6293 | 6233 | differs |
| 5|2025-12-01 | oasis | occupancy_rate | 0.781185444144287 | 0.602919942242901 | differs |
| 6|2025-08-01 | oasis | available_beds | 209 | 144 | differs |
| 6|2025-08-01 | oasis | census | 474 | 501 | differs |
| 6|2025-08-01 | oasis | alos | 31.7162447257384 | 7.75754733278054 | differs |
| 6|2025-08-01 | oasis | ltc_alos | 160.303125 | 64.1320138888889 | differs |
| 6|2025-08-01 | oasis | non_ltc_alos | 5.60723350253807 | 4.80600458115183 | differs |
| 6|2025-08-01 | oasis | total_bed_nights | 3413 | 2550 | differs |
| 6|2025-08-01 | oasis | available_bed_nights | 6479 | 4451 | differs |
| 6|2025-08-01 | oasis | occupancy_rate | 0.526778823892576 | 0.572904965176365 | differs |
| 3|2025-07-01 | oasis | available_beds | 235 | 251 | differs |
| 3|2025-07-01 | oasis | census | 1286 | 1426 | differs |
| 3|2025-07-01 | oasis | ltc_census | 102 | 103 | differs |
| 3|2025-07-01 | oasis | alos | 28.110743908761 | 3.388901130698 | differs |
| 3|2025-07-01 | oasis | ltc_alos | 323.630310457516 | 114.438839285714 | differs |
| 3|2025-07-01 | oasis | non_ltc_alos | 2.65213260135135 | 2.12901528453089 | differs |
| 3|2025-07-01 | oasis | total_bed_nights | 4897 | 4256 | differs |
| 3|2025-07-01 | oasis | available_bed_nights | 7285 | 7767 | differs |
| 3|2025-07-01 | oasis | occupancy_rate | 0.672203157172272 | 0.547959315050856 | differs |
| 1|2025-10-01 | oasis | available_beds | 463 | 451 | differs |
| 1|2025-10-01 | oasis | census | 1054 | 1120 | differs |
| 1|2025-10-01 | oasis | alos | 177.953747628083 | 4.84844451687672 | differs |
| 1|2025-10-01 | oasis | ltc_alos | 625.665962837838 | 129.20186965812 | differs |
| 1|2025-10-01 | oasis | non_ltc_alos | 3.12153693931398 | 2.70441994547598 | differs |
| 1|2025-10-01 | oasis | total_bed_nights | 10321 | 10612 | differs |
| 1|2025-10-01 | oasis | available_bed_nights | 14353 | 13981 | differs |
| 1|2025-10-01 | oasis | occupancy_rate | 0.719083118511809 | 0.759030112295258 | differs |
| 5|2025-08-01 | oasis | available_beds | 203 | 212 | differs |
| 5|2025-08-01 | oasis | census | 782 | 887 | differs |
| 5|2025-08-01 | oasis | ltc_census | 113 | 114 | differs |
| 5|2025-08-01 | oasis | alos | 64.8864556692242 | 3.12170235878336 | differs |
| 5|2025-08-01 | oasis | ltc_alos | 429.905235988201 | 110.343055555556 | differs |
| 5|2025-08-01 | oasis | non_ltc_alos | 3.23156452416542 | 2.67056062022752 | differs |
| 5|2025-08-01 | oasis | total_bed_nights | 4885 | 3141 | differs |
| 5|2025-08-01 | oasis | available_bed_nights | 6293 | 6557 | differs |
| 5|2025-08-01 | oasis | occupancy_rate | 0.776259335769903 | 0.479030044227543 | differs |
| 2|2025-07-01 | oasis | available_beds | 256 | 313 | differs |
| 2|2025-07-01 | oasis | census | 1022 | 1074 | differs |
| 2|2025-07-01 | oasis | ltc_census | 135 | 136 | differs |
| 2|2025-07-01 | oasis | alos | 35.5008561643836 | 4.80784336856675 | differs |
| 2|2025-07-01 | oasis | ltc_alos | 244.73024691358 | 106.834523809524 | differs |
| 2|2025-07-01 | oasis | non_ltc_alos | 3.6564731304021 | 3.16414540979414 | differs |
| 2|2025-07-01 | oasis | total_bed_nights | 5961 | 5665 | differs |
| 2|2025-07-01 | oasis | available_bed_nights | 7936 | 9713 | differs |
| 2|2025-07-01 | oasis | occupancy_rate | 0.751134072580645 | 0.583238958097395 | differs |
| 1|2025-04-01 | oasis | available_beds | 463 | 501 | differs |
| 1|2025-04-01 | oasis | census | 827 | 865 | differs |
| 1|2025-04-01 | oasis | ltc_census | 282 | 284 | differs |
| 1|2025-04-01 | oasis | alos | 222.345072551391 | 9.09387131115072 | differs |
| 1|2025-04-01 | oasis | ltc_alos | 646.474290780142 | 200.442214912281 | differs |
| 1|2025-04-01 | oasis | non_ltc_alos | 2.88738532110092 | 2.38608804838048 | differs |
| 1|2025-04-01 | oasis | available_bed_nights | 13890 | 15032 | differs |
| 1|2025-04-01 | oasis | occupancy_rate | 0.634557235421166 | 0.586016498137307 | differs |
| 6|2025-12-01 | oasis | available_beds | 209 | 192 | differs |
| 6|2025-12-01 | oasis | census | 473 | 493 | differs |
| 6|2025-12-01 | oasis | alos | 33.6193622269204 | 8.78177464896214 | differs |
| 6|2025-12-01 | oasis | ltc_alos | 173.053571428571 | 86.7212962962963 | differs |
| 6|2025-12-01 | oasis | non_ltc_alos | 6.50715488215488 | 5.43193847500796 | differs |
| 6|2025-12-01 | oasis | total_bed_nights | 3403 | 3016 | differs |
| 6|2025-12-01 | oasis | available_bed_nights | 6479 | 5952 | differs |
| 6|2025-12-01 | oasis | occupancy_rate | 0.525235375829603 | 0.506720430107527 | differs |
| ... | | 535 more | | | |

## vw_rcm

Keys (hospital_id, period): old 88, new 88. Differences: 902.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 5|2025-06-01 | oasis | total_submitted_claims | 13012469.2500004 | 13278111.8099999 | differs |
| 5|2025-06-01 | oasis | not_submitted_claims | 259710.13 | 351404.31 | differs |
| 5|2025-06-01 | oasis | approved_amount | 10947421.6000001 | 10644651.48 | differs |
| 5|2025-06-01 | oasis | rejections | 2065047.64999999 | 2089743.51999999 | differs |
| 5|2025-06-01 | oasis | rejection_rate_pct | 15.87 | 14.53 | differs |
| 5|2025-06-01 | oasis | approval_rate_pct | 84.13 | 74.02 | differs |
| 5|2025-06-01 | oasis | total_orders | 9131 | 13393 | differs |
| 5|2025-06-01 | oasis | approved_orders | 6898 | 7376 | differs |
| 5|2025-06-01 | oasis | approved_not_done | 1626 | 1945 | differs |
| 5|2025-06-01 | oasis | approved_not_done_pct | 17.81 | 14.52 | differs |
| 5|2025-06-01 | oasis | avg_tat_minutes | 32.1 | 73.2 | differs |
| 6|2025-10-01 | oasis | not_submitted_claims | 28967.12 | 6860.28 | differs |
| 6|2025-10-01 | oasis | approved_amount | 9388807.1399999 | 8148589.41999993 | differs |
| 6|2025-10-01 | oasis | rejections | 437062.759999999 | 2038681.56 | differs |
| 6|2025-10-01 | oasis | rejection_rate_pct | 4.45 | 18.23 | differs |
| 6|2025-10-01 | oasis | approval_rate_pct | 95.55 | 72.88 | differs |
| 6|2025-10-01 | oasis | total_orders | 4688 | 6560 | differs |
| 6|2025-10-01 | oasis | approved_orders | 3547 | 3662 | differs |
| 6|2025-10-01 | oasis | approved_not_done | 1083 | 1292 | differs |
| 6|2025-10-01 | oasis | approved_not_done_pct | 23.1 | 19.7 | differs |
| 6|2025-10-01 | oasis | avg_tat_minutes | 39.9 | 90.9 | differs |
| 8|2026-08-01 | oasis | not_submitted_claims | 0 | 23746.02 | differs |
| 8|2026-08-01 | oasis | approved_amount | 23746.02 | 0 | differs |
| 8|2026-08-01 | oasis | approval_rate_pct | 100 | 0 | differs |
| 8|2026-08-01 | oasis | total_orders | 52 | 193 | differs |
| 8|2026-08-01 | oasis | approved_orders | 28 | 29 | differs |
| 8|2026-08-01 | oasis | approved_not_done | 11 | 13 | differs |
| 8|2026-08-01 | oasis | approved_not_done_pct | 21.15 | 6.74 | differs |
| 8|2026-08-01 | oasis | avg_tat_minutes | 39.3 | 52.9 | differs |
| 6|2025-09-01 | oasis | total_submitted_claims | 9465318.33999985 | 9824412.45999989 | differs |
| 6|2025-09-01 | oasis | not_submitted_claims | 1198.4 | 312660.2 | differs |
| 6|2025-09-01 | oasis | approved_amount | 9245407.72999987 | 7672116.84999986 | differs |
| 6|2025-09-01 | oasis | rejections | 219910.61 | 1985228.29 | differs |
| 6|2025-09-01 | oasis | rejection_rate_pct | 2.32 | 18.38 | differs |
| 6|2025-09-01 | oasis | approval_rate_pct | 97.68 | 71.02 | differs |
| 6|2025-09-01 | oasis | total_orders | 3502 | 5165 | differs |
| 6|2025-09-01 | oasis | approved_orders | 2716 | 2743 | differs |
| 6|2025-09-01 | oasis | approved_not_done | 890 | 1013 | differs |
| 6|2025-09-01 | oasis | approved_not_done_pct | 25.41 | 19.61 | differs |
| 6|2025-09-01 | oasis | avg_tat_minutes | 49 | 106.9 | differs |
| 6|2026-09-01 | oasis | not_submitted_claims | 409479.98 | 1596621.28 | differs |
| 6|2026-09-01 | oasis | approved_amount | 1604108.73 | 0 | differs |
| 6|2026-09-01 | oasis | approval_rate_pct | 100 | 0 | differs |
| 6|2026-09-01 | oasis | total_orders | 5260 | 10114 | differs |
| 6|2026-09-01 | oasis | approved_orders | 3707 | 3682 | differs |
| 6|2026-09-01 | oasis | approved_not_done | 988 | 1082 | differs |
| 6|2026-09-01 | oasis | approved_not_done_pct | 18.78 | 10.7 | differs |
| 6|2026-09-01 | oasis | avg_tat_minutes | 36.7 | 70.2 | differs |
| 1|2025-07-01 | oasis | total_submitted_claims | 14411909.02 | 14696414.1199998 | differs |
| 1|2025-07-01 | oasis | not_submitted_claims | 56092.62 | 82359.5599999999 | differs |
| 1|2025-07-01 | oasis | approved_amount | 12613102.3599997 | 12387626.9799997 | differs |
| 1|2025-07-01 | oasis | rejections | 1798807.88 | 1651618.31000001 | differs |
| 1|2025-07-01 | oasis | rejection_rate_pct | 12.48 | 10.36 | differs |
| 1|2025-07-01 | oasis | approval_rate_pct | 87.52 | 77.73 | differs |
| 1|2025-07-01 | oasis | total_orders | 16793 | 27826 | differs |
| 1|2025-07-01 | oasis | approved_orders | 12686 | 14690 | differs |
| 1|2025-07-01 | oasis | approved_not_done | 3018 | 3881 | differs |
| 1|2025-07-01 | oasis | approved_not_done_pct | 17.97 | 13.95 | differs |
| 1|2025-07-01 | oasis | avg_tat_minutes | 42.6 | 68 | differs |
| 2|2025-01-01 | oasis | not_submitted_claims | 50772.11 | 37575.02 | differs |
| 2|2025-01-01 | oasis | approved_amount | 4544842.71000004 | 4488975.19000005 | differs |
| 2|2025-01-01 | oasis | rejections | 2368147.10999999 | 1901224.38000004 | differs |
| 2|2025-01-01 | oasis | rejection_rate_pct | 34.26 | 26.55 | differs |
| 2|2025-01-01 | oasis | approval_rate_pct | 65.74 | 62.69 | differs |
| 2|2025-01-01 | oasis | total_orders | 17516 | 30107 | differs |
| 2|2025-01-01 | oasis | approved_orders | 12862 | 14031 | differs |
| 2|2025-01-01 | oasis | approved_not_done | 2999 | 3408 | differs |
| 2|2025-01-01 | oasis | approved_not_done_pct | 17.12 | 11.32 | differs |
| 2|2025-01-01 | oasis | avg_tat_minutes | 29.4 | 66.7 | differs |
| 1|2025-05-01 | oasis | total_submitted_claims | 15053524.2500004 | 15579635.5300005 | differs |
| 1|2025-05-01 | oasis | not_submitted_claims | 268355.33 | 294693.64 | differs |
| 1|2025-05-01 | oasis | approved_amount | 13359950.0600002 | 12953354.7500003 | differs |
| 1|2025-05-01 | oasis | rejections | 1693574.35000002 | 1651622.62999999 | differs |
| 1|2025-05-01 | oasis | rejection_rate_pct | 11.25 | 10.01 | differs |
| 1|2025-05-01 | oasis | approval_rate_pct | 88.75 | 78.47 | differs |
| 1|2025-05-01 | oasis | total_orders | 16879 | 27574 | differs |
| 1|2025-05-01 | oasis | approved_orders | 12632 | 14786 | differs |
| 1|2025-05-01 | oasis | approved_not_done | 2995 | 3802 | differs |
| 1|2025-05-01 | oasis | approved_not_done_pct | 17.74 | 13.79 | differs |
| 1|2025-05-01 | oasis | avg_tat_minutes | 36.5 | 57.9 | differs |
| 1|2025-06-01 | oasis | total_submitted_claims | 13407745.3999998 | 13677873.4799998 | differs |
| 1|2025-06-01 | oasis | not_submitted_claims | 13079.13 | 265698.07 | differs |
| 1|2025-06-01 | oasis | approved_amount | 11726232.3599998 | 11576148.5399999 | differs |
| 1|2025-06-01 | oasis | rejections | 1681513.20000001 | 1639772.38999999 | differs |
| 1|2025-06-01 | oasis | rejection_rate_pct | 12.54 | 11 | differs |
| 1|2025-06-01 | oasis | approval_rate_pct | 87.46 | 77.66 | differs |
| 1|2025-06-01 | oasis | total_orders | 15539 | 24788 | differs |
| 1|2025-06-01 | oasis | approved_orders | 11655 | 13820 | differs |
| 1|2025-06-01 | oasis | approved_not_done | 2955 | 3704 | differs |
| 1|2025-06-01 | oasis | approved_not_done_pct | 19.02 | 14.94 | differs |
| 1|2025-06-01 | oasis | avg_tat_minutes | 34.3 | 52.9 | differs |
| 4|2025-12-01 | oasis | total_submitted_claims | 17850224.6200004 | 18112267.3599996 | differs |
| 4|2025-12-01 | oasis | not_submitted_claims | 37687.45 | 304147.63 | differs |
| 4|2025-12-01 | oasis | approved_amount | 15834265.1799994 | 15713263.5699991 | differs |
| 4|2025-12-01 | oasis | rejections | 2015959.73 | 2047799.11000002 | differs |
| 4|2025-12-01 | oasis | rejection_rate_pct | 11.29 | 10.08 | differs |
| 4|2025-12-01 | oasis | approval_rate_pct | 88.71 | 77.38 | differs |
| 4|2025-12-01 | oasis | total_orders | 19431 | 28742 | differs |
| 4|2025-12-01 | oasis | approved_orders | 14014 | 14908 | differs |
| 4|2025-12-01 | oasis | approved_not_done | 2618 | 3379 | differs |
| 4|2025-12-01 | oasis | approved_not_done_pct | 13.47 | 11.76 | differs |
| 4|2025-12-01 | oasis | avg_tat_minutes | 27.1 | 41.4 | differs |
| 3|2025-03-01 | oasis | total_submitted_claims | 17732864.4500004 | 7181519.0600001 | differs |
| 3|2025-03-01 | oasis | not_submitted_claims | 11677417.3200002 | 1124753.89 | differs |
| 3|2025-03-01 | oasis | approved_amount | 15889611.9700003 | 4159767.07000005 | differs |
| 3|2025-03-01 | oasis | rejections | 1843252.91000001 | 1956925.28000002 | differs |
| 3|2025-03-01 | oasis | rejection_rate_pct | 10.39 | 28.67 | differs |
| 3|2025-03-01 | oasis | approval_rate_pct | 89.61 | 60.95 | differs |
| 3|2025-03-01 | oasis | total_orders | 11498 | 15373 | differs |
| 3|2025-03-01 | oasis | approved_orders | 8617 | 8389 | differs |
| 3|2025-03-01 | oasis | approved_not_done | 1690 | 2085 | differs |
| 3|2025-03-01 | oasis | approved_not_done_pct | 14.7 | 13.56 | differs |
| 3|2025-03-01 | oasis | avg_tat_minutes | 29.7 | 58.8 | differs |
| 3|2026-08-01 | oasis | total_submitted_claims | 34533461.660003 | 35120773.7700029 | differs |
| 3|2026-08-01 | oasis | not_submitted_claims | 587.77 | 702199.499999999 | differs |
| 3|2026-08-01 | oasis | approved_amount | 27901125.4100008 | 27537850.8100003 | differs |
| 3|2026-08-01 | oasis | rejections | 6632337.30999956 | 7621686.16000008 | differs |
| 3|2026-08-01 | oasis | rejection_rate_pct | 19.21 | 19.39 | differs |
| 3|2026-08-01 | oasis | approval_rate_pct | 80.79 | 70.05 | differs |
| 3|2026-08-01 | oasis | total_orders | 17495 | 28100 | differs |
| 3|2026-08-01 | oasis | approved_orders | 13830 | 14384 | differs |
| 3|2026-08-01 | oasis | approved_not_done | 2326 | 2914 | differs |
| 3|2026-08-01 | oasis | approved_not_done_pct | 13.3 | 10.37 | differs |
| 3|2026-08-01 | oasis | avg_tat_minutes | 32.5 | 58.5 | differs |
| 4|2025-08-01 | oasis | total_submitted_claims | 13159436.97 | 13805359.8 | differs |
| 4|2025-08-01 | oasis | not_submitted_claims | 3458.26 | 696314.939999999 | differs |
| 4|2025-08-01 | oasis | approved_amount | 12078085.84 | 11580081.7899998 | differs |
| 4|2025-08-01 | oasis | rejections | 1081351.37 | 1571302.58999999 | differs |
| 4|2025-08-01 | oasis | rejection_rate_pct | 8.22 | 10.51 | differs |
| 4|2025-08-01 | oasis | approval_rate_pct | 91.78 | 77.44 | differs |
| 4|2025-08-01 | oasis | total_orders | 15243 | 21228 | differs |
| 4|2025-08-01 | oasis | approved_orders | 10141 | 10294 | differs |
| 4|2025-08-01 | oasis | approved_not_done | 2306 | 2388 | differs |
| 4|2025-08-01 | oasis | approved_not_done_pct | 15.13 | 11.25 | differs |
| 4|2025-08-01 | oasis | avg_tat_minutes | 26.5 | 47.9 | differs |
| 1|2025-10-01 | oasis | total_submitted_claims | 17560139.7099998 | 17859306.8499994 | differs |
| 1|2025-10-01 | oasis | not_submitted_claims | 24594.04 | 178754.53 | differs |
| 1|2025-10-01 | oasis | approved_amount | 15769118.8399997 | 15270892.7799994 | differs |
| 1|2025-10-01 | oasis | rejections | 1842719.97000001 | 2033650.02000001 | differs |
| 1|2025-10-01 | oasis | rejection_rate_pct | 10.49 | 10.29 | differs |
| 1|2025-10-01 | oasis | approval_rate_pct | 89.8 | 77.25 | differs |
| 1|2025-10-01 | oasis | total_orders | 18727 | 33222 | differs |
| 1|2025-10-01 | oasis | approved_orders | 14430 | 17153 | differs |
| 1|2025-10-01 | oasis | approved_not_done | 3802 | 4756 | differs |
| 1|2025-10-01 | oasis | approved_not_done_pct | 20.3 | 14.32 | differs |
| 1|2025-10-01 | oasis | avg_tat_minutes | 36 | 49.8 | differs |
| 1|2025-09-01 | oasis | total_submitted_claims | 14911107.4899998 | 15452252.9499999 | differs |
| 1|2025-09-01 | oasis | not_submitted_claims | 57196.26 | 573406.26 | differs |
| 1|2025-09-01 | oasis | approved_amount | 13129438.2099999 | 12754173.31 | differs |
| 1|2025-09-01 | oasis | rejections | 1801132.76000001 | 1757477.96000001 | differs |
| 1|2025-09-01 | oasis | rejection_rate_pct | 12.08 | 10.64 | differs |
| 1|2025-09-01 | oasis | approval_rate_pct | 88.05 | 77.23 | differs |
| 1|2025-09-01 | oasis | total_orders | 17196 | 28944 | differs |
| 1|2025-09-01 | oasis | approved_orders | 13266 | 15801 | differs |
| 1|2025-09-01 | oasis | approved_not_done | 3414 | 3916 | differs |
| 1|2025-09-01 | oasis | approved_not_done_pct | 19.85 | 13.53 | differs |
| 1|2025-09-01 | oasis | avg_tat_minutes | 40.4 | 53.6 | differs |
| 1|2026-09-01 | oasis | total_submitted_claims | 8856539.2299998 | 8933591.1599995 | differs |
| 1|2026-09-01 | oasis | not_submitted_claims | 1701770.72999999 | 8472674.54999962 | differs |
| 1|2026-09-01 | oasis | approved_amount | 8833834.0999998 | 111158.37 | differs |
| 1|2026-09-01 | oasis | rejections | 22705.13 | 23555.17 | differs |
| 1|2026-09-01 | oasis | rejection_rate_pct | 0.26 | 16.99 | differs |
| 1|2026-09-01 | oasis | approval_rate_pct | 99.74 | 80.19 | differs |
| 1|2026-09-01 | oasis | total_orders | 26237 | 39725 | differs |
| 1|2026-09-01 | oasis | approved_orders | 19055 | 22080 | differs |
| 1|2026-09-01 | oasis | approved_not_done | 3807 | 5178 | differs |
| 1|2026-09-01 | oasis | approved_not_done_pct | 14.51 | 13.03 | differs |
| 1|2026-09-01 | oasis | avg_tat_minutes | 35.8 | 50.2 | differs |
| 6|2025-07-01 | oasis | not_submitted_claims | 280 | 16700.34 | differs |
| 6|2025-07-01 | oasis | rejections | 1378027.91 | 1460475.07 | differs |
| 6|2025-07-01 | oasis | rejection_rate_pct | 14.08 | 13.09 | differs |
| 6|2025-07-01 | oasis | approval_rate_pct | 85.92 | 75.43 | differs |
| 6|2025-07-01 | oasis | total_orders | 3017 | 4518 | differs |
| 6|2025-07-01 | oasis | approved_orders | 2289 | 2090 | differs |
| 6|2025-07-01 | oasis | approved_not_done | 615 | 772 | differs |
| 6|2025-07-01 | oasis | approved_not_done_pct | 20.38 | 17.09 | differs |
| 6|2025-07-01 | oasis | avg_tat_minutes | 51.5 | 110.6 | differs |
| 6|2025-05-01 | oasis | not_submitted_claims | 309.31 | 891.62 | differs |
| 6|2025-05-01 | oasis | rejections | 284299.39 | 322133.67 | differs |
| 6|2025-05-01 | oasis | rejection_rate_pct | 4.26 | 4.21 | differs |
| 6|2025-05-01 | oasis | approval_rate_pct | 95.74 | 83.52 | differs |
| 6|2025-05-01 | oasis | total_orders | 1807 | 2240 | differs |
| 6|2025-05-01 | oasis | approved_orders | 1504 | 1156 | differs |
| 6|2025-05-01 | oasis | approved_not_done | 333 | 331 | differs |
| 6|2025-05-01 | oasis | approved_not_done_pct | 18.43 | 14.78 | differs |
| 6|2025-05-01 | oasis | avg_tat_minutes | 80.9 | 142.1 | differs |
| 5|2025-01-01 | oasis | total_submitted_claims | 6078477.63000002 | 6253507.56999994 | differs |
| 5|2025-01-01 | oasis | not_submitted_claims | 548496.04 | 335407.77 | differs |
| 5|2025-01-01 | oasis | approved_amount | 4576746.71000004 | 4033967.38000004 | differs |
| 5|2025-01-01 | oasis | rejections | 1501731.01000001 | 1451807.93000002 | differs |
| 5|2025-01-01 | oasis | rejection_rate_pct | 24.71 | 24.24 | differs |
| 5|2025-01-01 | oasis | approval_rate_pct | 75.29 | 67.36 | differs |
| 5|2025-01-01 | oasis | total_orders | 11012 | 17108 | differs |
| 5|2025-01-01 | oasis | approved_orders | 8765 | 8857 | differs |
| 5|2025-01-01 | oasis | approved_not_done | 2328 | 2573 | differs |
| 5|2025-01-01 | oasis | approved_not_done_pct | 21.14 | 15.04 | differs |
| 5|2025-01-01 | oasis | avg_tat_minutes | 35.7 | 57.4 | differs |
| 3|2025-12-01 | oasis | total_submitted_claims | 27804646.9500017 | 28124480.0500015 | differs |
| 3|2025-12-01 | oasis | not_submitted_claims | 2801.75 | 415955.35 | differs |
| 3|2025-12-01 | oasis | approved_amount | 25209346.2400004 | 24688903.9100003 | differs |
| ... | | 702 more | | | |

## vw_work_force

Keys (branch_id, period): old 112, new 112. Differences: 312.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 4|2026-08-01 | both | headcount | 623 | 631 | differs |
| 4|2026-08-01 | both | doctors_headcount | 136 | 137 | differs |
| 4|2026-08-01 | both | pt_doctors_headcount | 48 | 17 | differs |
| 4|2026-08-01 | both | FTE | 599 | 622.5 | differs |
| 5|2026-08-01 | both | headcount | 567 | 563 | differs |
| 5|2026-08-01 | both | medical_headcount | 358 | 354 | differs |
| 5|2026-08-01 | both | doctors_headcount | 130 | 129 | differs |
| 5|2026-08-01 | both | FTE | 549 | 545 | differs |
| 5|2025-08-01 | oasis | headcount | 552 | 563 | differs |
| 5|2025-08-01 | oasis | medical_headcount | 373 | 381 | differs |
| 5|2025-08-01 | oasis | pt_doctors_headcount | 34 | 33 | differs |
| 5|2025-08-01 | oasis | FTE | 535 | 546.5 | differs |
| 6|2025-12-01 | oasis | headcount | 422 | 414 | differs |
| 6|2025-12-01 | oasis | medical_headcount | 310 | 306 | differs |
| 6|2025-12-01 | oasis | doctors_headcount | 126 | 124 | differs |
| 6|2025-12-01 | oasis | FTE | 391 | 383 | differs |
| 7|2025-12-01 | oasis | headcount | 2 | 1 | differs |
| 7|2025-12-01 | oasis | FTE | 1.5 | 0.5 | differs |
| 1|2025-04-01 | oasis | headcount | 881 | 903 | differs |
| 1|2025-04-01 | oasis | medical_headcount | 578 | 587 | differs |
| 1|2025-04-01 | oasis | doctors_headcount | 154 | 155 | differs |
| 1|2025-04-01 | oasis | pt_doctors_headcount | 34 | 33 | differs |
| 1|2025-04-01 | oasis | FTE | 864 | 886.5 | differs |
| 2|2025-06-01 | oasis | headcount | 703 | 710 | differs |
| 2|2025-06-01 | oasis | FTE | 675 | 682 | differs |
| 4|2025-12-01 | oasis | doctors_headcount | 112 | 113 | differs |
| 7|2026-08-01 | both | headcount | 308 | 322 | differs |
| 7|2026-08-01 | both | resignations | 11 | 12 | differs |
| 7|2026-08-01 | both | medical_headcount | 226 | 232 | differs |
| 7|2026-08-01 | both | doctors_headcount | 103 | 106 | differs |
| 7|2026-08-01 | both | pt_doctors_headcount | 13 | 15 | differs |
| 7|2026-08-01 | both | FTE | 301.5 | 314.5 | differs |
| 5|2025-06-01 | oasis | headcount | 538 | 544 | differs |
| 5|2025-06-01 | oasis | medical_headcount | 367 | 370 | differs |
| 5|2025-06-01 | oasis | pt_doctors_headcount | 25 | 23 | differs |
| 5|2025-06-01 | oasis | FTE | 525.5 | 532.5 | differs |
| 1|2025-12-01 | oasis | headcount | 1010 | 966 | differs |
| 1|2025-12-01 | oasis | medical_headcount | 626 | 630 | differs |
| 1|2025-12-01 | oasis | doctors_headcount | 167 | 170 | differs |
| 1|2025-12-01 | oasis | pt_doctors_headcount | 46 | 45 | differs |
| 1|2025-12-01 | oasis | FTE | 987 | 943.5 | differs |
| 2|2025-08-01 | oasis | headcount | 697 | 709 | differs |
| 2|2025-08-01 | oasis | medical_headcount | 487 | 496 | differs |
| 2|2025-08-01 | oasis | FTE | 669.5 | 681.5 | differs |
| 2|2026-08-01 | both | headcount | 705 | 652 | differs |
| 2|2026-08-01 | both | medical_headcount | 490 | 445 | differs |
| 2|2026-08-01 | both | doctors_headcount | 145 | 141 | differs |
| 2|2026-08-01 | both | pt_doctors_headcount | 53 | 52 | differs |
| 2|2026-08-01 | both | FTE | 678.5 | 626 | differs |
| 4|2025-04-01 | oasis | headcount | 527 | 534 | differs |
| 4|2025-04-01 | oasis | medical_headcount | 373 | 380 | differs |
| 4|2025-04-01 | oasis | doctors_headcount | 106 | 107 | differs |
| 4|2025-04-01 | oasis | pt_doctors_headcount | 28 | 27 | differs |
| 4|2025-04-01 | oasis | FTE | 513 | 520.5 | differs |
| 3|2026-09-01 | both | headcount | 758 | 766 | differs |
| 3|2026-09-01 | both | medical_headcount | 500 | 526 | differs |
| 3|2026-09-01 | both | doctors_headcount | 159 | 156 | differs |
| 3|2026-09-01 | both | pt_doctors_headcount | 59 | 69 | differs |
| 1|2026-09-01 | both | headcount | 948 | 1034 | differs |
| 1|2026-09-01 | both | medical_headcount | 637 | 668 | differs |
| 1|2026-09-01 | both | doctors_headcount | 194 | 184 | differs |
| 1|2026-09-01 | both | pt_doctors_headcount | 51 | 45 | differs |
| 1|2026-09-01 | both | FTE | 922.5 | 1011.5 | differs |
| 1|2025-07-01 | oasis | headcount | 872 | 885 | differs |
| 1|2025-07-01 | oasis | medical_headcount | 587 | 593 | differs |
| 1|2025-07-01 | oasis | FTE | 853.5 | 866.5 | differs |
| 2|2025-05-01 | oasis | headcount | 701 | 706 | differs |
| 2|2025-05-01 | oasis | medical_headcount | 498 | 502 | differs |
| 2|2025-05-01 | oasis | doctors_headcount | 154 | 155 | differs |
| 2|2025-05-01 | oasis | pt_doctors_headcount | 56 | 55 | differs |
| 2|2025-05-01 | oasis | FTE | 673 | 678.5 | differs |
| 6|2026-09-01 | both | headcount | 441 | 476 | differs |
| 6|2026-09-01 | both | resignations | 0 | 2 | differs |
| 6|2026-09-01 | both | medical_headcount | 351 | 362 | differs |
| 6|2026-09-01 | both | doctors_headcount | 151 | 161 | differs |
| 6|2026-09-01 | both | pt_doctors_headcount | 68 | 61 | differs |
| 6|2026-09-01 | both | FTE | 407 | 445.5 | differs |
| 6|2025-07-01 | oasis | headcount | 337 | 343 | differs |
| 6|2025-07-01 | oasis | medical_headcount | 241 | 244 | differs |
| 6|2025-07-01 | oasis | doctors_headcount | 120 | 121 | differs |
| 6|2025-07-01 | oasis | FTE | 307 | 313 | differs |
| 5|2025-05-01 | oasis | headcount | 526 | 538 | differs |
| 5|2025-05-01 | oasis | medical_headcount | 355 | 360 | differs |
| 5|2025-05-01 | oasis | doctors_headcount | 106 | 109 | differs |
| 5|2025-05-01 | oasis | pt_doctors_headcount | 20 | 21 | differs |
| 5|2025-05-01 | oasis | FTE | 516 | 527.5 | differs |
| 8|2026-08-01 | both | headcount | 38 | 146 | differs |
| 8|2026-08-01 | both | resignations | 0 | 1 | differs |
| 8|2026-08-01 | both | medical_headcount | 37 | 122 | differs |
| 8|2026-08-01 | both | doctors_headcount | 37 | 86 | differs |
| 8|2026-08-01 | both | pt_doctors_headcount | 37 | 8 | differs |
| 8|2026-08-01 | both | FTE | 19.5 | 142 | differs |
| 4|2026-09-01 | both | medical_headcount | 412 | 418 | differs |
| 4|2026-09-01 | both | doctors_headcount | 128 | 133 | differs |
| 4|2026-09-01 | both | pt_doctors_headcount | 43 | 14 | differs |
| 4|2026-09-01 | both | FTE | 578.5 | 591 | differs |
| 4|2025-07-01 | oasis | medical_headcount | 377 | 382 | differs |
| 4|2025-07-01 | oasis | pt_doctors_headcount | 21 | 20 | differs |
| 4|2025-09-01 | oasis | medical_headcount | 374 | 383 | differs |
| 4|2025-09-01 | oasis | doctors_headcount | 101 | 102 | differs |
| 4|2025-09-01 | oasis | pt_doctors_headcount | 23 | 22 | differs |
| 3|2025-11-01 | oasis | doctors_headcount | 146 | 145 | differs |
| 2|2025-10-01 | oasis | headcount | 716 | 728 | differs |
| 2|2025-10-01 | oasis | medical_headcount | 485 | 496 | differs |
| 2|2025-10-01 | oasis | doctors_headcount | 145 | 150 | differs |
| 2|2025-10-01 | oasis | FTE | 689.5 | 701.5 | differs |
| 1|2025-11-01 | oasis | headcount | 958 | 969 | differs |
| 1|2025-11-01 | oasis | medical_headcount | 597 | 604 | differs |
| 1|2025-11-01 | oasis | doctors_headcount | 158 | 159 | differs |
| 1|2025-11-01 | oasis | FTE | 937 | 948 | differs |
| 5|2025-03-01 | oasis | headcount | 519 | 531 | differs |
| 5|2025-03-01 | oasis | FTE | 507 | 519 | differs |
| 6|2025-09-01 | oasis | headcount | 366 | 376 | differs |
| 6|2025-09-01 | oasis | medical_headcount | 266 | 270 | differs |
| 6|2025-09-01 | oasis | doctors_headcount | 117 | 118 | differs |
| 6|2025-09-01 | oasis | FTE | 337.5 | 347.5 | differs |
| 6|2025-11-01 | oasis | headcount | 406 | 412 | differs |
| 6|2025-11-01 | oasis | medical_headcount | 294 | 299 | differs |
| 6|2025-11-01 | oasis | doctors_headcount | 130 | 131 | differs |
| 6|2025-11-01 | oasis | FTE | 372 | 378 | differs |
| 2|2025-03-01 | oasis | headcount | 695 | 704 | differs |
| 2|2025-03-01 | oasis | medical_headcount | 499 | 503 | differs |
| 2|2025-03-01 | oasis | doctors_headcount | 158 | 159 | differs |
| 2|2025-03-01 | oasis | FTE | 665 | 674 | differs |
| 1|2025-09-01 | oasis | headcount | 903 | 930 | differs |
| 1|2025-09-01 | oasis | medical_headcount | 586 | 604 | differs |
| 1|2025-09-01 | oasis | doctors_headcount | 151 | 154 | differs |
| 1|2025-09-01 | oasis | pt_doctors_headcount | 33 | 32 | differs |
| 1|2025-09-01 | oasis | FTE | 886.5 | 914 | differs |
| 3|2025-09-01 | oasis | headcount | 687 | 697 | differs |
| 3|2025-09-01 | oasis | medical_headcount | 429 | 433 | differs |
| 3|2025-09-01 | oasis | doctors_headcount | 144 | 145 | differs |
| 3|2025-09-01 | oasis | FTE | 659.5 | 669.5 | differs |
| 4|2025-11-01 | oasis | headcount | 584 | 572 | differs |
| 4|2025-11-01 | oasis | doctors_headcount | 106 | 107 | differs |
| 4|2025-11-01 | oasis | pt_doctors_headcount | 28 | 29 | differs |
| 4|2025-11-01 | oasis | FTE | 570 | 557.5 | differs |
| 1|2025-01-01 | oasis | headcount | 868 | 877 | differs |
| 1|2025-01-01 | oasis | medical_headcount | 562 | 565 | differs |
| 1|2025-01-01 | oasis | FTE | 852 | 861 | differs |
| 5|2025-02-01 | oasis | headcount | 504 | 513 | differs |
| 5|2025-02-01 | oasis | medical_headcount | 327 | 334 | differs |
| 5|2025-02-01 | oasis | doctors_headcount | 105 | 106 | differs |
| 5|2025-02-01 | oasis | FTE | 491 | 500 | differs |
| 3|2025-01-01 | oasis | headcount | 624 | 661 | differs |
| 3|2025-01-01 | oasis | medical_headcount | 397 | 400 | differs |
| 3|2025-01-01 | oasis | doctors_headcount | 137 | 139 | differs |
| 3|2025-01-01 | oasis | FTE | 598 | 635 | differs |
| 4|2025-01-01 | oasis | headcount | 505 | 530 | differs |
| 4|2025-01-01 | oasis | medical_headcount | 350 | 357 | differs |
| 4|2025-01-01 | oasis | FTE | 491 | 516 | differs |
| 6|2025-01-01 | oasis | medical_headcount | 184 | 185 | differs |
| 6|2025-01-01 | oasis | doctors_headcount | 78 | 79 | differs |
| 2|2025-02-01 | oasis | headcount | 725 | 731 | differs |
| 2|2025-02-01 | oasis | pt_doctors_headcount | 62 | 60 | differs |
| 2|2025-02-01 | oasis | FTE | 694 | 701 | differs |
| 3|2025-02-01 | oasis | headcount | 648 | 655 | differs |
| 3|2025-02-01 | oasis | medical_headcount | 407 | 412 | differs |
| 3|2025-02-01 | oasis | doctors_headcount | 137 | 139 | differs |
| 3|2025-02-01 | oasis | FTE | 623 | 630 | differs |
| 1|2025-02-01 | oasis | headcount | 867 | 876 | differs |
| 1|2025-02-01 | oasis | medical_headcount | 564 | 570 | differs |
| 1|2025-02-01 | oasis | pt_doctors_headcount | 32 | 31 | differs |
| 1|2025-02-01 | oasis | FTE | 851 | 860.5 | differs |
| 5|2025-01-01 | oasis | headcount | 466 | 473 | differs |
| 5|2025-01-01 | oasis | medical_headcount | 290 | 295 | differs |
| 5|2025-01-01 | oasis | FTE | 453 | 460 | differs |
| 6|2025-02-01 | oasis | medical_headcount | 178 | 179 | differs |
| 6|2025-02-01 | oasis | doctors_headcount | 82 | 83 | differs |
| 2|2025-01-01 | oasis | headcount | 697 | 744 | differs |
| 2|2025-01-01 | oasis | pt_doctors_headcount | 60 | 58 | differs |
| 2|2025-01-01 | oasis | FTE | 667 | 715 | differs |
| 8|2025-11-01 | oasis | headcount | 0 | 1 | differs |
| 8|2025-11-01 | oasis | FTE | 0 | 1 | differs |
| 4|2025-02-01 | oasis | headcount | 527 | 536 | differs |
| 4|2025-02-01 | oasis | medical_headcount | 377 | 383 | differs |
| 4|2025-02-01 | oasis | pt_doctors_headcount | 25 | 24 | differs |
| 4|2025-02-01 | oasis | FTE | 514.5 | 524 | differs |
| 5|2025-11-01 | oasis | medical_headcount | 352 | 349 | differs |
| 5|2025-11-01 | oasis | doctors_headcount | 126 | 127 | differs |
| 6|2025-10-01 | oasis | headcount | 383 | 385 | differs |
| 6|2025-10-01 | oasis | medical_headcount | 273 | 275 | differs |
| 6|2025-10-01 | oasis | doctors_headcount | 121 | 122 | differs |
| 6|2025-10-01 | oasis | FTE | 353.5 | 355.5 | differs |
| 2|2025-09-01 | oasis | headcount | 690 | 700 | differs |
| 2|2025-09-01 | oasis | medical_headcount | 489 | 495 | differs |
| 2|2025-09-01 | oasis | FTE | 660 | 670 | differs |
| 1|2025-03-01 | oasis | headcount | 872 | 891 | differs |
| 1|2025-03-01 | oasis | medical_headcount | 568 | 579 | differs |
| 1|2025-03-01 | oasis | FTE | 856 | 875 | differs |
| 3|2025-03-01 | oasis | headcount | 638 | 643 | differs |
| 3|2025-03-01 | oasis | medical_headcount | 400 | 403 | differs |
| 3|2025-03-01 | oasis | FTE | 615.5 | 620.5 | differs |
| 7|2025-11-01 | oasis | headcount | 0 | 1 | differs |
| 7|2025-11-01 | oasis | FTE | 0 | 1 | differs |
| 4|2025-10-01 | oasis | headcount | 584 | 580 | differs |
| 4|2025-10-01 | oasis | medical_headcount | 376 | 380 | differs |
| 4|2025-10-01 | oasis | FTE | 570.5 | 566.5 | differs |
| 4|2025-03-01 | oasis | pt_doctors_headcount | 20 | 19 | differs |
| 3|2025-10-01 | oasis | doctors_headcount | 143 | 144 | differs |
| ... | | 112 more | | | |

## vw_income_statement_budget

Keys (branch_id, line_item_code, month_date): old 576, new 576. Differences: 0.

## vw_hospital

Keys (Id, Hospital, City): old 8, new 8. Differences: 2.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 2|Khamis|Asser |  | * |  |  | missing in new |
| 2|Khamis|Aseer |  | * |  |  | missing in old |

## vw_date_dim

Keys (Date): old 426, new 426. Differences: 0.

## targets

Keys (hospital_id, period_id, kpi_no, strategy_segment): old 2916, new 2916. Differences: 0.

## patient_satisfaction

Keys (hospital_id, period_id): old 56, new 56. Differences: 0.
