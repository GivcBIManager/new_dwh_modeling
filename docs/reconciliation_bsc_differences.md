# bsc views: old server against new (generated)

Generated 2026-10-13 10:52 by scripts/compare_bsc.ps1. Months: 2026-08-01, 2026-09-01 and the year 2025. Tolerance: 0.5% relative (absolute below 1). Attribution: docs/reconciliation_bsc.md.

## vw_customer

Keys (branch_id, period): old 89, new 112. Differences: 1414.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 4|2026-08-01 | non_moh_revenue | 9568303.15 | 9690241.12 | differs |
| 4|2026-08-01 | insurance_revenue | 7315856.09 | 7460246.12 | differs |
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
| 5|2026-08-01 | non_moh_revenue | 13366494.58 | 13504139.93 | differs |
| 5|2026-08-01 | insurance_revenue | 10442116.91 | 10845658.28 | differs |
| 5|2026-08-01 | referrals_revenue | 671967.97 | 666465.65 | differs |
| 5|2026-08-01 | credit_revenue | 16193291.55 | 16525306.88 | differs |
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
| 6|2025-12-01 | insurance_revenue | 2186224.82 | 2238187.43 | differs |
| 6|2025-12-01 | referrals_revenue | 802541.07 | 837447.73 | differs |
| 6|2025-12-01 | high_value_service_revenue | 2607133.04 | 2144027.42 | differs |
| 6|2025-12-01 | high_value_service_volume | 699 | 677 | differs |
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
| 3|2025-04-01 | revenue | 23967573.59 | 24094027.77 | differs |
| 3|2025-04-01 | non_ltc_ip_revenue | 10703389.99 | 10813812.69 | differs |
| 3|2025-04-01 | non_moh_revenue | 10647297.17 | 10704753.86 | differs |
| 3|2025-04-01 | insurance_revenue | 6543455.2 | 6601383.35 | differs |
| 3|2025-04-01 | referrals_revenue | 1145325.37 | 1158656.92 | differs |
| 3|2025-04-01 | credit_revenue | 20175813.01 | 20290975.89 | differs |
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
| 2|2025-06-01 | high_value_service_volume | 1464 | 316 | differs |
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
| 7|2026-08-01 | insurance_census | 2236 | 2223 | differs |
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
| 6|2025-04-01 | revenue | 5855457.8 | 5889140.57 | differs |
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
| 3|2025-12-01 | non_moh_revenue | 13851155.09 | 13968062.12 | differs |
| 3|2025-12-01 | insurance_revenue | 9627022.9 | 9703414.51 | differs |
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
| 1|2025-12-01 | credit_revenue | 27038237.01 | 27276312.9 | differs |
| 1|2025-12-01 | census | 19731 | 19504 | differs |
| 1|2025-12-01 | insurance_census | 16477 | 16291 | differs |
| 1|2025-12-01 | op_census | 17933 | 17815 | differs |
| 1|2025-12-01 | new_op_census | 2350 | 2336 | differs |
| 1|2025-12-01 | op_episodes | 13646 | 13241 | differs |
| 1|2025-12-01 | er_census | 1798 | 1689 | differs |
| 1|2025-12-01 | referrals_volume | 191 | 190 | differs |
| 1|2025-12-01 | available_slots | 30802 | 33334 | differs |
| ... | 1214 more | | | |

## vw_financial

Keys (branch_id, month_date): old 85, new 88. Differences: 515.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 1|2025-07-01 | ebitda_actual | 5893888.67 | 5940053.67 | differs |
| 1|2025-07-01 | account_receivable_actual | 12182234.5 | 153322891.14 | differs |
| 1|2025-07-01 | account_receivable_actual_opening_balance | 11980457.3 | 141140656.64 | differs |
| 1|2025-07-01 | consumables_actual | 1938666.39 | 4589553.96 | differs |
| 1|2025-07-01 | assets | -5776466.99 | 496326585.3 | differs |
| 1|2025-07-01 | assets_opening_balance | 2588151.45 | 502103052.29 | differs |
| 3|2025-09-01 | operating_expenses | 15671533.59 | 15456011.59 | differs |
| 3|2025-09-01 | ebitda_actual | 11590263.6 | 11805785.6 | differs |
| 3|2025-09-01 | account_receivable_actual | 2250855.87 | 174671403.68 | differs |
| 3|2025-09-01 | account_receivable_actual_opening_balance | 18925807.4 | 172420547.81 | differs |
| 3|2025-09-01 | consumables_actual | 1947653.19 | 3497649.93 | differs |
| 3|2025-09-01 | assets | 14238861.66 | 532751472.51 | differs |
| 3|2025-09-01 | assets_opening_balance | 14066176.91 | 518512610.85 | differs |
| 4|2025-02-01 | account_receivable_actual | -825233.28 | 96199890.12 | differs |
| 4|2025-02-01 | account_receivable_actual_opening_balance | 13412650.19 | 97025123.4 | differs |
| 4|2025-02-01 | consumables_actual | 1049253.88 | 2031798.52 | differs |
| 4|2025-02-01 | assets | 5599812.04 | 192328474.21 | differs |
| 4|2025-02-01 | assets_opening_balance | 8908064.1 | 186728662.17 | differs |
| 5|2025-03-01 | account_receivable_actual | -6223353.34 | 75383970.32 | differs |
| 5|2025-03-01 | account_receivable_actual_opening_balance | 6213566.79 | 81607323.66 | differs |
| 5|2025-03-01 | consumables_actual | 1082499.65 | 2233422.43 | differs |
| 5|2025-03-01 | assets | -701436.67 | 104331739.47 | differs |
| 5|2025-03-01 | assets_opening_balance | 5021197.64 | 105033176.14 | differs |
| 6|2025-08-01 | operating_expenses | 9822807.06 | 9772871.06 | differs |
| 6|2025-08-01 | ebitda_actual | 3020503.3 | 3070439.3 | differs |
| 6|2025-08-01 | account_receivable_actual | 3876166.74 | 56421119.19 | differs |
| 6|2025-08-01 | account_receivable_actual_opening_balance | 10909617.68 | 52544952.45 | differs |
| 6|2025-08-01 | consumables_actual | 1406945.13 | 2085817.01 | differs |
| 6|2025-08-01 | assets | 2580083.25 | 80280176.1 | differs |
| 6|2025-08-01 | assets_opening_balance | 3890935.41 | 77700092.85 | differs |
| 3|2025-08-01 | operating_expenses | 13718244.53 | 13502722.53 | differs |
| 3|2025-08-01 | ebitda_actual | 12900264.98 | 13115786.98 | differs |
| 3|2025-08-01 | account_receivable_actual | 18925807.4 | 172420547.81 | differs |
| 3|2025-08-01 | account_receivable_actual_opening_balance | 16795732.36 | 153494740.41 | differs |
| 3|2025-08-01 | consumables_actual | 1462542.45 | 2942856.1 | differs |
| 3|2025-08-01 | assets | 14066176.91 | 518512610.85 | differs |
| 3|2025-08-01 | assets_opening_balance | 12227460.1 | 504446433.94 | differs |
| 6|2025-09-01 | operating_expenses | 9077423.92 | 9027487.92 | differs |
| 6|2025-09-01 | ebitda_actual | 1661258.39 | 1711194.39 | differs |
| 6|2025-09-01 | account_receivable_actual | 10513493.64 | 66934612.83 | differs |
| 6|2025-09-01 | account_receivable_actual_opening_balance | 3876166.74 | 56421119.19 | differs |
| 6|2025-09-01 | consumables_actual | 657191.8 | 1219442.94 | differs |
| 6|2025-09-01 | assets | 1689099.69 | 81969275.79 | differs |
| 6|2025-09-01 | assets_opening_balance | 2580083.25 | 80280176.1 | differs |
| 5|2025-10-01 | account_receivable_actual | 2300156.36 | 94047882.48 | differs |
| 5|2025-10-01 | account_receivable_actual_opening_balance | -18302122.44 | 91747726.12 | differs |
| 5|2025-10-01 | consumables_actual | 1040966.15 | 2131876.81 | differs |
| 5|2025-10-01 | assets | 5655894.6 | 115328755.58 | differs |
| 5|2025-10-01 | assets_opening_balance | 1416746.01 | 109672860.98 | differs |
| 1|2025-02-01 | ebitda_actual | 8669010.089 | 8731737.56 | differs |
| 1|2025-02-01 | account_receivable_actual | 14650392.62 | 133422823.17 | differs |
| 1|2025-02-01 | account_receivable_actual_opening_balance | -30416644.14 | 118772430.55 | differs |
| 1|2025-02-01 | consumables_actual | 1154616.86 | 4032338.17 | differs |
| 1|2025-02-01 | assets | 8746693.22 | 501723494.48 | differs |
| 1|2025-02-01 | assets_opening_balance | 2026924.64 | 492976801.26 | differs |
| 4|2025-07-01 | account_receivable_actual | 6780213.4 | 83670524.2 | differs |
| 4|2025-07-01 | account_receivable_actual_opening_balance | -2264435.24 | 76890310.8 | differs |
| 4|2025-07-01 | consumables_actual | 874919.7 | 1967232.25 | differs |
| 4|2025-07-01 | assets | 3901345.77 | 199380538.12 | differs |
| 4|2025-07-01 | assets_opening_balance | 1792801.52 | 195479192.35 | differs |
| 3|2026-08-01 | net_revenue_actual | 3552019.66 | 40561310.51 | differs |
| 3|2026-08-01 | sub_revenue_actual | 3552019.66 | 43659200.94 | differs |
| 3|2026-08-01 | operating_expenses | -6908.32 | 24496140.32 | differs |
| 3|2026-08-01 | ebitda_actual | 3558927.98 | 16065170.19 | differs |
| 3|2026-08-01 | account_receivable_actual | 166370001.92 | 248977038.82 | differs |
| 3|2026-08-01 | account_receivable_actual_opening_balance | 251384632.23 | 293564622.34 | differs |
| 3|2026-08-01 | ga_expenses_actual | -6908.32 | 46297.51 | differs |
| 3|2026-08-01 | consumables_actual | 0 | 265978.81 | differs |
| 3|2026-08-01 | assets | 630651519.485 | 720207289.1 | differs |
| 3|2026-08-01 | assets_opening_balance | 578157532.551 | 688242909.13 | differs |
| 3|2026-08-01 | income | 3558927.98 | 16063504.42 | differs |
| 1|2025-12-01 | account_receivable_actual | 11261570.55 | 139848850.22 | differs |
| 1|2025-12-01 | account_receivable_actual_opening_balance | 11714529.31 | 128587279.67 | differs |
| 1|2025-12-01 | consumables_actual | 1786420.65 | 5087641.16 | differs |
| 1|2025-12-01 | assets | 1925899.59 | 512244913.92 | differs |
| 1|2025-12-01 | assets_opening_balance | 1825902.69 | 510319014.33 | differs |
| 1|2025-05-01 | ebitda_actual | 4211866.66 | 4258031.66 | differs |
| 1|2025-05-01 | account_receivable_actual | 16769201.58 | 129160199.34 | differs |
| 1|2025-05-01 | account_receivable_actual_opening_balance | 10907012.41 | 112390997.76 | differs |
| 1|2025-05-01 | consumables_actual | 1311525.19 | 4373664.99 | differs |
| 1|2025-05-01 | assets | 5931994.92 | 499514900.84 | differs |
| 1|2025-05-01 | assets_opening_balance | -3280045 | 493582905.92 | differs |
| 4|2025-12-01 | account_receivable_actual | 84333.01 | 103367189.03 | differs |
| 4|2025-12-01 | account_receivable_actual_opening_balance | 16445554.53 | 103282856.02 | differs |
| 4|2025-12-01 | consumables_actual | 1061306.13 | 2530779.6 | differs |
| 4|2025-12-01 | assets | 1240998.6 | 230706783.82 | differs |
| 4|2025-12-01 | assets_opening_balance | 10452578.28 | 229465785.22 | differs |
| 5|2025-06-01 | account_receivable_actual | 7729106.13 | 94699568.03 | differs |
| 5|2025-06-01 | account_receivable_actual_opening_balance | 2118588.82 | 86970461.9 | differs |
| 5|2025-06-01 | consumables_actual | 913002.81 | 1902822.07 | differs |
| 5|2025-06-01 | assets | 92418.95 | 105553528.8 | differs |
| 5|2025-06-01 | assets_opening_balance | 1824080.92 | 105461109.85 | differs |
| 2|2025-09-01 | account_receivable_actual | 3019096.87 | 162240301.45 | differs |
| 2|2025-09-01 | account_receivable_actual_opening_balance | 510087.87 | 159221204.58 | differs |
| 2|2025-09-01 | consumables_actual | 1710439.49 | 3334575.54 | differs |
| 2|2025-09-01 | assets | 10684331.14 | 758176855.8 | differs |
| 2|2025-09-01 | assets_opening_balance | 12240592.7 | 747492524.66 | differs |
| 4|2025-05-01 | account_receivable_actual | 10199584.87 | 79154746.04 | differs |
| 4|2025-05-01 | account_receivable_actual_opening_balance | -2431295.79 | 68955161.17 | differs |
| 4|2025-05-01 | consumables_actual | 1225195 | 2154094.09 | differs |
| 4|2025-05-01 | assets | 904682.07 | 193686390.83 | differs |
| 4|2025-05-01 | assets_opening_balance | 300445.25 | 192781708.76 | differs |
| 4|2025-10-01 | account_receivable_actual | 7836509.35 | 86837301.49 | differs |
| 4|2025-10-01 | account_receivable_actual_opening_balance | -11796656.11 | 79000792.14 | differs |
| 4|2025-10-01 | consumables_actual | 1090093.4 | 2522914.03 | differs |
| 4|2025-10-01 | assets | 10042083.74 | 219013206.94 | differs |
| 4|2025-10-01 | assets_opening_balance | 5010485.03 | 208971123.2 | differs |
| 5|2025-04-01 | account_receivable_actual | 9467902.76 | 84851873.08 | differs |
| 5|2025-04-01 | account_receivable_actual_opening_balance | -6223353.34 | 75383970.32 | differs |
| 5|2025-04-01 | consumables_actual | 501034.91 | 1578882.87 | differs |
| 5|2025-04-01 | assets | -694710.54 | 103637028.93 | differs |
| 5|2025-04-01 | assets_opening_balance | -701436.67 | 104331739.47 | differs |
| 5|2025-01-01 | account_receivable_actual | -9635056.75 | 75393756.87 | differs |
| 5|2025-01-01 | account_receivable_actual_opening_balance | 1487263.09 | 85028813.62 | differs |
| 5|2025-01-01 | consumables_actual | 1088046.85 | 2374234.18 | differs |
| 5|2025-01-01 | assets | 5204890.93 | 100011978.5 | differs |
| 5|2025-01-01 | assets_opening_balance | -944961.17 | 94807087.57 | differs |
| 6|2026-08-01 | net_revenue_actual | 16914582.16 | 16022436.26 | differs |
| 6|2026-08-01 | sub_revenue_actual | 16914582.16 | 18778571.49 | differs |
| 6|2026-08-01 | operating_expenses | 4096417.24 | 15466538.21 | differs |
| 6|2026-08-01 | ebitda_actual | 12818164.92 | 555898.05 | differs |
| 6|2026-08-01 | account_receivable_actual | 178928882.94 | 155025857.23 | differs |
| 6|2026-08-01 | account_receivable_actual_opening_balance | 161728055.12 | 139183713.24 | differs |
| 6|2026-08-01 | ga_expenses_actual | 0 | 2340920.05 | differs |
| 6|2026-08-01 | consumables_actual | 0 | 136789.33 | differs |
| 6|2026-08-01 | assets | 188417363.56 | 105773948.62 | differs |
| 6|2026-08-01 | assets_opening_balance | 169367163.03 | 103445504.1 | differs |
| 6|2026-08-01 | income | 12818170.67 | -391962.48 | differs |
| 1|2025-10-01 | ebitda_actual | 5831437.56 | 5877603.56 | differs |
| 1|2025-10-01 | account_receivable_actual | 1235717.77 | 116872750.36 | differs |
| 1|2025-10-01 | account_receivable_actual_opening_balance | -20964797.5 | 115637032.59 | differs |
| 1|2025-10-01 | consumables_actual | 2133158.98 | 5359916.57 | differs |
| 1|2025-10-01 | assets | 6162637.29 | 508493111.64 | differs |
| 1|2025-10-01 | assets_opening_balance | 2120883.39 | 502330474.35 | differs |
| 4|2026-09-01 | net_revenue_actual | 2911534.58 | 0 | differs |
| 4|2026-09-01 | sub_revenue_actual | 2911534.58 | 0 | differs |
| 4|2026-09-01 | operating_expenses | 0 | 280173.11 | differs |
| 4|2026-09-01 | ebitda_actual | 2911534.58 | -280173.11 | differs |
| 4|2026-09-01 | account_receivable_actual | 181934872.5 | 168177808.8 | differs |
| 4|2026-09-01 | account_receivable_actual_opening_balance | 181980569.69 | 168174808.8 | differs |
| 4|2026-09-01 | ga_expenses_actual | 0 | 9638.39 | differs |
| 4|2026-09-01 | assets | 187732761.73 | 301386692.56 | differs |
| 4|2026-09-01 | assets_opening_balance | 192142881.943 | 301819288.98 | differs |
| 4|2026-09-01 | income | 2911534.58 | -280284.66 | differs |
| 3|2025-11-01 | operating_expenses | 16424789.42 | 16209267.42 | differs |
| 3|2025-11-01 | ebitda_actual | 11511075.85 | 11726597.85 | differs |
| 3|2025-11-01 | account_receivable_actual | 18999074.86 | 186411121.37 | differs |
| 3|2025-11-01 | account_receivable_actual_opening_balance | -7259357.17 | 167412046.51 | differs |
| 3|2025-11-01 | consumables_actual | 1573826.52 | 3401898.15 | differs |
| 3|2025-11-01 | assets | 19080659.38 | 565147561.31 | differs |
| 3|2025-11-01 | assets_opening_balance | 13315429.41 | 546066901.93 | differs |
| 1|2026-09-01 | consumables_actual | 0 | -69912.74 | differs |
| 1|2026-09-01 | assets | 326219094.13 | 549069964.72 | differs |
| 1|2026-09-01 | assets_opening_balance | 338376255.4 | 563424258.86 | differs |
| 6|2025-11-01 | ebitda_actual | 3694519.889 | 3744455.89 | differs |
| 6|2025-11-01 | account_receivable_actual | 10024113.3 | 80948069.42 | differs |
| 6|2025-11-01 | account_receivable_actual_opening_balance | 3989343.29 | 70923956.12 | differs |
| 6|2025-11-01 | consumables_actual | 1038497.52 | 2451848.19 | differs |
| 6|2025-11-01 | assets | 6345263.29 | 89663833.76 | differs |
| 6|2025-11-01 | assets_opening_balance | 1349294.68 | 83318570.47 | differs |
| 2|2025-05-01 | account_receivable_actual | 17682753.78 | 137147452.41 | differs |
| 2|2025-05-01 | account_receivable_actual_opening_balance | 15293656.46 | 119464698.63 | differs |
| 2|2025-05-01 | consumables_actual | 1785200.88 | 3478227.08 | differs |
| 2|2025-05-01 | assets | 9055160.2 | 709782335.52 | differs |
| 2|2025-05-01 | assets_opening_balance | 5912881.78 | 700727175.32 | differs |
| 2|2025-12-01 | account_receivable_actual | 18594161.57 | 206295494.28 | differs |
| 2|2025-12-01 | account_receivable_actual_opening_balance | 18658132.88 | 187701332.71 | differs |
| 2|2025-12-01 | consumables_actual | 2396765.17 | 4162511 | differs |
| 2|2025-12-01 | assets | 8773417.84 | 796447254.43 | differs |
| 2|2025-12-01 | assets_opening_balance | 15022628.48 | 787673836.59 | differs |
| 3|2025-06-01 | operating_expenses | 13714186.84 | 13498664.84 | differs |
| 3|2025-06-01 | ebitda_actual | 8068492.53 | 8284014.53 | differs |
| 3|2025-06-01 | account_receivable_actual | 17399464.03 | 136699008.05 | differs |
| 3|2025-06-01 | account_receivable_actual_opening_balance | 2207077.3 | 119299544.02 | differs |
| 3|2025-06-01 | consumables_actual | 1350356.4 | 2603343.27 | differs |
| 3|2025-06-01 | assets | 7187067.97 | 492218973.84 | differs |
| 3|2025-06-01 | assets_opening_balance | 11145326.84 | 485031905.87 | differs |
| 2|2025-07-01 | account_receivable_actual | 21306345.9 | 158711116.71 | differs |
| 2|2025-07-01 | account_receivable_actual_opening_balance | 257318.4 | 137404770.81 | differs |
| 2|2025-07-01 | consumables_actual | 2390531.03 | 4072645.42 | differs |
| 2|2025-07-01 | assets | 17302222.35 | 735251931.96 | differs |
| 2|2025-07-01 | assets_opening_balance | 8167374.09 | 717949709.61 | differs |
| 2|2025-10-01 | account_receivable_actual | 6802898.38 | 169043199.83 | differs |
| 2|2025-10-01 | account_receivable_actual_opening_balance | 3019096.87 | 162240301.45 | differs |
| 2|2025-10-01 | consumables_actual | 2027320.87 | 3896034.63 | differs |
| 2|2025-10-01 | assets | 14474352.31 | 772651208.11 | differs |
| 2|2025-10-01 | assets_opening_balance | 10684331.14 | 758176855.8 | differs |
| 5|2026-08-01 | consumables_actual | 1307792.7 | 2452040.49 | differs |
| 5|2026-08-01 | assets | -14820670.306 | 145129831.64 | differs |
| 5|2026-08-01 | assets_opening_balance | -20377232.486 | 142617070.79 | differs |
| 6|2025-01-01 | account_receivable_actual | 4650783.01 | 8809254.07 | differs |
| 6|2025-01-01 | account_receivable_actual_opening_balance | 3684123.48 | 4158471.06 | differs |
| 6|2025-01-01 | consumables_actual | 234128.49 | 466175.58 | differs |
| 6|2025-01-01 | assets | -1501808.36 | 83324220.55 | differs |
| 6|2025-01-01 | assets_opening_balance | 51147275.44 | 84826028.91 | differs |
| 3|2025-01-01 | operating_expenses | 16364732.88 | 16149210.88 | differs |
| 3|2025-01-01 | ebitda_actual | 9442760.76 | 9658282.76 | differs |
| 3|2025-01-01 | account_receivable_actual | 3562252.56 | 128273513.42 | differs |
| 3|2025-01-01 | account_receivable_actual_opening_balance | 6218273.56 | 124711260.86 | differs |
| 3|2025-01-01 | consumables_actual | 1915046.18 | 3344515.78 | differs |
| ... | 315 more | | | |

## vw_gl_transactions

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 7042, new 8580. Differences: 8759.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 2|2025-07-01|IS|expenses|general and administrative expenses|repair & maintenance|security and cleaning expenses | OpeningBalance | 0 | 144426.63 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | Transaction_Balance | -181092 | 0 | differs |
| 5|2025-09-01|IS|revenue|revenue - discounts|revenue - settlement discount|rejection | OpeningBalance | 0 | 10478483.46 | differs |
| 3|2025-06-01|IS|other income|other income, net|other income, net|support medical companies | OpeningBalance | 0 | -166666.67 | differs |
| 4|2025-03-01|BS|assets|non current assets|work in progress|cwip | OpeningBalance | 0 | 8853320.4 | differs |
| 1|2025-02-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | OpeningBalance | 0 | -51091631.91 | differs |
| 2|2026-09-01||||| | * |  |  | missing in new |
| 6|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | 0 | -4021004.88 | differs |
| 1|2025-02-01|BS|assets|non current assets|intangible assets |software accm amortization | * |  |  | missing in new |
| 3|2025-04-01|BS|assets|non current assets|ppe cost|computers cost | OpeningBalance | 0 | 7398340.88 | differs |
| 1|2025-09-01|BS|assets|current assets|inventories, net|inventory - provision | OpeningBalance | 0 | -3462708.9 | differs |
| 2|2025-10-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 551172 | differs |
| 1|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 11704.48 | differs |
| 6|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 154713.77 | differs |
| 2|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 216383359.76 | differs |
| 3|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 157963666.9 | differs |
| 3|2025-12-01|IS|revenue|revenue|revenue out patient|revenue credit - op | OpeningBalance | 0 | -40330839.99 | differs |
| 6|2025-02-01|IS|expenses|direct cost|maintenance expense|maintenance expense | OpeningBalance | 0 | 175768.34 | differs |
| 1|2025-07-01|IS|expenses|general and administrative expenses|employee cost|employee cost | OpeningBalance | 0 | 1845138.38 | differs |
| 3|2025-10-01|IS|expenses|direct cost|employee costs|employee govt fees | OpeningBalance | 0 | 3553871.06 | differs |
| 4|2025-06-01|IS|expenses|direct cost|employee costs|employee costs | OpeningBalance | 0 | 25102392.29 | differs |
| 3|2025-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|housing guarantee payable to employees | OpeningBalance | 0 | -37641.87 | differs |
| 3|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | * |  |  | missing in new |
| 3|2025-04-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|hopsitality | OpeningBalance | 0 | 39396.13 | differs |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid government fee | OpeningBalance | 0 | 45355 | differs |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 4|2025-02-01|IS|expenses|direct cost|employee costs|employee medical insurance | OpeningBalance | 0 | 161801.34 | differs |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 146114.72 | differs |
| 2|2025-12-01|BS|assets|non current assets|ppe cost|advertisement and electrical equip cost | OpeningBalance | 0 | 1717378.74 | differs |
| 1|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued doctors fee and commission | * |  |  | missing in new |
| 5|2025-03-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | OpeningBalance | 0 | -40266115.09 | differs |
| 2|2025-10-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | OpeningBalance | 0 | 14186164.92 | differs |
| 6|2025-07-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 0 | 946018.04 | differs |
| 3|2025-10-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 5|2025-05-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | 0 | -1903131 | differs |
| 2|2025-03-01|IS|expenses|general and administrative expenses|governmental fee|government fee | OpeningBalance | 0 | 220188.23 | differs |
| 3|2025-04-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | 0 | -4486577.47 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 0 | -15922239.89 | differs |
| 3|2025-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | OpeningBalance | 0 | 15995102.56 | differs |
| 2|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 1302989.55 | differs |
| 4|2025-07-01|IS|revenue|revenue - discounts|revenue - settlement discount|volume discount | OpeningBalance | 0 | 940391.6 | differs |
| 1|2025-02-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | 0 | -1976608 | differs |
| 2|2025-12-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 0 | -30290805.51 | differs |
| 3|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 1|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | 0 | -392324.23 | differs |
| 6|2025-04-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 3|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 389400 | differs |
| 2|2025-02-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | OpeningBalance | 0 | -27582178.1 | differs |
| 5|2025-08-01|IS|expenses|direct cost|employee costs|doctor commission - incentive | OpeningBalance | 0 | 1151204.4 | differs |
| 5|2025-02-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | OpeningBalance | 0 | 157781.53 | differs |
| 2|2025-01-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | OpeningBalance | 0 | 61090.92 | differs |
| 5|2025-05-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | 0 | -1378098.65 | differs |
| 3|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 270600 | differs |
| 3|2025-06-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 330837.65 | differs |
| 6|2025-07-01|IS|expenses|direct cost|utilities|utilities | OpeningBalance | 0 | 1509008.89 | differs |
| 4|2025-02-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | OpeningBalance | 0 | 254943 | differs |
| 3|2025-01-01|BS|assets|non current assets|ppe cost|vehicles cost | OpeningBalance | 0 | 1900574.13 | differs |
| 6|2025-09-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 6|2025-09-01|IS|expenses|direct cost|employee costs|employee govt fees | OpeningBalance | 0 | 11200 | differs |
| 4|2025-03-01|IS|expenses|direct cost|employee costs|doctor commission - incentive | OpeningBalance | 0 | 456966.7 | differs |
| 2|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 0 | -36008115.6 | differs |
| 5|2025-12-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 0 | 6901902.23 | differs |
| 6|2025-12-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | 0 | 5104268.07 | differs |
| 3|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 5|2025-02-01|IS|expenses|direct cost|other direct expenses|referral cost | OpeningBalance | 0 | 52161.5 | differs |
| 5|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | OpeningBalance | 0 | 2190242.63 | differs |
| 3|2025-05-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | OpeningBalance | 0 | 1719795.5 | differs |
| 6|2025-06-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | OpeningBalance | 0 | 1574353.63 | differs |
| 1|2025-05-01|IS|expenses|direct cost|other direct expenses|referral cost | OpeningBalance | 0 | 79655.17 | differs |
| 1|2025-11-01|BS|assets|current assets|inventories, net|goods in transit | OpeningBalance | 0 | 70901.05 | differs |
| 2|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 1881973.98 | differs |
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | Transaction_Balance | -12872.9 | -1499.02 | differs |
| 5|2025-07-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | 0 | -1499102.98 | differs |
| 5|2025-08-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | OpeningBalance | 0 | -892590.95 | differs |
| 1|2025-10-01|IS|expenses|direct cost|medical consumables|other direct expenses | OpeningBalance | 0 | 12105829.43 | differs |
| 5|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 446666.68 | differs |
| 2|2025-02-01|IS|expenses|zakat|zakat|zakat expense | OpeningBalance | 0 | 261065.09 | differs |
| 6|2025-09-01|IS|expenses|direct cost|medical consumables|lab consumables | OpeningBalance | 0 | 1521073.25 | differs |
| 3|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | 0 | -45295.16 | differs |
| 5|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | OpeningBalance | 0 | 580000.03 | differs |
| 5|2025-07-01|IS|expenses|direct cost|employee costs|outsource expenses (givc) | OpeningBalance | 0 | 2895946.3 | differs |
| 5|2026-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | Transaction_Balance | 5275675.35 | 0 | differs |
| 1|2025-10-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | OpeningBalance | 0 | -2677616 | differs |
| 1|2025-08-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | OpeningBalance | 0 | 776608.46 | differs |
| 6|2025-06-01|IS|expenses|direct cost|deprecition|depreciation expense | * |  |  | missing in new |
| 5|2025-06-01|IS|expenses|direct cost|other direct expenses|kitchen expenses | OpeningBalance | 0 | 183432.01 | differs |
| 6|2025-02-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 0 | 39189.64 | differs |
| 4|2025-06-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | OpeningBalance | 0 | 38339217.58 | differs |
| 4|2025-11-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 0 | 3517660.31 | differs |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | 0 | -576115.39 | differs |
| 4|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 6|2025-03-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 0 | -363246114.32 | differs |
| 1|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued nafees portal fees | OpeningBalance | 0 | -100000 | differs |
| 5|2025-06-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | OpeningBalance | 0 | 324534.85 | differs |
| 1|2026-08-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 3|2025-05-01|IS|expenses|direct cost|medical consumables|stock adjustments | OpeningBalance | 0 | 326839.49 | differs |
| 4|2025-05-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | OpeningBalance | 0 | 206606.27 | differs |
| 5|2025-10-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 0 | 6843576.13 | differs |
| 4|2025-10-01|IS|revenue|revenue - discounts|revenue - settlement discount|rejection | OpeningBalance | 0 | 10068065.89 | differs |
| 5|2025-12-01|IS|expenses|direct cost|maintenance expense|employee accommodation maintenance | OpeningBalance | 0 | 53474.17 | differs |
| 1|2025-03-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 0 | -50608.81 | differs |
| 4|2025-12-01|IS|expenses|direct cost|maintenance expense|building and facility maintenance | OpeningBalance | 0 | 89587.02 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | Transaction_Balance | 3024371 | -2936664.17 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 2773518.23 | -61088.72 | differs |
| 1|2025-02-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 0 | -92834458.31 | differs |
| 4|2025-10-01|IS|expenses|direct cost|maintenance expense|general maintenance | OpeningBalance | 0 | 422740.7 | differs |
| 1|2025-12-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | OpeningBalance | 0 | 1287027.96 | differs |
| 6|2025-09-01|IS|expenses|general and administrative expenses|governmental fee|employee govt fees | OpeningBalance | 0 | 723641.38 | differs |
| 4|2025-06-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 0 | -18728318.23 | differs |
| 1|2025-09-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | OpeningBalance | 0 | 14786935.56 | differs |
| 5|2025-12-01|BS|assets|non current assets|ppe cost|vehicles cost | OpeningBalance | 0 | 540732.26 | differs |
| 4|2025-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | 0 | 3260460.36 | differs |
| 6|2025-04-01|IS|expenses|direct cost|medical consumables|medical consumables | OpeningBalance | 0 | 753912.8 | differs |
| 4|2025-07-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 6|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 761344.32 | differs |
| 3|2025-01-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 0 | 16723729.62 | differs |
| 1|2025-11-01|IS|expenses|direct cost|medical consumables|stock adjustments | OpeningBalance | 0 | 655781.91 | differs |
| 3|2025-09-01|IS|expenses|direct cost|maintenance expense|medical equipment maintenance | OpeningBalance | 0 | 632142.14 | differs |
| 1|2025-07-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | 0 | -19751526.66 | differs |
| 1|2025-08-01|IS|other income|other income, net|other income, net|education and training | OpeningBalance | 0 | -39482.9 | differs |
| 6|2025-04-01|IS|expenses|direct cost|cost of goods sold|stock adjustments | * |  |  | missing in new |
| 5|2025-07-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | 0 | 10823.2 | differs |
| 1|2025-03-01|BS|assets|non current assets|ppe cost|computers cost | OpeningBalance | 0 | 7184026.58 | differs |
| 5|2025-05-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 0 | -193573442.74 | differs |
| 5|2025-02-01|IS|expenses|general and administrative expenses|employee cost|employee cost | OpeningBalance | 0 | 166793.96 | differs |
| 3|2025-05-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | OpeningBalance | 0 | -85454453.29 | differs |
| 3|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 185514922.32 | differs |
| 4|2025-03-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 702015.43 | differs |
| 1|2025-12-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | OpeningBalance | 0 | 32189507.68 | differs |
| 1|2025-01-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | 0 | -17591975 | differs |
| 6|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | OpeningBalance | 0 | 676445.21 | differs |
| 2|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 0 | 215842640.79 | differs |
| 6|2025-04-01|IS|expenses|direct cost|medical consumables|lab consumables | OpeningBalance | 0 | 355198.95 | differs |
| 4|2025-01-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 5|2025-06-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 0 | -22775637.36 | differs |
| 6|2025-07-01|BS|assets|current assets|due from / ( due to) branch|due from branch | * |  |  | missing in new |
| 3|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | OpeningBalance | 0 | 118800 | differs |
| 6|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | OpeningBalance | 0 | 29006.98 | differs |
| 1|2025-10-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | 0 | -23591630.72 | differs |
| 2|2025-03-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 6|2025-08-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | OpeningBalance | 0 | 2825381.38 | differs |
| 5|2025-04-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | OpeningBalance | 0 | 1271130.66 | differs |
| 5|2025-09-01|IS|expenses|direct cost|maintenance expense|it maintenance | OpeningBalance | 0 | 438675.88 | differs |
| 1|2025-01-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | 0 | -823952.4 | differs |
| 6|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | OpeningBalance | 0 | 915131.62 | differs |
| 6|2025-10-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued doctors fee and commission | OpeningBalance | 0 | -119759.5 | differs |
| 6|2025-07-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | 0 | -1354238.68 | differs |
| 2|2025-12-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 1|2025-03-01|IS|expenses|direct cost|utilities|utilities | OpeningBalance | 0 | 380749.06 | differs |
| 5|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|advance to suppliers | OpeningBalance | 0 | 470346.5 | differs |
| 3|2025-11-01|IS|expenses|direct cost|referral cost|referral cost | OpeningBalance | 0 | 898502.08 | differs |
| 1|2025-12-01|IS|revenue|revenue|revenue out patient|revenue cash - op | OpeningBalance | 0 | -20134991.09 | differs |
| 2|2025-06-01|IS|revenue|revenue - discounts|revenue - settlement discount|rejection | OpeningBalance | 0 | 8198949.76 | differs |
| 4|2025-07-01|IS|expenses|direct cost|employee costs|outsource expenses (givc) | OpeningBalance | 0 | 2785448.03 | differs |
| 3|2025-04-01|BS|assets|current assets|due from related parties |due from related parties  | * |  |  | missing in new |
| 5|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | OpeningBalance | 0 | 1531391.08 | differs |
| 1|2025-04-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 6|2025-07-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 0 | 77715.08 | differs |
| 3|2025-06-01|IS|expenses|direct cost|employee costs|employee govt fees | OpeningBalance | 0 | 1941851.35 | differs |
| 1|2025-02-01|BS|assets|current assets|inventories, net|inventory - non-medical - kitchen | OpeningBalance | 0 | -176355.61 | differs |
| 3|2025-12-01|IS|expenses|direct cost|other direct expenses|other direct expenses | OpeningBalance | 0 | 973490.24 | differs |
| 6|2025-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | OpeningBalance | 0 | 182526.58 | differs |
| 3|2025-07-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | OpeningBalance | 0 | -58731360.6 | differs |
| 4|2025-10-01|IS|expenses|direct cost|employee costs|employee costs | OpeningBalance | 0 | 44001284 | differs |
| 4|2025-10-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 0 | -25161865.28 | differs |
| 4|2025-02-01|IS|expenses|direct cost|other direct expenses|referral cost | OpeningBalance | 0 | 75296.9 | differs |
| 6|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 5|2025-11-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | 0 | -712157.65 | differs |
| 2|2025-05-01|IS|expenses|direct cost|utilities|utilities | OpeningBalance | 0 | 433672.51 | differs |
| 4|2025-11-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | OpeningBalance | 0 | 80623303.38 | differs |
| 5|2025-07-01|IS|other income|other income, net|other income, net|other income | OpeningBalance | 0 | 132042.26 | differs |
| 3|2025-01-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|housing guarantee payable to employees | OpeningBalance | 0 | -37641.87 | differs |
| 5|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | 0 | -644136.52 | differs |
| 2|2025-06-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | 0 | 30849.83 | differs |
| 1|2025-09-01|BS|assets|current assets|due from related parties |due from related parties  | * |  |  | missing in new |
| 2|2025-01-01|BS|assets|non current assets|ppe cost|computers cost | OpeningBalance | 0 | 8261194.18 | differs |
| 5|2025-04-01|IS|other income|other income, net|other income, net|hrdf income | * |  |  | missing in new |
| 1|2025-10-01|IS|expenses|direct cost|other direct expenses|cost of medicines | OpeningBalance | 0 | -17141.66 | differs |
| 6|2025-09-01|IS|expenses|finance cost|finance cost|bank charges | OpeningBalance | 0 | 7051389.83 | differs |
| 3|2025-04-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | OpeningBalance | 0 | -508956.49 | differs |
| 3|2025-04-01|IS|expenses|direct cost|maintenance expense|medical gases | OpeningBalance | 0 | 58985 | differs |
| 2|2025-12-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 0 | 2990457.72 | differs |
| 5|2025-01-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | 0 | -1157548.36 | differs |
| 1|2025-03-01|IS|expenses|direct cost|other direct expenses|referral cost | OpeningBalance | 0 | 30900 | differs |
| 4|2025-10-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 0 | 100336.06 | differs |
| 6|2025-02-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | 0 | -3412695.2 | differs |
| 2|2025-01-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | OpeningBalance | 0 | -71696.25 | differs |
| 6|2025-11-01|IS|expenses|direct cost|deprecition|depreciation expense | * |  |  | missing in new |
| 4|2025-06-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 0 | 4027765.87 | differs |
| 1|2025-02-01|IS|expenses|general and administrative expenses|governmental fee|staff training and recruitments | OpeningBalance | 0 | 20333.33 | differs |
| 6|2025-07-01|IS|expenses|direct cost|employee costs|employee costs | OpeningBalance | 0 | 19037273.07 | differs |
| 2|2025-08-01|IS|expenses|direct cost|maintenance expense|employee accommodation maintenance | OpeningBalance | 0 | 27022.58 | differs |
| 4|2025-09-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 0 | 571800.42 | differs |
| 3|2025-04-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | 0 | -1849769.11 | differs |
| 1|2025-10-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | OpeningBalance | 0 | 26027849.34 | differs |
| 3|2025-08-01|IS|expenses|direct cost|maintenance expense|building and facility maintenance | OpeningBalance | 0 | 745763.01 | differs |
| 2|2025-02-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | OpeningBalance | 0 | -2610975.15 | differs |
| 1|2025-08-01|BS|assets|non current assets|ppe cost|medical equip cost | OpeningBalance | 0 | 121839773.28 | differs |
| ... | 8559 more | | | |

## vw_gl_openning_balance

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 476, new 8580. Differences: 8707.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 8|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -12411.55 | -8449.98 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | -1448736 | -4800603 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | forwarded_balance | -3351867 | 0 | differs |
| 2|2026-09-01||||| | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | OpeningBalance | 3027457.52 | 3339281.23 | differs |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | forwarded_balance | 311823.71 | 0 | differs |
| 1|2026-08-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 2639518.33 | -61088.72 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | forwarded_balance | 133999.9 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | * |  |  | missing in new |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | -405499.5 | -2271803.56 | differs |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | forwarded_balance | -1866304.06 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 43428468 | -155588073.75 | differs |
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | forwarded_balance | -199016541.75 | 0 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -14707601.11 | -24315272.2 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -9856671.437 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 54191821.51 | 229114221.99 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 174922400.48 | 0 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -22688596.38 | -71642128.02 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -16679314.161 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 183743.59 | 896222.22 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | forwarded_balance | 712478.63 | 0 | differs |
| 2|2026-08-01||||| | * |  |  | missing in new |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | OpeningBalance | -85772.86 | -2327109.04 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | forwarded_balance | -2241336.18 | 0 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | OpeningBalance | -449924 | -12475511 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | forwarded_balance | -12025587 | 0 | differs |
| 5|2026-08-01|IS|other income|other income, net|other income, net|hrdf income | * |  |  | missing in new |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | OpeningBalance | 1220741.42 | -7586447.22 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | forwarded_balance | -39223398.96 | 0 | differs |
| 2|2026-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | OpeningBalance | 3247733 | 6495466 | differs |
| 1|2026-08-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | OpeningBalance | -276996 | -3093110 | differs |
| 1|2026-08-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | forwarded_balance | -2816114 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | -5456199.07 | -34495731.41 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | forwarded_balance | -29039532.341 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | -870290.74 | 2679108.57 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | forwarded_balance | 3549399.31 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | OpeningBalance | 401639 | -257899 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | forwarded_balance | -659538 | 0 | differs |
| 2|2026-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | * |  |  | missing in new |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued nafees portal fees | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|general and administrative expenses|telephone, electricity and water|telephone, electricity and water | * |  |  | missing in new |
| 8|2026-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | * |  |  | missing in new |
| 6|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | * |  |  | missing in new |
| 5|2026-08-01||||| | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 4|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | -597382.54 | -8072472.9 | differs |
| 4|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | forwarded_balance | -8890643.362 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | OpeningBalance | 38018.09 | 296505.32 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | forwarded_balance | 258487.23 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | -75941.96 | 181832.2 | differs |
| 3|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 233959.445 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 1126162.48 | 149669980.4 | differs |
| 5|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 148543337.06 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue out patient|revenue credit - op | * |  |  | missing in new |
| 2|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | OpeningBalance | -551157.81 | -1252605.71 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | forwarded_balance | -701447.9 | 0 | differs |
| 3|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | -44679.34 | 225716.5 | differs |
| 3|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 233959.445 | 0 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | OpeningBalance | -159659.98 | -283956.96 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | forwarded_balance | 2784.06 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | * |  |  | missing in new |
| 4|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | OpeningBalance | 599689.37 | 750539.6 | differs |
| 4|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | forwarded_balance | 150850.232 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | OpeningBalance | -2105800 | -6977883 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | forwarded_balance | -4872083 | 0 | differs |
| 4|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 54316657.15 | 181034546.93 | differs |
| 4|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 127663912.54 | 0 | differs |
| 5|2026-09-01|IS|expenses|direct cost|employee costs|employee medical insurance | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | OpeningBalance | 47602.19 | -92855599.77 | differs |
| 1|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | forwarded_balance | -92903201.96 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 2|2026-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|computers cost | OpeningBalance | 633126.74 | 7886896.63 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|computers cost | forwarded_balance | 7253769.89 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 261176.98 | 291249.98 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|cash | forwarded_balance | 30073 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | OpeningBalance | -115320.07 | -242542.71 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | forwarded_balance | -127222.64 | 0 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|advertisement and electrical equip accm dep | OpeningBalance | 0 | -12917185.83 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|advertisement and electrical equip accm dep | forwarded_balance | -12917185.83 | 0 | differs |
| 5|2026-09-01|IS|expenses|direct cost|employee costs|employee costs | OpeningBalance | 39131555.701 | 44819161.04 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | OpeningBalance | 60640830.44 | 66459792.31 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 1549338.1 | 2084958.29 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | forwarded_balance | 535620.19 | 0 | differs |
| 4|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -12015858.46 | -21872529.9 | differs |
| 4|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -9856671.437 | 0 | differs |
| 8|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -6551.75 | -5502.04 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | OpeningBalance | 3107206.29 | 106215874.42 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | forwarded_balance | 103108668.13 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op | * |  |  | missing in new |
| 1|2026-09-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | OpeningBalance | -524617 | -12550204 | differs |
| 1|2026-09-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | forwarded_balance | -12025587 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 1686064.63 | 7160689.52 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|bank | forwarded_balance | 5474624.89 | 0 | differs |
| 1|2026-09-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|direct cost|medical consumables|stock adjustments | * |  |  | missing in new |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | 1860499.36 | 5536613.55 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|bank | forwarded_balance | 3691019.76 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -19172352.21 | -35851666.37 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -16679314.161 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 6295.27 | 39916.27 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | forwarded_balance | 74621 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|due from / ( due to) branch|due from branch | OpeningBalance | 125169882 | 624867439.48 | differs |
| 2|2026-08-01|BS|assets|current assets|due from / ( due to) branch|due from branch | forwarded_balance | 499697557.48 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|general and administrative expenses|professional fee and subscription|professional fee and subscription | * |  |  | missing in new |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | OpeningBalance | 13597.46 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | forwarded_balance | -13597.46 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | OpeningBalance | 919468.98 | 1317624.19 | differs |
| 2|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | 4634899.67 | 432652964.66 | differs |
| 2|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 241275023.709 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | OpeningBalance | -963770.68 | 767964.71 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | forwarded_balance | 1731735.39 | 0 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | OpeningBalance | -165604.16 | -6922450.83 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | forwarded_balance | -6756846.67 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | OpeningBalance | 142940.5 | 2425232.23 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | forwarded_balance | 2282291.73 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|inventories, net|inventory - provision | OpeningBalance | 601241.89 | -1203120.36 | differs |
| 1|2026-08-01|BS|assets|current assets|inventories, net|inventory - provision | forwarded_balance | -1804362.25 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | OpeningBalance | 6842538.28 | 3825480.46 | differs |
| 2|2026-08-01|IS|expenses|direct cost|deprecition|depreciation expense | * |  |  | missing in new |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | 858823.15 | 4821843.25 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store | forwarded_balance | 3549399.31 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | OpeningBalance | 1223432.93 | 51132692.85 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | forwarded_balance | 49909259.92 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | OpeningBalance | -554955.58 | -4963294.2 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | forwarded_balance | -4408338.62 | 0 | differs |
| 1|2026-09-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | OpeningBalance | -323162 | -3139276 | differs |
| 1|2026-09-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | forwarded_balance | -2816114 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | * |  |  | missing in new |
| 5|2026-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  | * |  |  | missing in new |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | OpeningBalance | -26220991.22 | 256563486.04 | differs |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | forwarded_balance | 230572199.28 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | OpeningBalance | 523306.15 | -39.8 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | forwarded_balance | -523345.95 | 0 | differs |
| 3|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance | * |  |  | missing in new |
| 2|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due from branch | * |  |  | missing in new |
| 5|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | -932257.851 | -6737776.27 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | forwarded_balance | -5103236.7 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | OpeningBalance | 677527.72 | 11207552.48 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | forwarded_balance | 1731735.39 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | OpeningBalance | -38299.29 | 117524565.27 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | forwarded_balance | 117562864.56 | 0 | differs |
| 2|2026-09-01|IS|expenses|direct cost|maintenance expense|vehicle maintenance | OpeningBalance | 36942.59 | 73885.18 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip | * |  |  | missing in new |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | OpeningBalance | -319151.52 | -1097212.52 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | forwarded_balance | -778061 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | OpeningBalance | 9900.92 | -722.12 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | forwarded_balance | -10623.04 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | OpeningBalance | -1586543.02 | -30733172.69 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | forwarded_balance | -29146629.669 | 0 | differs |
| 3|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | -6029887.04 | 6043460.88 | differs |
| 3|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | forwarded_balance | -5011410.151 | 0 | differs |
| 8|2026-08-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 197418.7 | 48139.03 | differs |
| 5|2026-08-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|cash | OpeningBalance | 289785.77 | 329615.36 | differs |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|cash | forwarded_balance | 39829.587 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | OpeningBalance | 841607.66 | 2475725.25 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid iqama and work permits | forwarded_balance | 1634117.59 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | OpeningBalance | -1357341.202 | -6557988.94 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | forwarded_balance | -5200647.739 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|bank | OpeningBalance | -1247642.83 | 3896819.49 | differs |
| 2|2026-08-01|BS|assets|current assets|cash and bank balances|bank | forwarded_balance | 5144462.32 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | OpeningBalance | 567505.07 | -190000 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued rent | forwarded_balance | -757505.07 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | OpeningBalance | -75334.78 | -63834.78 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued referral lab | forwarded_balance | 11500 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|deferred revenue  | * |  |  | missing in new |
| 2|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | OpeningBalance | 1372141.6 | 9117704.27 | differs |
| 2|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | forwarded_balance | 7745562.67 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -10707605.39 | -19192594.05 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -8484988.66 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | OpeningBalance | 1120031.31 | 1655651.5 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | forwarded_balance | 535620.19 | 0 | differs |
| 2|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | OpeningBalance | -984915.028 | -17433277.3 | differs |
| 2|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | forwarded_balance | -16448362.27 | 0 | differs |
| 3|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | OpeningBalance | -16662195.68 | -31099341.21 | differs |
| 3|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | forwarded_balance | -16352207.459 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | OpeningBalance | -13249681.88 | -13893453.97 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | forwarded_balance | -643772.09 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | OpeningBalance | 22725.81 | 27000.02 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid rent | forwarded_balance | 4274.21 | 0 | differs |
| 2|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op | * |  |  | missing in new |
| 2|2026-08-01|IS|expenses|general and administrative expenses|insurance |insurance  | * |  |  | missing in new |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | OpeningBalance | 16756.94 | -383352.41 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | forwarded_balance | -400109.35 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | OpeningBalance | 401639 | -257899 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | forwarded_balance | -659538 | 0 | differs |
| 5|2026-09-01|IS|other income|other income, net|other income, net|other income | OpeningBalance | -901669.73 | -89455.96 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op | * |  |  | missing in new |
| 1|2026-09-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  | * |  |  | missing in new |
| 8|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|direct cost|deprecition|depreciation expense | * |  |  | missing in new |
| 4|2026-08-01|IS|expenses|general and administrative expenses|employee cost|employee cost | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | OpeningBalance | -4045.68 | 254441.55 | differs |
| ... | 8507 more | | | |

## vw_hospital_beds_utilization

Keys (hospital_id, period): old 88, new 88. Differences: 735.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 5|2026-08-01 | available_beds | 203 | 201 | differs |
| 5|2026-08-01 | census | 929 | 1049 | differs |
| 5|2026-08-01 | alos | 35.31090778615 | 27.4782160687333 | differs |
| 5|2026-08-01 | ltc_alos | 468.119871794872 | 525.851947463768 | differs |
| 5|2026-08-01 | non_ltc_alos | 2.75004822530864 | 2.31335147578973 | differs |
| 5|2026-08-01 | available_bed_nights | 6293 | 6231 | differs |
| 2|2025-09-01 | available_beds | 256 | 311 | differs |
| 2|2025-09-01 | census | 1014 | 1080 | differs |
| 2|2025-09-01 | ltc_census | 131 | 132 | differs |
| 2|2025-09-01 | alos | 34.3325936883629 | 5.07281746031747 | differs |
| 2|2025-09-01 | ltc_alos | 244.235687022901 | 116.757098765432 | differs |
| 2|2025-09-01 | non_ltc_alos | 3.19181766704417 | 2.7077385620915 | differs |
| 2|2025-09-01 | total_bed_nights | 5393 | 5356 | differs |
| 2|2025-09-01 | available_bed_nights | 7680 | 9327 | differs |
| 2|2025-09-01 | occupancy_rate | 0.702213541666667 | 0.574246810335585 | differs |
| 3|2025-05-01 | census | 1225 | 1360 | differs |
| 3|2025-05-01 | ltc_census | 102 | 103 | differs |
| 3|2025-05-01 | alos | 27.7646258503401 | 2.9539949100703 | differs |
| 3|2025-05-01 | ltc_alos | 306.488562091503 | 62.9482638888889 | differs |
| 3|2025-05-01 | non_ltc_alos | 2.44864945087563 | 2.15473737163475 | differs |
| 3|2025-05-01 | total_bed_nights | 4651 | 4203 | differs |
| 3|2025-05-01 | occupancy_rate | 0.638435140700069 | 0.575832305795314 | differs |
| 1|2026-09-01 | available_beds | 463 | 452 | differs |
| 1|2026-09-01 | census | 1217 | 1292 | differs |
| 1|2026-09-01 | alos | 139.195425910709 | 6.59028164009392 | differs |
| 1|2026-09-01 | ltc_alos | 495.046117705242 | 139.725818452381 | differs |
| 1|2026-09-01 | non_ltc_alos | 2.92078598484849 | 2.31037919377472 | differs |
| 1|2026-09-01 | total_bed_nights | 11106 | 11351 | differs |
| 1|2026-09-01 | available_bed_nights | 13890 | 13556 | differs |
| 1|2026-09-01 | occupancy_rate | 0.799568034557235 | 0.837341398642667 | differs |
| 3|2025-06-01 | available_beds | 235 | 244 | differs |
| 3|2025-06-01 | census | 1060 | 1207 | differs |
| 3|2025-06-01 | ltc_census | 99 | 100 | differs |
| 3|2025-06-01 | alos | 32.2827044025157 | 2.79109484964811 | differs |
| 3|2025-06-01 | ltc_alos | 320.756734006734 | 61.032532051282 | differs |
| 3|2025-06-01 | non_ltc_alos | 2.56477627471384 | 2.05529437965663 | differs |
| 3|2025-06-01 | total_bed_nights | 4216 | 3847 | differs |
| 3|2025-06-01 | available_bed_nights | 7050 | 7320 | differs |
| 3|2025-06-01 | occupancy_rate | 0.598014184397163 | 0.525546448087432 | differs |
| 6|2026-08-01 | available_beds | 209 | 192 | differs |
| 6|2026-08-01 | census | 454 | 480 | differs |
| 6|2026-08-01 | alos | 26.3433370044053 | 4.457757885763 | differs |
| 6|2026-08-01 | ltc_alos | 185.549851190476 | 80.2116898148148 | differs |
| 6|2026-08-01 | non_ltc_alos | 3.94242043551089 | 3.27717712842713 | differs |
| 6|2026-08-01 | total_bed_nights | 2735 | 2782 | differs |
| 6|2026-08-01 | available_bed_nights | 6479 | 5949 | differs |
| 6|2026-08-01 | occupancy_rate | 0.422133045223028 | 0.46764162044041 | differs |
| 1|2025-09-01 | available_beds | 463 | 451 | differs |
| 1|2025-09-01 | census | 952 | 1009 | differs |
| 1|2025-09-01 | alos | 197.898634453782 | 8.01007930576316 | differs |
| 1|2025-09-01 | ltc_alos | 641.421534936999 | 278.025297619048 | differs |
| 1|2025-09-01 | non_ltc_alos | 2.64120020171457 | 2.23876166242579 | differs |
| 1|2025-09-01 | total_bed_nights | 9301 | 9570 | differs |
| 1|2025-09-01 | available_bed_nights | 13890 | 13530 | differs |
| 1|2025-09-01 | occupancy_rate | 0.669618430525558 | 0.707317073170732 | differs |
| 3|2025-02-01 | available_beds | 235 | 237 | differs |
| 3|2025-02-01 | census | 1206 | 1337 | differs |
| 3|2025-02-01 | ltc_census | 98 | 99 | differs |
| 3|2025-02-01 | alos | 24.1239980652294 | 3.30246281437687 | differs |
| 3|2025-02-01 | ltc_alos | 265.891581632653 | 60.8283680555556 | differs |
| 3|2025-02-01 | non_ltc_alos | 2.74022262334537 | 2.31404519854906 | differs |
| 3|2025-02-01 | total_bed_nights | 4309 | 3807 | differs |
| 3|2025-02-01 | available_bed_nights | 6580 | 6624 | differs |
| 3|2025-02-01 | occupancy_rate | 0.654863221884499 | 0.574728260869565 | differs |
| 2|2026-09-01 | available_beds | 256 | 278 | differs |
| 2|2026-09-01 | census | 1023 | 1131 | differs |
| 2|2026-09-01 | ltc_census | 244 | 304 | differs |
| 2|2026-09-01 | alos | 18.6359156076898 | 4.30641369562709 | differs |
| 2|2026-09-01 | ltc_alos | 68.625 | 11.1008333333333 | differs |
| 2|2026-09-01 | non_ltc_alos | 2.97823063756953 | 2.41155562933452 | differs |
| 2|2026-09-01 | total_bed_nights | 4442 | 4495 | differs |
| 2|2026-09-01 | available_bed_nights | 7680 | 8351 | differs |
| 2|2026-09-01 | occupancy_rate | 0.578385416666667 | 0.53825889115076 | differs |
| 4|2025-03-01 | available_beds | 244 | 226 | differs |
| 4|2025-03-01 | census | 536 | 827 | differs |
| 4|2025-03-01 | ltc_census | 69 | 287 | differs |
| 4|2025-03-01 | alos | 99.6975279850746 | 3.19993955512572 | differs |
| 4|2025-03-01 | ltc_alos | 758.794685990338 | 75.728125 | differs |
| 4|2025-03-01 | non_ltc_alos | 2.31486438258387 | 2.34833659491193 | differs |
| 4|2025-03-01 | total_bed_nights | 2804 | 2609 | differs |
| 4|2025-03-01 | available_bed_nights | 7564 | 7004 | differs |
| 4|2025-01-01 | available_beds | 244 | 231 | differs |
| 4|2025-01-01 | census | 804 | 1100 | differs |
| 4|2025-01-01 | ltc_census | 87 | 304 | differs |
| 4|2025-01-01 | alos | 71.0500103648425 | 5.18522256143526 | differs |
| 4|2025-01-01 | ltc_alos | 629.144157088123 | 163.637689393939 | differs |
| 4|2025-01-01 | non_ltc_alos | 3.33147373314737 | 2.78442760942761 | differs |
| 4|2025-01-01 | total_bed_nights | 4047 | 3744 | differs |
| 4|2025-01-01 | available_bed_nights | 7564 | 7165 | differs |
| 4|2025-01-01 | occupancy_rate | 0.535034373347435 | 0.522540125610607 | differs |
| 2|2025-12-01 | available_beds | 256 | 300 | differs |
| 2|2025-12-01 | census | 1162 | 1220 | differs |
| 2|2025-12-01 | ltc_census | 105 | 106 | differs |
| 2|2025-12-01 | alos | 25.0125860585198 | 22.2781939541042 | differs |
| 2|2025-12-01 | ltc_alos | 247.311904761905 | 254.009316479401 | differs |
| 2|2025-12-01 | non_ltc_alos | 2.92987228003784 | 2.52333772349936 | differs |
| 2|2025-12-01 | total_bed_nights | 5148 | 4919 | differs |
| 2|2025-12-01 | available_bed_nights | 7936 | 9300 | differs |
| 2|2025-12-01 | occupancy_rate | 0.648689516129032 | 0.528924731182796 | differs |
| 1|2025-07-01 | available_beds | 463 | 469 | differs |
| 1|2025-07-01 | census | 894 | 947 | differs |
| 1|2025-07-01 | alos | 214.090277777778 | 14.3356248874482 | differs |
| 1|2025-07-01 | ltc_alos | 619.672521786492 | 253.277921455939 | differs |
| 1|2025-07-01 | non_ltc_alos | 3.02196712018141 | 2.55105583900227 | differs |
| 1|2025-07-01 | total_bed_nights | 9722 | 9856 | differs |
| 1|2025-07-01 | available_bed_nights | 14353 | 14540 | differs |
| 3|2025-04-01 | census | 1091 | 1225 | differs |
| 3|2025-04-01 | ltc_census | 90 | 91 | differs |
| 3|2025-04-01 | alos | 26.7556523067522 | 2.93621804903495 | differs |
| 3|2025-04-01 | ltc_alos | 293.298611111111 | 57.9217803030303 | differs |
| 3|2025-04-01 | non_ltc_alos | 2.79075091575092 | 2.36236493253215 | differs |
| 3|2025-04-01 | total_bed_nights | 4260 | 3825 | differs |
| 3|2025-04-01 | occupancy_rate | 0.604255319148936 | 0.542015020546975 | differs |
| 5|2025-11-01 | census | 906 | 1015 | differs |
| 5|2025-11-01 | ltc_census | 143 | 145 | differs |
| 5|2025-11-01 | alos | 59.1278513612951 | 4.04178485162181 | differs |
| 5|2025-11-01 | ltc_alos | 356.128787878788 | 132.409548611111 | differs |
| 5|2025-11-01 | non_ltc_alos | 3.46450415028397 | 2.75327530322041 | differs |
| 5|2025-11-01 | total_bed_nights | 5725 | 3506 | differs |
| 5|2025-11-01 | available_bed_nights | 6090 | 6051 | differs |
| 5|2025-11-01 | occupancy_rate | 0.940065681444992 | 0.579408362254173 | differs |
| 1|2025-03-01 | available_beds | 463 | 503 | differs |
| 1|2025-03-01 | census | 797 | 839 | differs |
| 1|2025-03-01 | ltc_census | 322 | 324 | differs |
| 1|2025-03-01 | alos | 248.700334588038 | 37.4135945463812 | differs |
| 1|2025-03-01 | ltc_alos | 611.001552795031 | 339.293390376984 | differs |
| 1|2025-03-01 | non_ltc_alos | 3.09824561403509 | 2.84249318336742 | differs |
| 1|2025-03-01 | total_bed_nights | 9631 | 9494 | differs |
| 1|2025-03-01 | available_bed_nights | 14353 | 15578 | differs |
| 1|2025-03-01 | occupancy_rate | 0.671009545042848 | 0.609449223263577 | differs |
| 2|2025-10-01 | available_beds | 256 | 298 | differs |
| 2|2025-10-01 | census | 1257 | 1328 | differs |
| 2|2025-10-01 | ltc_census | 127 | 128 | differs |
| 2|2025-10-01 | alos | 27.1915274463007 | 5.14922266430887 | differs |
| 2|2025-10-01 | ltc_alos | 240.789041994751 | 154.022183641975 | differs |
| 2|2025-10-01 | non_ltc_alos | 3.18543510324484 | 2.74157369971049 | differs |
| 2|2025-10-01 | total_bed_nights | 6070 | 6005 | differs |
| 2|2025-10-01 | available_bed_nights | 7936 | 9240 | differs |
| 2|2025-10-01 | occupancy_rate | 0.764868951612903 | 0.649891774891775 | differs |
| 4|2025-12-01 | census | 830 | 1114 | differs |
| 4|2025-12-01 | ltc_census | 92 | 310 | differs |
| 4|2025-12-01 | alos | 66.2748493975904 | 5.33844764670837 | differs |
| 4|2025-12-01 | ltc_alos | 575.384510869565 | 170.785683760684 | differs |
| 4|2025-12-01 | non_ltc_alos | 2.80860433604336 | 2.40418561467334 | differs |
| 4|2025-12-01 | total_bed_nights | 3910 | 3953 | differs |
| 4|2025-12-01 | occupancy_rate | 0.516922263352723 | 0.522607086197779 | differs |
| 1|2025-01-01 | available_beds | 463 | 493 | differs |
| 1|2025-01-01 | census | 1061 | 1101 | differs |
| 1|2025-01-01 | alos | 190.437794533459 | 7.9904879014021 | differs |
| 1|2025-01-01 | ltc_alos | 588.829523107178 | 134.129737103175 | differs |
| 1|2025-01-01 | non_ltc_alos | 3.38129039704524 | 3.00896607114873 | differs |
| 1|2025-01-01 | total_bed_nights | 10927 | 10791 | differs |
| 1|2025-01-01 | available_bed_nights | 14353 | 15278 | differs |
| 1|2025-01-01 | occupancy_rate | 0.761304256949767 | 0.70630972640398 | differs |
| 6|2025-08-01 | available_beds | 209 | 144 | differs |
| 6|2025-08-01 | census | 474 | 501 | differs |
| 6|2025-08-01 | alos | 31.7153656821378 | 7.75754733278054 | differs |
| 6|2025-08-01 | ltc_alos | 160.297916666667 | 64.1320138888889 | differs |
| 6|2025-08-01 | non_ltc_alos | 5.60723350253807 | 4.80600458115183 | differs |
| 6|2025-08-01 | total_bed_nights | 3413 | 2550 | differs |
| 6|2025-08-01 | available_bed_nights | 6479 | 4451 | differs |
| 6|2025-08-01 | occupancy_rate | 0.526778823892576 | 0.572904965176365 | differs |
| 5|2025-08-01 | available_beds | 203 | 212 | differs |
| 5|2025-08-01 | census | 782 | 887 | differs |
| 5|2025-08-01 | ltc_census | 113 | 114 | differs |
| 5|2025-08-01 | alos | 64.8861359761296 | 3.12170235878336 | differs |
| 5|2025-08-01 | ltc_alos | 429.90302359882 | 110.343055555556 | differs |
| 5|2025-08-01 | non_ltc_alos | 3.23156452416542 | 2.67056062022752 | differs |
| 5|2025-08-01 | total_bed_nights | 4885 | 3141 | differs |
| 5|2025-08-01 | available_bed_nights | 6293 | 6557 | differs |
| 5|2025-08-01 | occupancy_rate | 0.776259335769903 | 0.479030044227543 | differs |
| 2|2025-07-01 | available_beds | 256 | 313 | differs |
| 2|2025-07-01 | census | 1022 | 1074 | differs |
| 2|2025-07-01 | ltc_census | 135 | 136 | differs |
| 2|2025-07-01 | alos | 35.5006930854534 | 4.80784336856675 | differs |
| 2|2025-07-01 | ltc_alos | 244.729012345679 | 106.834523809524 | differs |
| 2|2025-07-01 | non_ltc_alos | 3.6564731304021 | 3.16414540979414 | differs |
| 2|2025-07-01 | total_bed_nights | 5961 | 5665 | differs |
| 2|2025-07-01 | available_bed_nights | 7936 | 9713 | differs |
| 2|2025-07-01 | occupancy_rate | 0.751134072580645 | 0.583238958097395 | differs |
| 2|2025-01-01 | available_beds | 256 | 316 | differs |
| 2|2025-01-01 | census | 1032 | 1077 | differs |
| 2|2025-01-01 | ltc_census | 102 | 103 | differs |
| 2|2025-01-01 | alos | 28.4596253229974 | 3.15694444444445 | differs |
| 2|2025-01-01 | ltc_alos | 255.587418300654 | 33.5458333333333 | differs |
| 2|2025-01-01 | non_ltc_alos | 3.54883512544803 | 3.05485411223093 | differs |
| 2|2025-01-01 | total_bed_nights | 5346 | 5032 | differs |
| 2|2025-01-01 | available_bed_nights | 7936 | 9807 | differs |
| 2|2025-01-01 | occupancy_rate | 0.673639112903226 | 0.513102885693892 | differs |
| 1|2025-04-01 | available_beds | 463 | 501 | differs |
| 1|2025-04-01 | census | 827 | 865 | differs |
| 1|2025-04-01 | ltc_census | 282 | 284 | differs |
| 1|2025-04-01 | alos | 222.329655380895 | 9.09387131115072 | differs |
| 1|2025-04-01 | ltc_alos | 646.429078014184 | 200.442214912281 | differs |
| 1|2025-04-01 | non_ltc_alos | 2.88738532110092 | 2.38608804838048 | differs |
| 1|2025-04-01 | available_bed_nights | 13890 | 15032 | differs |
| 1|2025-04-01 | occupancy_rate | 0.634557235421166 | 0.586016498137307 | differs |
| 3|2025-01-01 | available_beds | 235 | 272 | differs |
| 3|2025-01-01 | census | 1382 | 1507 | differs |
| 3|2025-01-01 | ltc_census | 90 | 91 | differs |
| ... | 535 more | | | |

## vw_rcm

Keys (hospital_id, period): old 88, new 88. Differences: 902.

| Key | Column | Old | New | Status |
|---|---|---|---|---|
| 5|2025-06-01 | total_submitted_claims | 13012469.2500004 | 13278111.8099999 | differs |
| 5|2025-06-01 | not_submitted_claims | 259710.13 | 351404.31 | differs |
| 5|2025-06-01 | approved_amount | 10947421.6000001 | 10644651.48 | differs |
| 5|2025-06-01 | rejections | 2065047.64999999 | 2089743.51999999 | differs |
| 5|2025-06-01 | rejection_rate_pct | 15.87 | 14.53 | differs |
| 5|2025-06-01 | approval_rate_pct | 84.13 | 74.02 | differs |
| 5|2025-06-01 | total_orders | 9131 | 13393 | differs |
| 5|2025-06-01 | approved_orders | 6898 | 7376 | differs |
| 5|2025-06-01 | approved_not_done | 1626 | 1945 | differs |
| 5|2025-06-01 | approved_not_done_pct | 17.81 | 14.52 | differs |
| 5|2025-06-01 | avg_tat_minutes | 32.1 | 73.2 | differs |
| 6|2025-10-01 | not_submitted_claims | 28967.12 | 6860.28 | differs |
| 6|2025-10-01 | approved_amount | 9388807.13999996 | 8148589.41999993 | differs |
| 6|2025-10-01 | rejections | 437062.759999999 | 2038681.56 | differs |
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
| 8|2026-08-01 | total_orders | 52 | 193 | differs |
| 8|2026-08-01 | approved_orders | 28 | 29 | differs |
| 8|2026-08-01 | approved_not_done | 11 | 13 | differs |
| 8|2026-08-01 | approved_not_done_pct | 21.15 | 6.74 | differs |
| 8|2026-08-01 | avg_tat_minutes | 39.3 | 52.9 | differs |
| 6|2025-09-01 | total_submitted_claims | 9465318.33999994 | 9824412.45999989 | differs |
| 6|2025-09-01 | not_submitted_claims | 1198.4 | 312660.2 | differs |
| 6|2025-09-01 | approved_amount | 9245407.72999994 | 7672116.84999986 | differs |
| 6|2025-09-01 | rejections | 219910.61 | 1985228.29 | differs |
| 6|2025-09-01 | rejection_rate_pct | 2.32 | 18.38 | differs |
| 6|2025-09-01 | approval_rate_pct | 97.68 | 71.02 | differs |
| 6|2025-09-01 | total_orders | 3502 | 5165 | differs |
| 6|2025-09-01 | approved_orders | 2716 | 2743 | differs |
| 6|2025-09-01 | approved_not_done | 890 | 1013 | differs |
| 6|2025-09-01 | approved_not_done_pct | 25.41 | 19.61 | differs |
| 6|2025-09-01 | avg_tat_minutes | 49 | 106.9 | differs |
| 6|2026-09-01 | not_submitted_claims | 409479.98 | 1596621.28 | differs |
| 6|2026-09-01 | approved_amount | 1604108.73 | 0 | differs |
| 6|2026-09-01 | approval_rate_pct | 100 | 0 | differs |
| 6|2026-09-01 | total_orders | 5260 | 10114 | differs |
| 6|2026-09-01 | approved_orders | 3707 | 3682 | differs |
| 6|2026-09-01 | approved_not_done | 988 | 1082 | differs |
| 6|2026-09-01 | approved_not_done_pct | 18.78 | 10.7 | differs |
| 6|2026-09-01 | avg_tat_minutes | 36.7 | 70.2 | differs |
| 1|2025-07-01 | total_submitted_claims | 14411909.0200001 | 14696414.1199998 | differs |
| 1|2025-07-01 | not_submitted_claims | 56092.62 | 82359.5599999999 | differs |
| 1|2025-07-01 | approved_amount | 12613102.3599998 | 12387626.9799997 | differs |
| 1|2025-07-01 | rejections | 1798807.88 | 1651618.31000001 | differs |
| 1|2025-07-01 | rejection_rate_pct | 12.48 | 10.36 | differs |
| 1|2025-07-01 | approval_rate_pct | 87.52 | 77.73 | differs |
| 1|2025-07-01 | total_orders | 16793 | 27826 | differs |
| 1|2025-07-01 | approved_orders | 12686 | 14690 | differs |
| 1|2025-07-01 | approved_not_done | 3018 | 3881 | differs |
| 1|2025-07-01 | approved_not_done_pct | 17.97 | 13.95 | differs |
| 1|2025-07-01 | avg_tat_minutes | 42.6 | 68 | differs |
| 2|2025-01-01 | not_submitted_claims | 50772.11 | 37575.02 | differs |
| 2|2025-01-01 | approved_amount | 4544842.71000002 | 4488975.19000005 | differs |
| 2|2025-01-01 | rejections | 2368147.11 | 1901224.38000004 | differs |
| 2|2025-01-01 | rejection_rate_pct | 34.26 | 26.55 | differs |
| 2|2025-01-01 | approval_rate_pct | 65.74 | 62.69 | differs |
| 2|2025-01-01 | total_orders | 17516 | 30107 | differs |
| 2|2025-01-01 | approved_orders | 12862 | 14031 | differs |
| 2|2025-01-01 | approved_not_done | 2999 | 3408 | differs |
| 2|2025-01-01 | approved_not_done_pct | 17.12 | 11.32 | differs |
| 2|2025-01-01 | avg_tat_minutes | 29.4 | 66.7 | differs |
| 1|2025-05-01 | total_submitted_claims | 15053524.2500001 | 15579635.5300005 | differs |
| 1|2025-05-01 | not_submitted_claims | 268355.33 | 294693.64 | differs |
| 1|2025-05-01 | approved_amount | 13359950.06 | 12953354.7500003 | differs |
| 1|2025-05-01 | rejections | 1693574.35000001 | 1651622.62999999 | differs |
| 1|2025-05-01 | rejection_rate_pct | 11.25 | 10.01 | differs |
| 1|2025-05-01 | approval_rate_pct | 88.75 | 78.47 | differs |
| 1|2025-05-01 | total_orders | 16879 | 27574 | differs |
| 1|2025-05-01 | approved_orders | 12632 | 14786 | differs |
| 1|2025-05-01 | approved_not_done | 2995 | 3802 | differs |
| 1|2025-05-01 | approved_not_done_pct | 17.74 | 13.79 | differs |
| 1|2025-05-01 | avg_tat_minutes | 36.5 | 57.9 | differs |
| 1|2025-06-01 | total_submitted_claims | 13407745.4000001 | 13677873.4799998 | differs |
| 1|2025-06-01 | not_submitted_claims | 13079.13 | 265698.07 | differs |
| 1|2025-06-01 | approved_amount | 11726232.36 | 11576148.5399999 | differs |
| 1|2025-06-01 | rejections | 1681513.2 | 1639772.38999999 | differs |
| 1|2025-06-01 | rejection_rate_pct | 12.54 | 11 | differs |
| 1|2025-06-01 | approval_rate_pct | 87.46 | 77.66 | differs |
| 1|2025-06-01 | total_orders | 15539 | 24788 | differs |
| 1|2025-06-01 | approved_orders | 11655 | 13820 | differs |
| 1|2025-06-01 | approved_not_done | 2955 | 3704 | differs |
| 1|2025-06-01 | approved_not_done_pct | 19.02 | 14.94 | differs |
| 1|2025-06-01 | avg_tat_minutes | 34.3 | 52.9 | differs |
| 4|2025-12-01 | total_submitted_claims | 17850224.6199999 | 18112267.3599996 | differs |
| 4|2025-12-01 | not_submitted_claims | 37687.45 | 304147.63 | differs |
| 4|2025-12-01 | approved_amount | 15834265.1799997 | 15713263.5699991 | differs |
| 4|2025-12-01 | rejections | 2015959.73000001 | 2047799.11000002 | differs |
| 4|2025-12-01 | rejection_rate_pct | 11.29 | 10.08 | differs |
| 4|2025-12-01 | approval_rate_pct | 88.71 | 77.38 | differs |
| 4|2025-12-01 | total_orders | 19431 | 28742 | differs |
| 4|2025-12-01 | approved_orders | 14014 | 14908 | differs |
| 4|2025-12-01 | approved_not_done | 2618 | 3379 | differs |
| 4|2025-12-01 | approved_not_done_pct | 13.47 | 11.76 | differs |
| 4|2025-12-01 | avg_tat_minutes | 27.1 | 41.4 | differs |
| 3|2025-03-01 | total_submitted_claims | 17732864.4500003 | 7181519.0600001 | differs |
| 3|2025-03-01 | not_submitted_claims | 11677417.3200002 | 1124753.89 | differs |
| 3|2025-03-01 | approved_amount | 15889611.9700003 | 4159767.07000005 | differs |
| 3|2025-03-01 | rejections | 1843252.91 | 1956925.28000002 | differs |
| 3|2025-03-01 | rejection_rate_pct | 10.39 | 28.67 | differs |
| 3|2025-03-01 | approval_rate_pct | 89.61 | 60.95 | differs |
| 3|2025-03-01 | total_orders | 11498 | 15373 | differs |
| 3|2025-03-01 | approved_orders | 8617 | 8389 | differs |
| 3|2025-03-01 | approved_not_done | 1690 | 2085 | differs |
| 3|2025-03-01 | approved_not_done_pct | 14.7 | 13.56 | differs |
| 3|2025-03-01 | avg_tat_minutes | 29.7 | 58.8 | differs |
| 3|2026-08-01 | total_submitted_claims | 34533461.6600035 | 35120773.7700029 | differs |
| 3|2026-08-01 | not_submitted_claims | 587.77 | 702199.499999999 | differs |
| 3|2026-08-01 | approved_amount | 27901125.4100013 | 27537850.8100003 | differs |
| 3|2026-08-01 | rejections | 6632337.30999951 | 7621686.16000008 | differs |
| 3|2026-08-01 | rejection_rate_pct | 19.21 | 19.39 | differs |
| 3|2026-08-01 | approval_rate_pct | 80.79 | 70.05 | differs |
| 3|2026-08-01 | total_orders | 17495 | 28100 | differs |
| 3|2026-08-01 | approved_orders | 13830 | 14384 | differs |
| 3|2026-08-01 | approved_not_done | 2326 | 2914 | differs |
| 3|2026-08-01 | approved_not_done_pct | 13.3 | 10.37 | differs |
| 3|2026-08-01 | avg_tat_minutes | 32.5 | 58.5 | differs |
| 4|2025-08-01 | total_submitted_claims | 13159436.9699999 | 13805359.8 | differs |
| 4|2025-08-01 | not_submitted_claims | 3458.26 | 696314.939999999 | differs |
| 4|2025-08-01 | approved_amount | 12078085.8399998 | 11580081.7899998 | differs |
| 4|2025-08-01 | rejections | 1081351.37 | 1571302.58999999 | differs |
| 4|2025-08-01 | rejection_rate_pct | 8.22 | 10.51 | differs |
| 4|2025-08-01 | approval_rate_pct | 91.78 | 77.44 | differs |
| 4|2025-08-01 | total_orders | 15243 | 21228 | differs |
| 4|2025-08-01 | approved_orders | 10141 | 10294 | differs |
| 4|2025-08-01 | approved_not_done | 2306 | 2388 | differs |
| 4|2025-08-01 | approved_not_done_pct | 15.13 | 11.25 | differs |
| 4|2025-08-01 | avg_tat_minutes | 26.5 | 47.9 | differs |
| 1|2025-10-01 | total_submitted_claims | 17560139.7099997 | 17859306.8499994 | differs |
| 1|2025-10-01 | not_submitted_claims | 24594.04 | 178754.53 | differs |
| 1|2025-10-01 | approved_amount | 15769118.8399999 | 15270892.7799994 | differs |
| 1|2025-10-01 | rejections | 1842719.97000001 | 2033650.02000001 | differs |
| 1|2025-10-01 | rejection_rate_pct | 10.49 | 10.29 | differs |
| 1|2025-10-01 | approval_rate_pct | 89.8 | 77.25 | differs |
| 1|2025-10-01 | total_orders | 18727 | 33222 | differs |
| 1|2025-10-01 | approved_orders | 14430 | 17153 | differs |
| 1|2025-10-01 | approved_not_done | 3802 | 4756 | differs |
| 1|2025-10-01 | approved_not_done_pct | 20.3 | 14.32 | differs |
| 1|2025-10-01 | avg_tat_minutes | 36 | 49.8 | differs |
| 1|2025-09-01 | total_submitted_claims | 14911107.4899993 | 15452252.9499999 | differs |
| 1|2025-09-01 | not_submitted_claims | 57196.26 | 573406.26 | differs |
| 1|2025-09-01 | approved_amount | 13129438.2099994 | 12754173.31 | differs |
| 1|2025-09-01 | rejections | 1801132.76000001 | 1757477.96000001 | differs |
| 1|2025-09-01 | rejection_rate_pct | 12.08 | 10.64 | differs |
| 1|2025-09-01 | approval_rate_pct | 88.05 | 77.23 | differs |
| 1|2025-09-01 | total_orders | 17196 | 28944 | differs |
| 1|2025-09-01 | approved_orders | 13266 | 15801 | differs |
| 1|2025-09-01 | approved_not_done | 3414 | 3916 | differs |
| 1|2025-09-01 | approved_not_done_pct | 19.85 | 13.53 | differs |
| 1|2025-09-01 | avg_tat_minutes | 40.4 | 53.6 | differs |
| 1|2026-09-01 | total_submitted_claims | 8856539.22999972 | 8933591.1599995 | differs |
| 1|2026-09-01 | not_submitted_claims | 1701770.73 | 8472674.54999962 | differs |
| 1|2026-09-01 | approved_amount | 8833834.09999972 | 111158.37 | differs |
| 1|2026-09-01 | rejections | 22705.13 | 23555.17 | differs |
| 1|2026-09-01 | rejection_rate_pct | 0.26 | 16.99 | differs |
| 1|2026-09-01 | approval_rate_pct | 99.74 | 80.19 | differs |
| 1|2026-09-01 | total_orders | 26237 | 39725 | differs |
| 1|2026-09-01 | approved_orders | 19055 | 22080 | differs |
| 1|2026-09-01 | approved_not_done | 3807 | 5178 | differs |
| 1|2026-09-01 | approved_not_done_pct | 14.51 | 13.03 | differs |
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
| 5|2025-01-01 | total_orders | 11012 | 17108 | differs |
| 5|2025-01-01 | approved_orders | 8765 | 8857 | differs |
| 5|2025-01-01 | approved_not_done | 2328 | 2573 | differs |
| 5|2025-01-01 | approved_not_done_pct | 21.14 | 15.04 | differs |
| 5|2025-01-01 | avg_tat_minutes | 35.7 | 57.4 | differs |
| 3|2025-12-01 | total_submitted_claims | 27804646.9500001 | 28124480.0500015 | differs |
| 3|2025-12-01 | not_submitted_claims | 2801.75 | 415955.35 | differs |
| 3|2025-12-01 | approved_amount | 25209346.2399997 | 24688903.9100003 | differs |
| ... | 702 more | | | |

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
| 7|2026-08-01 | doctors_headcount | 103 | 106 | differs |
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
| 1|2026-09-01 | medical_headcount | 637 | 668 | differs |
| 1|2026-09-01 | doctors_headcount | 194 | 184 | differs |
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
| 6|2026-09-01 | headcount | 441 | 476 | differs |
| 6|2026-09-01 | resignations | 0 | 2 | differs |
| 6|2026-09-01 | medical_headcount | 351 | 362 | differs |
| 6|2026-09-01 | doctors_headcount | 151 | 161 | differs |
| 6|2026-09-01 | pt_doctors_headcount | 68 | 61 | differs |
| 6|2026-09-01 | FTE | 407 | 445.5 | differs |
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
| 8|2026-08-01 | doctors_headcount | 37 | 86 | differs |
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
| 6|2025-10-01 | headcount | 383 | 385 | differs |
| 6|2025-10-01 | resignations | 3 | 0 | differs |
| 6|2025-10-01 | medical_headcount | 273 | 275 | differs |
| 6|2025-10-01 | doctors_headcount | 121 | 122 | differs |
| 6|2025-10-01 | FTE | 353.5 | 355.5 | differs |
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
| 7|2025-11-01 | FTE | 0 | 1 | differs |
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
