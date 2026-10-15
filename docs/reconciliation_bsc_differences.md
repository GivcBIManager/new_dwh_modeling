# bsc views: old server against new (generated)

Generated 2026-10-15 13:44 by scripts/compare_bsc.ps1. Months: 2026-08-01, 2026-09-01 and the year 2025. Tolerance: 0.5% relative (absolute below 1). Attribution: docs/reconciliation_bsc.md.

## vw_customer

Keys (branch_id, period): old 89, new 112. Differences: 948.

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
| 4|2026-08-01 | oasis | readmission_within_30days | 36 | 33 | differs |
| 5|2026-08-01 | oasis | non_moh_revenue | 13366494.58 | 13504139.93 | differs |
| 5|2026-08-01 | oasis | insurance_revenue | 10442116.91 | 10845658.28 | differs |
| 5|2026-08-01 | oasis | referrals_revenue | 671967.97 | 666465.65 | differs |
| 5|2026-08-01 | oasis | credit_revenue | 16193291.55 | 16525306.88 | differs |
| 5|2026-08-01 | oasis | op_episodes | 7308 | 7219 | differs |
| 5|2026-08-01 | oasis | referrals_volume | 250 | 245 | differs |
| 5|2026-08-01 | oasis | available_slots | 22518 | 23842 | differs |
| 5|2026-08-01 | oasis | op_waiting_time_in_minutes | 235713 | 230560 | differs |
| 5|2026-08-01 | oasis | icu_discharge | 130 | 128 | differs |
| 5|2025-08-01 | oasis | insurance_revenue | 7481557.11 | 7625253.64 | differs |
| 5|2025-08-01 | oasis | referrals_revenue | 1008057.11 | 1101738.44 | differs |
| 5|2025-08-01 | oasis | credit_revenue | 14304338.12 | 14457799.9 | differs |
| 5|2025-08-01 | oasis | op_episodes | 6994 | 6741 | differs |
| 5|2025-08-01 | oasis | er_census | 1354 | 1368 | differs |
| 5|2025-08-01 | oasis | available_slots | 20362 | 21010 | differs |
| 5|2025-08-01 | oasis | op_waiting_time_in_minutes | 311740 | 306252 | differs |
| 5|2025-08-01 | oasis | icu_discharge | 83 | 81 | differs |
| 6|2025-12-01 | oasis | non_ltc_ip_revenue | 7851341.55 | 7897033.34 | differs |
| 6|2025-12-01 | oasis | insurance_revenue | 2186224.82 | 2238187.43 | differs |
| 6|2025-12-01 | oasis | referrals_revenue | 802541.07 | 837447.73 | differs |
| 6|2025-12-01 | oasis | high_value_service_revenue | 2607133.04 | 2144027.42 | differs |
| 6|2025-12-01 | oasis | high_value_service_volume | 699 | 677 | differs |
| 6|2025-12-01 | oasis | er_census | 599 | 589 | differs |
| 6|2025-12-01 | oasis | available_slots | 16584 | 16716 | differs |
| 6|2025-12-01 | oasis | icu_discharge | 127 | 132 | differs |
| 7|2025-12-01 | oasis | census | 3 | 0 | differs |
| 7|2025-12-01 | oasis | op_census | 3 | 0 | differs |
| 7|2025-12-01 | oasis | distinct_patients | 3 | 0 | differs |
| 7|2025-12-01 | oasis | new_op_census | 2 | 0 | differs |
| 7|2025-12-01 | oasis | op_episodes | 3 | 0 | differs |
| 7|2025-12-01 | oasis | available_slots | 76 | 0 | differs |
| 7|2025-12-01 | oasis | op_waiting_time_in_minutes | 42 | 0 | differs |
| 3|2025-04-01 | oasis | revenue | 23967573.59 | 24094062.77 | differs |
| 3|2025-04-01 | oasis | non_ltc_ip_revenue | 10703389.99 | 10813812.69 | differs |
| 3|2025-04-01 | oasis | non_moh_revenue | 10647297.17 | 10704788.86 | differs |
| 3|2025-04-01 | oasis | insurance_revenue | 6543455.2 | 6601418.35 | differs |
| 3|2025-04-01 | oasis | referrals_revenue | 1145325.37 | 1158656.92 | differs |
| 3|2025-04-01 | oasis | credit_revenue | 20175813.01 | 20291010.89 | differs |
| 3|2025-04-01 | oasis | high_value_service_revenue | 1819530.22 | 1834168.82 | differs |
| 3|2025-04-01 | oasis | op_episodes | 9981 | 9781 | differs |
| 3|2025-04-01 | oasis | er_census | 1734 | 1723 | differs |
| 3|2025-04-01 | oasis | available_slots | 23244 | 23426 | differs |
| 3|2025-04-01 | oasis | op_waiting_time_in_minutes | 396935 | 334773 | differs |
| 3|2025-04-01 | oasis | icu_discharge | 47 | 196 | differs |
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
| 1|2025-04-01 | oasis | icu_discharge | 26 | 25 | differs |
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
| 2|2025-06-01 | oasis | referrals_volume | 1147 | 372 | differs |
| 2|2025-06-01 | oasis | available_slots | 26314 | 4630 | differs |
| 2|2025-06-01 | oasis | op_waiting_time_in_minutes | 214408 | 36078 | differs |
| 2|2025-06-01 | oasis | icu_discharge | 57 | 62 | differs |
| 4|2025-12-01 | oasis | non_moh_revenue | 9704344.32 | 9758453.41 | differs |
| 4|2025-12-01 | oasis | insurance_revenue | 7648095.71 | 7752731.53 | differs |
| 4|2025-12-01 | oasis | referrals_revenue | 1208892.12 | 1217380.2 | differs |
| 4|2025-12-01 | oasis | high_value_service_revenue | 2080852.05 | 2100982.21 | differs |
| 4|2025-12-01 | oasis | op_episodes | 10305 | 10162 | differs |
| 4|2025-12-01 | oasis | er_census | 1107 | 1079 | differs |
| 4|2025-12-01 | oasis | available_slots | 27932 | 27744 | differs |
| 4|2025-12-01 | oasis | op_waiting_time_in_minutes | 285969 | 279700 | differs |
| 4|2025-12-01 | oasis | admissions | 693 | 687 | differs |
| 4|2025-12-01 | oasis | readmission_within_30days | 43 | 37 | differs |
| 4|2025-12-01 | oasis | insurance_admissions | 479 | 474 | differs |
| 4|2025-12-01 | oasis | discharges | 684 | 679 | differs |
| 4|2025-12-01 | oasis | icu_discharge | 92 | 91 | differs |
| 4|2025-12-01 | oasis | alos_non_ltc | 2.44821162444113 | 2.46440920086754 | differs |
| 7|2026-08-01 | oasis | non_moh_revenue | 2478895.7 | 2545789.16 | differs |
| 7|2026-08-01 | oasis | insurance_revenue | 1250208.48 | 1349752.96 | differs |
| 7|2026-08-01 | oasis | credit_revenue | 2752186.58 | 2786510.29 | differs |
| 7|2026-08-01 | oasis | insurance_census | 2235 | 2223 | differs |
| 7|2026-08-01 | oasis | returning_patients | 626 | 274 | differs |
| 7|2026-08-01 | oasis | new_op_census | 1636 | 1646 | differs |
| 7|2026-08-01 | oasis | op_episodes | 2555 | 2455 | differs |
| 7|2026-08-01 | oasis | er_census | 617 | 603 | differs |
| 7|2026-08-01 | oasis | available_slots | 18960 | 17834 | differs |
| 7|2026-08-01 | oasis | op_waiting_time_in_minutes | 116254 | 111375 | differs |
| 7|2026-08-01 | oasis | insurance_admissions | 58 | 59 | differs |
| 7|2026-08-01 | oasis | icu_discharge | 18 | 42 | differs |
| 6|2025-04-01 | oasis | revenue | 5855457.8 | 5889140.57 | differs |
| 6|2025-04-01 | oasis | non_ltc_ip_revenue | 2214382.48 | 2245837.1 | differs |
| 6|2025-04-01 | oasis | non_moh_revenue | 806075.79 | 847311.23 | differs |
| 6|2025-04-01 | oasis | high_value_service_revenue | 449649.1 | 458810.1 | differs |
| 6|2025-04-01 | oasis | census | 1064 | 1052 | differs |
| 6|2025-04-01 | oasis | insurance_census | 18 | 17 | differs |
| 6|2025-04-01 | oasis | returning_patients | 120 | 119 | differs |
| 6|2025-04-01 | oasis | er_census | 418 | 406 | differs |
| 3|2025-12-01 | oasis | non_ltc_ip_revenue | 15334515.34 | 15490898.65 | differs |
| 3|2025-12-01 | oasis | non_moh_revenue | 13851155.09 | 13968081.16 | differs |
| 3|2025-12-01 | oasis | insurance_revenue | 9627022.9 | 9703433.55 | differs |
| 3|2025-12-01 | oasis | op_episodes | 11080 | 10738 | differs |
| 3|2025-12-01 | oasis | er_census | 2051 | 2024 | differs |
| 3|2025-12-01 | oasis | op_waiting_time_in_minutes | 502687 | 471673 | differs |
| 3|2025-12-01 | oasis | icu_discharge | 107 | 297 | differs |
| 5|2025-06-01 | oasis | non_ltc_ip_revenue | 7132554.39 | 7183245.42 | differs |
| 5|2025-06-01 | oasis | non_moh_revenue | 6977155.12 | 6612750.69 | differs |
| 5|2025-06-01 | oasis | insurance_revenue | 4357656.02 | 4457353.1 | differs |
| 5|2025-06-01 | oasis | referrals_revenue | 439604.01 | 529133.91 | differs |
| 5|2025-06-01 | oasis | credit_revenue | 13902564.78 | 14389963.54 | differs |
| 5|2025-06-01 | oasis | high_value_service_revenue | 1258659.37 | 1283864.83 | differs |
| 5|2025-06-01 | oasis | op_episodes | 6220 | 6049 | differs |
| 5|2025-06-01 | oasis | available_slots | 17248 | 17936 | differs |
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
| 1|2025-12-01 | oasis | op_waiting_time_in_minutes | 439104 | 435460 | differs |
| 2|2025-08-01 | oasis | non_moh_revenue | 13026978.73 | 12941259.93 | differs |
| 2|2025-08-01 | oasis | insurance_revenue | 8975122.33 | 9071455.59 | differs |
| 2|2025-08-01 | oasis | referrals_revenue | 2208176.18 | 2222979.96 | differs |
| 2|2025-08-01 | oasis | credit_revenue | 26391586.48 | 26600090.62 | differs |
| 2|2025-08-01 | oasis | high_value_service_volume | 2299 | 661 | differs |
| 2|2025-08-01 | oasis | census | 18431 | 6491 | differs |
| 2|2025-08-01 | oasis | insurance_census | 11093 | 3679 | differs |
| 2|2025-08-01 | oasis | op_census | 16321 | 4366 | differs |
| 2|2025-08-01 | oasis | distinct_patients | 10238 | 5036 | differs |
| 2|2025-08-01 | oasis | returning_patients | 4026 | 1155 | differs |
| 2|2025-08-01 | oasis | new_op_census | 2866 | 791 | differs |
| 2|2025-08-01 | oasis | op_episodes | 12775 | 3450 | differs |
| 2|2025-08-01 | oasis | er_census | 2110 | 2125 | differs |
| 2|2025-08-01 | oasis | referrals_volume | 1452 | 521 | differs |
| 2|2025-08-01 | oasis | available_slots | 30838 | 9202 | differs |
| 2|2025-08-01 | oasis | op_waiting_time_in_minutes | 299420 | 87509 | differs |
| 2|2025-08-01 | oasis | icu_discharge | 46 | 52 | differs |
| 2|2026-08-01 | oasis | revenue | 32241634.65 | 32403946.98 | differs |
| 2|2026-08-01 | oasis | non_ltc_ip_revenue | 11331849.62 | 11394362.89 | differs |
| 2|2026-08-01 | oasis | non_moh_revenue | 17124717.99 | 16922360.38 | differs |
| 2|2026-08-01 | oasis | insurance_revenue | 10938178.21 | 11295817.73 | differs |
| 2|2026-08-01 | oasis | referrals_revenue | 2177895.45 | 2384937.63 | differs |
| 2|2026-08-01 | oasis | credit_revenue | 26484420.86 | 27199510.63 | differs |
| 2|2026-08-01 | oasis | high_value_service_revenue | 4530864.4 | 4652162.9 | differs |
| 2|2026-08-01 | oasis | returning_patients | 4322 | 2503 | differs |
| 2|2026-08-01 | oasis | op_episodes | 14311 | 13842 | differs |
| 2|2026-08-01 | oasis | er_census | 2175 | 2207 | differs |
| 2|2026-08-01 | oasis | referrals_volume | 1734 | 1747 | differs |
| 2|2026-08-01 | oasis | available_slots | 30560 | 34894 | differs |
| 2|2026-08-01 | oasis | op_waiting_time_in_minutes | 466912 | 493991 | differs |
| 2|2026-08-01 | oasis | icu_discharge | 76 | 82 | differs |
| 4|2025-04-01 | oasis | insurance_revenue | 5768684.64 | 5828825.67 | differs |
| 4|2025-04-01 | oasis | credit_revenue | 11891160.84 | 11987238.11 | differs |
| 4|2025-04-01 | oasis | op_episodes | 9039 | 8909 | differs |
| 4|2025-04-01 | oasis | er_census | 1504 | 1477 | differs |
| 4|2025-04-01 | oasis | available_slots | 20612 | 20948 | differs |
| 4|2025-04-01 | oasis | op_waiting_time_in_minutes | 276265 | 274340 | differs |
| 4|2025-04-01 | oasis | icu_discharge | 37 | 36 | differs |
| 3|2026-09-01 | oasis | non_ltc_ip_revenue | 12675772.25 | 12766185.67 | differs |
| 3|2026-09-01 | oasis | insurance_revenue | 10956761.12 | 11043874.79 | differs |
| 3|2026-09-01 | oasis | referrals_revenue | 1057841.38 | 1004204.28 | differs |
| 3|2026-09-01 | oasis | op_episodes | 11907 | 11557 | differs |
| 3|2026-09-01 | oasis | er_census | 2018 | 2042 | differs |
| 3|2026-09-01 | oasis | referrals_volume | 812 | 806 | differs |
| 3|2026-09-01 | oasis | op_waiting_time_in_minutes | 570777 | 544436 | differs |
| 3|2026-09-01 | oasis | insurance_admissions | 558 | 561 | differs |
| 3|2026-09-01 | oasis | icu_discharge | 68 | 273 | differs |
| 3|2025-07-01 | oasis | revenue | 28957342.39 | 29139818.2 | differs |
| 3|2025-07-01 | oasis | non_ltc_ip_revenue | 13634032.82 | 13803564.48 | differs |
| 3|2025-07-01 | oasis | non_moh_revenue | 12059476.61 | 12185867.68 | differs |
| 3|2025-07-01 | oasis | insurance_revenue | 6938512.08 | 7093529.61 | differs |
| 3|2025-07-01 | oasis | referrals_revenue | 1504327.58 | 1603625.88 | differs |
| 3|2025-07-01 | oasis | credit_revenue | 24124716.74 | 24337008.16 | differs |
| 3|2025-07-01 | oasis | op_episodes | 9392 | 9152 | differs |
| 3|2025-07-01 | oasis | er_census | 1454 | 1442 | differs |
| 3|2025-07-01 | oasis | op_waiting_time_in_minutes | 412173 | 374298 | differs |
| 3|2025-07-01 | oasis | icu_discharge | 85 | 246 | differs |
| ... | | 748 more | | | |

## vw_financial

Keys (branch_id, month_date): old 85, new 88. Differences: 446.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 1|2025-06-01 | oasis | ebitda_actual | 5103605.75 | 5149770.75 | differs |
| 1|2025-06-01 | oasis | account_receivable_actual | 11980457.3 | 141140656.64 | differs |
| 1|2025-06-01 | oasis | account_receivable_actual_opening_balance | 16769201.58 | 129160199.34 | differs |
| 1|2025-06-01 | oasis | assets | 2588151.45 | 502103052.29 | differs |
| 1|2025-06-01 | oasis | assets_opening_balance | 5931994.92 | 499514900.84 | differs |
| 5|2025-12-01 | oasis | account_receivable_actual | 3378866.69 | 111366359.76 | differs |
| 5|2025-12-01 | oasis | account_receivable_actual_opening_balance | 13939610.59 | 107987493.07 | differs |
| 5|2025-12-01 | oasis | assets | -8027469.42 | 113532130.26 | differs |
| 5|2025-12-01 | oasis | assets_opening_balance | 6230844.1 | 121559599.68 | differs |
| 4|2025-06-01 | oasis | account_receivable_actual | -2264435.24 | 76890310.8 | differs |
| 4|2025-06-01 | oasis | account_receivable_actual_opening_balance | 10199584.87 | 79154746.04 | differs |
| 4|2025-06-01 | oasis | assets | 1792801.52 | 195479192.35 | differs |
| 4|2025-06-01 | oasis | assets_opening_balance | 904682.07 | 193686390.83 | differs |
| 5|2025-07-01 | oasis | account_receivable_actual | 6411498.8 | 101111066.83 | differs |
| 5|2025-07-01 | oasis | account_receivable_actual_opening_balance | 7729106.13 | 94699568.03 | differs |
| 5|2025-07-01 | oasis | assets | 401830.42 | 105955359.22 | differs |
| 5|2025-07-01 | oasis | assets_opening_balance | 92418.95 | 105553528.8 | differs |
| 1|2025-04-01 | oasis | ebitda_actual | 7346244.77 | 7392410.77 | differs |
| 1|2025-04-01 | oasis | account_receivable_actual | 10907012.41 | 112390997.76 | differs |
| 1|2025-04-01 | oasis | account_receivable_actual_opening_balance | -31938837.82 | 101483985.35 | differs |
| 1|2025-04-01 | oasis | assets | -3280045 | 493582905.92 | differs |
| 1|2025-04-01 | oasis | assets_opening_balance | -4860543.56 | 496862950.92 | differs |
| 4|2025-04-01 | oasis | account_receivable_actual | -2431295.79 | 68955161.17 | differs |
| 4|2025-04-01 | oasis | account_receivable_actual_opening_balance | -24813433.16 | 71386456.96 | differs |
| 4|2025-04-01 | oasis | assets | 300445.25 | 192781708.76 | differs |
| 4|2025-04-01 | oasis | assets_opening_balance | 152789.3 | 192481263.51 | differs |
| 5|2025-05-01 | oasis | account_receivable_actual | 2118588.82 | 86970461.9 | differs |
| 5|2025-05-01 | oasis | account_receivable_actual_opening_balance | 9467902.76 | 84851873.08 | differs |
| 5|2025-05-01 | oasis | assets | 1824080.92 | 105461109.85 | differs |
| 5|2025-05-01 | oasis | assets_opening_balance | -694710.54 | 103637028.93 | differs |
| 4|2025-03-01 | oasis | account_receivable_actual | -24813433.16 | 71386456.96 | differs |
| 4|2025-03-01 | oasis | account_receivable_actual_opening_balance | -825233.28 | 96199890.12 | differs |
| 4|2025-03-01 | oasis | assets | 152789.3 | 192481263.51 | differs |
| 4|2025-03-01 | oasis | assets_opening_balance | 5599812.04 | 192328474.21 | differs |
| 4|2025-01-01 | oasis | account_receivable_actual | 13412650.19 | 97025123.4 | differs |
| 4|2025-01-01 | oasis | account_receivable_actual_opening_balance | 11166377.92 | 83612473.21 | differs |
| 4|2025-01-01 | oasis | assets | 8908064.1 | 186728662.17 | differs |
| 4|2025-01-01 | oasis | assets_opening_balance | 1504497.95 | 177820598.07 | differs |
| 1|2025-03-01 | oasis | account_receivable_actual | -31938837.82 | 101483985.35 | differs |
| 1|2025-03-01 | oasis | account_receivable_actual_opening_balance | 14650392.62 | 133422823.17 | differs |
| 1|2025-03-01 | oasis | assets | -4860543.56 | 496862950.92 | differs |
| 1|2025-03-01 | oasis | assets_opening_balance | 8746693.22 | 501723494.48 | differs |
| 8|2026-08-01 | fusion | net_revenue_actual | 402833.71 | 489031.9 | differs |
| 8|2026-08-01 | fusion | sub_revenue_actual | 402833.71 | 493988.56 | differs |
| 8|2026-08-01 | fusion | operating_expenses | 0 | 3726916.12 | differs |
| 8|2026-08-01 | fusion | ebitda_actual | 402833.71 | -3237884.22 | differs |
| 8|2026-08-01 | fusion | account_receivable_actual | 917.35 | 74783.77 | differs |
| 8|2026-08-01 | fusion | account_receivable_actual_opening_balance | 679.47 | 29763.77 | differs |
| 8|2026-08-01 | fusion | ga_expenses_actual | 0 | 30740 | differs |
| 8|2026-08-01 | fusion | assets | 606791.68 | -8535.07 | differs |
| 8|2026-08-01 | fusion | assets_opening_balance | 198098.17 | 223847.38 | differs |
| 8|2026-08-01 | fusion | income | 402833.71 | -3237901.47 | differs |
| 2|2025-11-01 | oasis | account_receivable_actual | 18658132.88 | 187701332.71 | differs |
| 2|2025-11-01 | oasis | account_receivable_actual_opening_balance | 6802898.38 | 169043199.83 | differs |
| 2|2025-11-01 | oasis | assets | 15022628.48 | 787673836.59 | differs |
| 2|2025-11-01 | oasis | assets_opening_balance | 14474352.31 | 772651208.11 | differs |
| 5|2026-09-01 | fusion | net_revenue_actual | 2868798.78 | -6810.25 | differs |
| 5|2026-09-01 | fusion | sub_revenue_actual | 2868798.78 | -6810.25 | differs |
| 5|2026-09-01 | fusion | operating_expenses | 5932618.61 | 811224.66 | differs |
| 5|2026-09-01 | fusion | ebitda_actual | -3063819.83 | -818034.91 | differs |
| 5|2026-09-01 | fusion | account_receivable_actual | 149835989.59 | 100338321.9 | differs |
| 5|2026-09-01 | fusion | ga_expenses_actual | 0 | 117161.24 | differs |
| 5|2026-09-01 | fusion | consumables_actual | 1394546.13 | 0 | differs |
| 5|2026-09-01 | fusion | assets | 5037322.884 | 302386266.31 | differs |
| 5|2026-09-01 | fusion | assets_opening_balance | -14820670.306 | 302836197.13 | differs |
| 5|2026-09-01 | fusion | income | -3063819.83 | -998663.82 | differs |
| 5|2026-09-01 | fusion | consumables_budget | 3111851.87 | 1396343.79 | differs |
| 2|2025-08-01 | oasis | account_receivable_actual | 510087.87 | 159221204.58 | differs |
| 2|2025-08-01 | oasis | account_receivable_actual_opening_balance | 21306345.9 | 158711116.71 | differs |
| 2|2025-08-01 | oasis | assets | 12240592.7 | 747492524.66 | differs |
| 2|2025-08-01 | oasis | assets_opening_balance | 17302222.35 | 735251931.96 | differs |
| 3|2025-09-01 | oasis | operating_expenses | 15671533.59 | 15456011.59 | differs |
| 3|2025-09-01 | oasis | ebitda_actual | 11590263.6 | 11805785.6 | differs |
| 3|2025-09-01 | oasis | account_receivable_actual | 2250855.87 | 174671403.68 | differs |
| 3|2025-09-01 | oasis | account_receivable_actual_opening_balance | 18925807.4 | 172420547.81 | differs |
| 3|2025-09-01 | oasis | assets | 14238861.66 | 532751472.51 | differs |
| 3|2025-09-01 | oasis | assets_opening_balance | 14066176.91 | 518512610.85 | differs |
| 4|2025-07-01 | oasis | account_receivable_actual | 6780213.4 | 83670524.2 | differs |
| 4|2025-07-01 | oasis | account_receivable_actual_opening_balance | -2264435.24 | 76890310.8 | differs |
| 4|2025-07-01 | oasis | assets | 3901345.77 | 199380538.12 | differs |
| 4|2025-07-01 | oasis | assets_opening_balance | 1792801.52 | 195479192.35 | differs |
| 4|2025-08-01 | oasis | account_receivable_actual | 7126924.05 | 90797448.25 | differs |
| 4|2025-08-01 | oasis | account_receivable_actual_opening_balance | 6780213.4 | 83670524.2 | differs |
| 4|2025-08-01 | oasis | assets | 4580100.05 | 203960638.17 | differs |
| 4|2025-08-01 | oasis | assets_opening_balance | 3901345.77 | 199380538.12 | differs |
| 1|2025-07-01 | oasis | ebitda_actual | 5893888.67 | 5940053.67 | differs |
| 1|2025-07-01 | oasis | account_receivable_actual | 12182234.5 | 153322891.14 | differs |
| 1|2025-07-01 | oasis | account_receivable_actual_opening_balance | 11980457.3 | 141140656.64 | differs |
| 1|2025-07-01 | oasis | assets | -5776466.99 | 496326585.3 | differs |
| 1|2025-07-01 | oasis | assets_opening_balance | 2588151.45 | 502103052.29 | differs |
| 5|2025-02-01 | oasis | account_receivable_actual | 6213566.79 | 81607323.66 | differs |
| 5|2025-02-01 | oasis | account_receivable_actual_opening_balance | -9635056.75 | 75393756.87 | differs |
| 5|2025-02-01 | oasis | assets | 5021197.64 | 105033176.14 | differs |
| 5|2025-02-01 | oasis | assets_opening_balance | 5204890.93 | 100011978.5 | differs |
| 1|2025-08-01 | oasis | ebitda_actual | 4225117.88 | 4271283.88 | differs |
| 1|2025-08-01 | oasis | account_receivable_actual | -16721061.05 | 136601830.09 | differs |
| 1|2025-08-01 | oasis | account_receivable_actual_opening_balance | 12182234.5 | 153322891.14 | differs |
| 1|2025-08-01 | oasis | assets | 3883005.66 | 500209590.96 | differs |
| 1|2025-08-01 | oasis | assets_opening_balance | -5776466.99 | 496326585.3 | differs |
| 2|2026-08-01 | oasis | assets | 874490262.646 | 898860960.52 | differs |
| 2|2026-08-01 | oasis | assets_opening_balance | 877203031.826 | 886257136.26 | differs |
| 2|2026-08-01 | oasis | consumables_budget | 5513311.24 | 2594499.41 | differs |
| 1|2025-01-01 | oasis | ebitda_actual | 7253983.93 | 7316711.4 | differs |
| 1|2025-01-01 | oasis | account_receivable_actual | -30416644.14 | 118772430.55 | differs |
| 1|2025-01-01 | oasis | account_receivable_actual_opening_balance | 3020992.14 | 149189074.69 | differs |
| 1|2025-01-01 | oasis | assets | 2026924.64 | 492976801.26 | differs |
| 1|2025-01-01 | oasis | assets_opening_balance | -8629589.6 | 490949876.62 | differs |
| 5|2025-10-01 | oasis | account_receivable_actual | 2300156.36 | 94047882.48 | differs |
| 5|2025-10-01 | oasis | account_receivable_actual_opening_balance | -18302122.44 | 91747726.12 | differs |
| 5|2025-10-01 | oasis | assets | 5655894.6 | 115328755.58 | differs |
| 5|2025-10-01 | oasis | assets_opening_balance | 1416746.01 | 109672860.98 | differs |
| 6|2025-08-01 | oasis | operating_expenses | 9822807.06 | 9772871.06 | differs |
| 6|2025-08-01 | oasis | ebitda_actual | 3020503.3 | 3070439.3 | differs |
| 6|2025-08-01 | oasis | account_receivable_actual | 3876166.74 | 56421119.19 | differs |
| 6|2025-08-01 | oasis | account_receivable_actual_opening_balance | 10909617.68 | 52544952.45 | differs |
| 6|2025-08-01 | oasis | assets | 2580083.25 | 80280176.1 | differs |
| 6|2025-08-01 | oasis | assets_opening_balance | 3890935.41 | 77700092.85 | differs |
| 4|2025-02-01 | oasis | account_receivable_actual | -825233.28 | 96199890.12 | differs |
| 4|2025-02-01 | oasis | account_receivable_actual_opening_balance | 13412650.19 | 97025123.4 | differs |
| 4|2025-02-01 | oasis | assets | 5599812.04 | 192328474.21 | differs |
| 4|2025-02-01 | oasis | assets_opening_balance | 8908064.1 | 186728662.17 | differs |
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
| 5|2025-03-01 | oasis | account_receivable_actual | -6223353.34 | 75383970.32 | differs |
| 5|2025-03-01 | oasis | account_receivable_actual_opening_balance | 6213566.79 | 81607323.66 | differs |
| 5|2025-03-01 | oasis | assets | -701436.67 | 104331739.47 | differs |
| 5|2025-03-01 | oasis | assets_opening_balance | 5021197.64 | 105033176.14 | differs |
| 4|2025-12-01 | oasis | account_receivable_actual | 84333.01 | 103367189.03 | differs |
| 4|2025-12-01 | oasis | account_receivable_actual_opening_balance | 16445554.53 | 103282856.02 | differs |
| 4|2025-12-01 | oasis | assets | 1240998.6 | 230706783.82 | differs |
| 4|2025-12-01 | oasis | assets_opening_balance | 10452578.28 | 229465785.22 | differs |
| 5|2025-06-01 | oasis | account_receivable_actual | 7729106.13 | 94699568.03 | differs |
| 5|2025-06-01 | oasis | account_receivable_actual_opening_balance | 2118588.82 | 86970461.9 | differs |
| 5|2025-06-01 | oasis | assets | 92418.95 | 105553528.8 | differs |
| 5|2025-06-01 | oasis | assets_opening_balance | 1824080.92 | 105461109.85 | differs |
| 1|2025-10-01 | oasis | ebitda_actual | 5831437.56 | 5877603.56 | differs |
| 1|2025-10-01 | oasis | account_receivable_actual | 1235717.77 | 116872750.36 | differs |
| 1|2025-10-01 | oasis | account_receivable_actual_opening_balance | -20964797.5 | 115637032.59 | differs |
| 1|2025-10-01 | oasis | assets | 6162637.29 | 508493111.64 | differs |
| 1|2025-10-01 | oasis | assets_opening_balance | 2120883.39 | 502330474.35 | differs |
| 4|2025-10-01 | oasis | account_receivable_actual | 7836509.35 | 86837301.49 | differs |
| 4|2025-10-01 | oasis | account_receivable_actual_opening_balance | -11796656.11 | 79000792.14 | differs |
| 4|2025-10-01 | oasis | assets | 10042083.74 | 219013206.94 | differs |
| 4|2025-10-01 | oasis | assets_opening_balance | 5010485.03 | 208971123.2 | differs |
| 5|2025-01-01 | oasis | account_receivable_actual | -9635056.75 | 75393756.87 | differs |
| 5|2025-01-01 | oasis | account_receivable_actual_opening_balance | 1487263.09 | 85028813.62 | differs |
| 5|2025-01-01 | oasis | assets | 5204890.93 | 100011978.5 | differs |
| 5|2025-01-01 | oasis | assets_opening_balance | -944961.17 | 94807087.57 | differs |
| 6|2026-08-01 | fusion | net_revenue_actual | 16914582.16 | 23191095.16 | differs |
| 6|2026-08-01 | fusion | sub_revenue_actual | 16914582.16 | 25947230.39 | differs |
| 6|2026-08-01 | fusion | operating_expenses | 4096417.24 | 15466538.21 | differs |
| 6|2026-08-01 | fusion | ebitda_actual | 12818164.92 | 7724556.95 | differs |
| 6|2026-08-01 | fusion | account_receivable_actual | 178928882.94 | 82828756.23 | differs |
| 6|2026-08-01 | fusion | account_receivable_actual_opening_balance | 161728055.12 | 93825443.9 | differs |
| 6|2026-08-01 | fusion | ga_expenses_actual | 0 | 2309139.29 | differs |
| 6|2026-08-01 | fusion | assets | 188417363.56 | 551719919.41 | differs |
| 6|2026-08-01 | fusion | assets_opening_balance | 169367163.03 | 549416880.53 | differs |
| 6|2026-08-01 | fusion | income | 12818170.67 | 6776696.42 | differs |
| 6|2026-08-01 | fusion | consumables_budget | 4366661.18 | 1871426.22 | differs |
| 1|2025-05-01 | oasis | ebitda_actual | 4211866.66 | 4258031.66 | differs |
| 1|2025-05-01 | oasis | account_receivable_actual | 16769201.58 | 129160199.34 | differs |
| 1|2025-05-01 | oasis | account_receivable_actual_opening_balance | 10907012.41 | 112390997.76 | differs |
| 1|2025-05-01 | oasis | assets | 5931994.92 | 499514900.84 | differs |
| 1|2025-05-01 | oasis | assets_opening_balance | -3280045 | 493582905.92 | differs |
| 3|2025-08-01 | oasis | operating_expenses | 13718244.53 | 13502722.53 | differs |
| 3|2025-08-01 | oasis | ebitda_actual | 12900264.98 | 13115786.98 | differs |
| 3|2025-08-01 | oasis | account_receivable_actual | 18925807.4 | 172420547.81 | differs |
| 3|2025-08-01 | oasis | account_receivable_actual_opening_balance | 16795732.36 | 153494740.41 | differs |
| 3|2025-08-01 | oasis | assets | 14066176.91 | 518512610.85 | differs |
| 3|2025-08-01 | oasis | assets_opening_balance | 12227460.1 | 504446433.94 | differs |
| 4|2025-05-01 | oasis | account_receivable_actual | 10199584.87 | 79154746.04 | differs |
| 4|2025-05-01 | oasis | account_receivable_actual_opening_balance | -2431295.79 | 68955161.17 | differs |
| 4|2025-05-01 | oasis | assets | 904682.07 | 193686390.83 | differs |
| 4|2025-05-01 | oasis | assets_opening_balance | 300445.25 | 192781708.76 | differs |
| 4|2026-09-01 | fusion | net_revenue_actual | 2911534.58 | 0 | differs |
| 4|2026-09-01 | fusion | sub_revenue_actual | 2911534.58 | 0 | differs |
| 4|2026-09-01 | fusion | operating_expenses | 0 | 280625.95 | differs |
| 4|2026-09-01 | fusion | ebitda_actual | 2911534.58 | -280625.95 | differs |
| 4|2026-09-01 | fusion | account_receivable_actual | 181934872.5 | 265120771.16 | differs |
| 4|2026-09-01 | fusion | account_receivable_actual_opening_balance | 181980569.69 | 265117771.16 | differs |
| 4|2026-09-01 | fusion | ga_expenses_actual | 0 | 10254.14 | differs |
| 4|2026-09-01 | fusion | assets | 187732761.73 | 488202176.2 | differs |
| 4|2026-09-01 | fusion | assets_opening_balance | 192142881.943 | 488806070.87 | differs |
| 4|2026-09-01 | fusion | income | 2911534.58 | -290336.31 | differs |
| 4|2026-09-01 | fusion | consumables_budget | 3006789.33 | 1349200.34 | differs |
| 3|2025-11-01 | oasis | operating_expenses | 16424789.42 | 16209267.42 | differs |
| 3|2025-11-01 | oasis | ebitda_actual | 11511075.85 | 11726597.85 | differs |
| 3|2025-11-01 | oasis | account_receivable_actual | 18999074.86 | 186411121.37 | differs |
| 3|2025-11-01 | oasis | account_receivable_actual_opening_balance | -7259357.17 | 167412046.51 | differs |
| 3|2025-11-01 | oasis | assets | 19080659.38 | 565147561.31 | differs |
| 3|2025-11-01 | oasis | assets_opening_balance | 13315429.41 | 546066901.93 | differs |
| 2|2025-09-01 | oasis | account_receivable_actual | 3019096.87 | 162240301.45 | differs |
| ... | | 246 more | | | |

## vw_gl_transactions

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 7029, new 8740. Differences: 8899.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 2|2025-07-01|IS|expenses|general and administrative expenses|repair & maintenance|security and cleaning expenses | oasis | OpeningBalance | 0 | 144426.63 | differs |
| 5|2025-09-01|IS|revenue|revenue - discounts|revenue - settlement discount|rejection | oasis | OpeningBalance | 0 | 10478483.46 | differs |
| 3|2025-06-01|IS|other income|other income, net|other income, net|support medical companies | oasis | OpeningBalance | 0 | -166666.67 | differs |
| 4|2025-03-01|BS|assets|non current assets|work in progress|cwip | oasis | OpeningBalance | 0 | 8853320.4 | differs |
| 1|2025-02-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | oasis | OpeningBalance | 0 | -51091631.91 | differs |
| 2|2026-09-01||||| |  | * |  |  | missing in new |
| 6|2025-04-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | oasis | OpeningBalance | 0 | -4021004.88 | differs |
| 1|2025-02-01|BS|assets|non current assets|intangible assets |software accm amortization |  | * |  |  | missing in new |
| 3|2025-04-01|BS|assets|non current assets|ppe cost|computers cost | oasis | OpeningBalance | 0 | 7398340.88 | differs |
| 1|2025-09-01|BS|assets|current assets|inventories, net|inventory - provision | oasis | OpeningBalance | 0 | -3462708.9 | differs |
| 2|2025-10-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 0 | 551172 | differs |
| 1|2025-05-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | oasis | OpeningBalance | 0 | 11704.48 | differs |
| 6|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | oasis | OpeningBalance | 0 | 154713.77 | differs |
| 2|2025-11-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 0 | 216383359.76 | differs |
| 3|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 0 | 157963666.9 | differs |
| 3|2025-12-01|IS|revenue|revenue|revenue out patient|revenue credit - op | oasis | OpeningBalance | 0 | -40330839.99 | differs |
| 6|2025-02-01|IS|expenses|direct cost|maintenance expense|maintenance expense | oasis | OpeningBalance | 0 | 175768.34 | differs |
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
| 3|2025-06-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 0 | 330837.65 | differs |
| 6|2025-07-01|IS|expenses|direct cost|utilities|utilities | oasis | OpeningBalance | 0 | 1509008.89 | differs |
| 4|2025-02-01|IS|expenses|direct cost|employee costs|part time saudi doctors cost | oasis | OpeningBalance | 0 | 254943 | differs |
| 3|2025-01-01|BS|assets|non current assets|ppe cost|vehicles cost | oasis | OpeningBalance | 0 | 1900574.13 | differs |
| 6|2025-09-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 6|2025-09-01|IS|expenses|direct cost|employee costs|employee govt fees | oasis | OpeningBalance | 0 | 11200 | differs |
| 4|2025-03-01|IS|expenses|direct cost|employee costs|doctor commission - incentive | oasis | OpeningBalance | 0 | 456966.7 | differs |
| 2|2025-03-01|BS|assets|current assets|trade receivables, net|trade receivables - provision | oasis | OpeningBalance | 0 | -36008115.6 | differs |
| 5|2025-12-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 0 | 6901902.23 | differs |
| 6|2025-12-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | 0 | 5104268.07 | differs |
| 3|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 5|2025-02-01|IS|expenses|direct cost|other direct expenses|referral cost | oasis | OpeningBalance | 0 | 52161.5 | differs |
| 5|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|other indirect expenses | oasis | OpeningBalance | 0 | 2190242.63 | differs |
| 3|2025-05-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | oasis | OpeningBalance | 0 | 1719795.5 | differs |
| 6|2025-06-01|IS|expenses|direct cost|cost of goods sold|cost of medicines | oasis | OpeningBalance | 0 | 1574353.63 | differs |
| 1|2025-05-01|IS|expenses|direct cost|other direct expenses|referral cost | oasis | OpeningBalance | 0 | 79655.17 | differs |
| 1|2025-11-01|BS|assets|current assets|inventories, net|goods in transit | oasis | OpeningBalance | 0 | 70901.05 | differs |
| 2|2025-11-01|BS|assets|current assets|prepaid expenses and other assets|other receivables | oasis | OpeningBalance | 0 | 1881973.98 | differs |
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch |  | * |  |  | missing in new |
| 5|2025-07-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | OpeningBalance | 0 | -1499102.98 | differs |
| 5|2025-08-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | oasis | OpeningBalance | 0 | -892590.95 | differs |
| 1|2025-10-01|IS|expenses|direct cost|medical consumables|other direct expenses | oasis | OpeningBalance | 0 | 12105829.43 | differs |
| 5|2025-08-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | oasis | OpeningBalance | 0 | 446666.68 | differs |
| 2|2025-02-01|IS|expenses|zakat|zakat|zakat expense | oasis | OpeningBalance | 0 | 261065.09 | differs |
| 6|2025-09-01|IS|expenses|direct cost|medical consumables|lab consumables | oasis | OpeningBalance | 0 | 1521073.25 | differs |
| 3|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers | oasis | OpeningBalance | 0 | -45295.16 | differs |
| 5|2025-11-01|IS|expenses|general and administrative expenses|other indirect expenses|rental cost | oasis | OpeningBalance | 0 | 580000.03 | differs |
| 5|2025-07-01|IS|expenses|direct cost|employee costs|outsource expenses (givc) | oasis | OpeningBalance | 0 | 2895946.3 | differs |
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
| 2|2025-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 0 | 2519661.12 | differs |
| 4|2025-02-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | OpeningBalance | 0 | 24180.99 | differs |
| 2|2025-05-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | oasis | OpeningBalance | 0 | -15555665.61 | differs |
| 5|2025-05-01|BS|assets|current assets|inventories, net|inventory - non-medical - general | oasis | OpeningBalance | 0 | -329896.67 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip |  | * |  |  | missing in new |
| 5|2025-04-01|BS|assets|current assets|inventories, net|expired stock - sub store | oasis | OpeningBalance | 0 | 370350.12 | differs |
| 2|2025-04-01|IS|revenue|revenue - discounts|revenue - settlement discount|early payment disocunt | oasis | OpeningBalance | 0 | 357191.81 | differs |
| 1|2025-03-01|IS|revenue|revenue - discounts|revenue - settlement discount|rejection | oasis | OpeningBalance | 0 | 3992181.84 | differs |
| 2|2025-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | oasis | OpeningBalance | 0 | -11490706.63 | differs |
| 6|2025-09-01|IS|revenue|revenue|revenue out patient|revenue credit - op | oasis | OpeningBalance | 0 | -4802079.02 | differs |
| 3|2025-12-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued others | oasis | OpeningBalance | 0 | -6230057.43 | differs |
| 5|2025-12-01|IS|expenses|finance cost|finance cost|bank charges | oasis | OpeningBalance | 0 | 268022.79 | differs |
| 6|2025-07-01|IS|other income|other income, net|other income, net|other income | oasis | OpeningBalance | 0 | -8666.68 | differs |
| 2|2025-07-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables | oasis | OpeningBalance | 0 | -479062.46 | differs |
| 1|2025-07-01|BS|assets|current assets|prepaid expenses and other assets|prepaid insurance | oasis | OpeningBalance | 0 | 1472316.64 | differs |
| 1|2025-05-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | OpeningBalance | 0 | -2150574.58 | differs |
| 5|2025-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip | oasis | OpeningBalance | 0 | -27831709.69 | differs |
| 3|2025-11-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 5|2025-05-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | 0 | -1884923.74 | differs |
| 4|2025-12-01|IS|oci|other comprehensive income |re-measurement of retirement benefit obligation|actuarial loss / (gain) |  | * |  |  | missing in new |
| 1|2025-02-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | oasis | OpeningBalance | 0 | -78853696.76 | differs |
| 3|2025-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 3|2025-04-01|IS|expenses|direct cost|maintenance expense|security and cleaning expenses | oasis | OpeningBalance | 0 | 196921.54 | differs |
| 3|2025-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | oasis | OpeningBalance | 0 | 2958355.79 | differs |
| 1|2025-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | 0 | 788188.54 | differs |
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
| ... | | 8699 more | | | |

## vw_gl_openning_balance

Keys (BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE): old 463, new 8740. Differences: 8861.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 2|2026-09-01||||| |  | * |  |  | missing in new |
| 2|2026-08-01|IS|expenses|general and administrative expenses|other indirect expenses|inma supervising expenses  |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | OpeningBalance | -85772.86 | -2327109.04 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | forwarded_balance | -2241336.18 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch |  | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  |  | * |  |  | missing in new |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | OpeningBalance | 2639518.33 | -61088.72 | differs |
| 4|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | forwarded_balance | 133999.9 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip |  | * |  |  | missing in new |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | OpeningBalance | -405499.5 | -2271803.56 | differs |
| 5|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | forwarded_balance | -1866304.06 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|trade receivables, net|trade receivables - provision |  | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -22688596.38 | -71642128.02 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -16679314.161 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 183743.59 | 896222.22 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | forwarded_balance | 712478.63 | 0 | differs |
| 2|2026-08-01||||| |  | * |  |  | missing in new |
| 5|2026-08-01|IS|other income|other income, net|other income, net|hrdf income |  | * |  |  | missing in new |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -14707601.11 | -24315272.2 | differs |
| 4|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -9856671.437 | 0 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | OpeningBalance | 54191821.51 | 229114221.99 | differs |
| 1|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | oasis | forwarded_balance | 174922400.48 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued nafees portal fees |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | OpeningBalance | -641972.63 | -5050311.25 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | forwarded_balance | -4408338.62 | 0 | differs |
| 8|2026-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 1|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | OpeningBalance | -5456199.07 | -34495731.41 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|trade payables|trade payables | oasis | forwarded_balance | -29039532.341 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | OpeningBalance | -870290.74 | 2679108.57 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - main store | oasis | forwarded_balance | 3549399.31 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | OpeningBalance | 401639 | -257899 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | forwarded_balance | -659538 | 0 | differs |
| 2|2026-09-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 6|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 6|2026-08-01|IS|revenue|revenue|revenue out patient|revenue credit - op |  | * |  |  | missing in new |
| 2|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | OpeningBalance | -551157.81 | -1252605.71 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | forwarded_balance | -701447.9 | 0 | differs |
| 3|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | OpeningBalance | -44679.34 | 225716.5 | differs |
| 3|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | forwarded_balance | 233959.445 | 0 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | oasis | OpeningBalance | -6662913.06 | -89320249.67 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|medical equip accm dep | oasis | forwarded_balance | -82657336.61 | 0 | differs |
| 5|2026-08-01||||| |  | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 4|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | fusion | OpeningBalance | -597382.54 | -8072472.9 | differs |
| 4|2026-08-01|BS|liabilities|non current liabilities|end-of-service indemnities|end-of-service indemnities | fusion | forwarded_balance | -8890643.362 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | OpeningBalance | 38018.09 | 296505.32 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | forwarded_balance | 258487.23 | 0 | differs |
| 3|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | OpeningBalance | -75941.96 | 181832.2 | differs |
| 3|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | forwarded_balance | 233959.445 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | 1126162.48 | 149669980.4 | differs |
| 5|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 148543337.06 | 0 | differs |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|payable to patients / customers |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | OpeningBalance | 47602.19 | -92855599.77 | differs |
| 1|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due to branch | oasis | forwarded_balance | -92903201.96 | 0 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | oasis | OpeningBalance | -3466643.72 | -59327290.52 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | oasis | forwarded_balance | -55860646.8 | 0 | differs |
| 1|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities |  | * |  |  | missing in new |
| 4|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | OpeningBalance | 599689.37 | 750539.6 | differs |
| 4|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|advance to employees | fusion | forwarded_balance | 150850.232 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | OpeningBalance | -2105800 | -6977883 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|zakat payable|zakat payable | oasis | forwarded_balance | -4872083 | 0 | differs |
| 4|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | 54316657.15 | 296848067.72 | differs |
| 4|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 127663912.54 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 2|2026-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 5|2026-09-01|IS|expenses|direct cost|employee costs|employee costs | fusion | OpeningBalance | 39131555.701 | 44819161.04 | differs |
| 1|2026-09-01|IS|expenses|general and administrative expenses|travelling expenses |travelling expenses  |  | * |  |  | missing in new |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | OpeningBalance | 3107206.29 | 106215874.42 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | forwarded_balance | 103108668.13 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 8|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -6551.75 | -5502.04 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|advertisement and electrical equip accm dep | oasis | OpeningBalance | 0 | -12917185.83 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|advertisement and electrical equip accm dep | oasis | forwarded_balance | -12917185.83 | 0 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | OpeningBalance | -115320.07 | -242542.71 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | forwarded_balance | -127222.64 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|due from / ( due to) branch|due from branch | oasis | OpeningBalance | 125169882 | 624867439.48 | differs |
| 2|2026-08-01|BS|assets|current assets|due from / ( due to) branch|due from branch | oasis | forwarded_balance | 499697557.48 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | OpeningBalance | 1549338.1 | 2084958.29 | differs |
| 1|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|other prepayments | oasis | forwarded_balance | 535620.19 | 0 | differs |
| 4|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -12015858.46 | -21872529.9 | differs |
| 4|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | forwarded_balance | -9856671.437 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | OpeningBalance | 261176.98 | 291249.98 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|cash | oasis | forwarded_balance | 30073 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 1|2026-09-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | OpeningBalance | -524617 | -12550204 | differs |
| 1|2026-09-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | forwarded_balance | -12025587 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | OpeningBalance | 1686064.63 | 7160689.52 | differs |
| 1|2026-08-01|BS|assets|current assets|cash and bank balances|bank | oasis | forwarded_balance | 5474624.89 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|package discount | fusion | OpeningBalance | 60640830.44 | 42242688.46 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|computers cost | oasis | OpeningBalance | 633126.74 | 7886896.63 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|computers cost | oasis | forwarded_balance | 7253769.89 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | OpeningBalance | 13597.46 | 0 | differs |
| 1|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued utilities | oasis | forwarded_balance | -13597.46 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | fusion | OpeningBalance | 919468.98 | 1317624.19 | differs |
| 2|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | 4634899.67 | 432652964.66 | differs |
| 2|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 241275023.709 | 0 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | oasis | OpeningBalance | -963770.68 | 767964.71 | differs |
| 5|2026-08-01|BS|assets|current assets|inventories, net|inventory - medical - sub store | oasis | forwarded_balance | 1731735.39 | 0 | differs |
| 5|2026-09-01|IS|expenses|direct cost|medical consumables|stock adjustments |  | * |  |  | missing in new |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | OpeningBalance | -19172352.21 | -35851666.37 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | oasis | forwarded_balance | -16679314.161 | 0 | differs |
| 1|2026-08-01|BS|assets|current assets|inventories, net|inventory - provision | oasis | OpeningBalance | 601241.89 | -1203120.36 | differs |
| 1|2026-08-01|BS|assets|current assets|inventories, net|inventory - provision | oasis | forwarded_balance | -1804362.25 | 0 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | OpeningBalance | -165604.16 | -6922450.83 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe accm depreciation|furniture accm dep | oasis | forwarded_balance | -6756846.67 | 0 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | OpeningBalance | 142940.5 | 2425232.23 | differs |
| 2|2026-08-01|BS|assets|current assets|prepaid expenses and other assets|prepaid visa | oasis | forwarded_balance | 2282291.73 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 1223432.93 | 51132692.85 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | forwarded_balance | 49909259.92 | 0 | differs |
| 1|2026-09-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | OpeningBalance | -323162 | -3139276 | differs |
| 1|2026-09-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | forwarded_balance | -2816114 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue cash - ip |  | * |  |  | missing in new |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | OpeningBalance | 6295.27 | 39916.27 | differs |
| 5|2026-09-01|BS|assets|current assets|cash and bank balances|cash | fusion | forwarded_balance | 74621 | 0 | differs |
| 6|2026-08-01|IS|revenue|revenue - discounts|revenue - contractual discounts|credit discount | fusion | OpeningBalance | 6842538.28 | 3825480.46 | differs |
| 2|2026-08-01|IS|expenses|direct cost|deprecition|depreciation expense |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | oasis | OpeningBalance | 3027457.52 | 3339281.23 | differs |
| 1|2026-08-01|BS|assets|non current assets|work in progress|cwip | oasis | forwarded_balance | 311823.71 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - main store |  | * |  |  | missing in new |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | OpeningBalance | -26220991.22 | 235746693.46 | differs |
| 3|2026-09-01|BS|assets|current assets|trade receivables, net|trade receivables | fusion | forwarded_balance | 230572199.28 | 0 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | OpeningBalance | -449924 | -12475511 | differs |
| 1|2026-08-01|BS|liabilities|non current liabilities|lease liability|right of use-lease liability | oasis | forwarded_balance | -12025587 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | OpeningBalance | -554955.58 | -4963294.2 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|computers accm dep | oasis | forwarded_balance | -4408338.62 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | OpeningBalance | -276996 | -3093110 | differs |
| 1|2026-08-01|BS|assets|non current assets|right of use - asset|right of use - accm dep | oasis | forwarded_balance | -2816114 | 0 | differs |
| 8|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|vat payable | fusion | OpeningBalance | -12411.55 | -8449.98 | differs |
| 2|2026-09-01|IS|revenue|revenue - discounts|revenue - contractual discounts|cash discount | fusion | OpeningBalance | 3247733 | 6495466 | differs |
| 5|2026-08-01|IS|expected credit loss |expected credit loss |expected credit loss |expected credit loss  |  | * |  |  | missing in new |
| 5|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | OpeningBalance | 523306.15 | -39.8 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|due to related parties|due to related parties | oasis | forwarded_balance | -523345.95 | 0 | differs |
| 3|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 2|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|other payables |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid  maintenance |  | * |  |  | missing in new |
| 2|2026-09-01|BS|assets|current assets|due from / ( due to) branch|due from branch |  | * |  |  | missing in new |
| 5|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | fusion | OpeningBalance | -932257.851 | -7309211.24 | differs |
| 5|2026-09-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|employee cost - accrual | fusion | forwarded_balance | -5103236.7 | 0 | differs |
| 5|2026-09-01|BS|assets|current assets|inventories, net|inventory - medical - sub store |  | * |  |  | missing in new |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | OpeningBalance | -38299.29 | 117524565.27 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe cost|medical equip cost | oasis | forwarded_balance | 117562864.56 | 0 | differs |
| 2|2026-09-01|IS|expenses|direct cost|maintenance expense|vehicle maintenance | fusion | OpeningBalance | 36942.59 | 73885.18 | differs |
| 6|2026-08-01|IS|revenue|revenue|revenue inpatient|revenue credit - ip |  | * |  |  | missing in new |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | OpeningBalance | -319151.52 | -1097212.52 | differs |
| 5|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued pt doctor fee | oasis | forwarded_balance | -778061 | 0 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | oasis | OpeningBalance | 9900.92 | -722.12 | differs |
| 2|2026-08-01|BS|liabilities|current liabilities|accrued expenses and other liabilities|accrued communication expense | oasis | forwarded_balance | -10623.04 | 0 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | OpeningBalance | -98315.12 | -2339651.3 | differs |
| 1|2026-09-01|BS|assets|non current assets|ppe accm depreciation|vehicles accm dep | oasis | forwarded_balance | -2241336.18 | 0 | differs |
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
| 6|2026-08-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 1|2026-09-01|IS|expenses|selling and marketing expenses|selling and marketing expenses|advertisement expenses  |  | * |  |  | missing in new |
| 8|2026-09-01|IS|revenue|revenue|revenue out patient|revenue cash - op |  | * |  |  | missing in new |
| 1|2026-08-01|IS|expenses|direct cost|deprecition|depreciation expense |  | * |  |  | missing in new |
| 4|2026-08-01|IS|expenses|general and administrative expenses|employee cost|employee cost |  | * |  |  | missing in new |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | OpeningBalance | -4045.68 | 254441.55 | differs |
| 1|2026-09-01|BS|assets|current assets|prepaid expenses and other assets|prepaid subscription fee | oasis | forwarded_balance | 258487.23 | 0 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | oasis | OpeningBalance | -3024396.99 | -58885043.79 | differs |
| 1|2026-08-01|BS|assets|non current assets|ppe accm depreciation|building accm dep | oasis | forwarded_balance | -55860646.8 | 0 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | OpeningBalance | 143818.58 | 9467184.13 | differs |
| 2|2026-08-01|BS|assets|non current assets|ppe cost|furniture cost | oasis | forwarded_balance | 9323365.55 | 0 | differs |
| 4|2026-08-01|IS|revenue|revenue|revenue out patient|revenue credit - op |  | * |  |  | missing in new |
| ... | | 8661 more | | | |

## vw_hospital_beds_utilization

Keys (hospital_id, period): old 88, new 88. Differences: 613.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 3|2025-06-01 | oasis | available_beds | 235 | 244 | differs |
| 3|2025-06-01 | oasis | alos | 32.3448506289308 | 2.98832070707071 | differs |
| 3|2025-06-01 | oasis | ltc_alos | 321.422138047138 | 61.032532051282 | differs |
| 3|2025-06-01 | oasis | non_ltc_alos | 2.56477627471384 | 2.13953021497313 | differs |
| 3|2025-06-01 | oasis | total_bed_nights | 4216 | 3847 | differs |
| 3|2025-06-01 | oasis | available_bed_nights | 7050 | 7320 | differs |
| 3|2025-06-01 | oasis | occupancy_rate | 0.598014184397163 | 0.525546448087432 | differs |
| 1|2026-09-01 | oasis | available_beds | 462 | 452 | differs |
| 1|2026-09-01 | oasis | alos | 139.750684743906 | 6.95001671346436 | differs |
| 1|2026-09-01 | oasis | ltc_alos | 496.918892185955 | 139.725818452381 | differs |
| 1|2026-09-01 | oasis | non_ltc_alos | 2.97149621212121 | 2.32022537013975 | differs |
| 1|2026-09-01 | oasis | total_bed_nights | 11106 | 11351 | differs |
| 1|2026-09-01 | oasis | available_bed_nights | 13860 | 13559 | differs |
| 1|2026-09-01 | oasis | occupancy_rate | 0.801298701298701 | 0.837156132458146 | differs |
| 2|2025-09-01 | oasis | available_beds | 251 | 311 | differs |
| 2|2025-09-01 | oasis | alos | 34.3367850098619 | 5.35100414078676 | differs |
| 2|2025-09-01 | oasis | ltc_alos | 244.268129770992 | 116.757098765432 | differs |
| 2|2025-09-01 | oasis | non_ltc_alos | 3.19181766704417 | 2.80296131582663 | differs |
| 2|2025-09-01 | oasis | total_bed_nights | 5393 | 5356 | differs |
| 2|2025-09-01 | oasis | available_bed_nights | 7530 | 9327 | differs |
| 2|2025-09-01 | oasis | occupancy_rate | 0.716201859229748 | 0.574246810335585 | differs |
| 3|2025-05-01 | oasis | alos | 27.8184013605442 | 3.12396666154161 | differs |
| 3|2025-05-01 | oasis | ltc_alos | 307.134395424837 | 62.9482638888889 | differs |
| 3|2025-05-01 | oasis | non_ltc_alos | 2.44864945087563 | 2.22772250832293 | differs |
| 3|2025-05-01 | oasis | total_bed_nights | 4651 | 4203 | differs |
| 3|2025-05-01 | oasis | occupancy_rate | 0.638435140700069 | 0.575832305795314 | differs |
| 5|2026-08-01 | oasis | available_beds | 203 | 201 | differs |
| 5|2026-08-01 | oasis | alos | 35.3382221026193 | 31.0630532434932 | differs |
| 5|2026-08-01 | oasis | ltc_alos | 468.510256410256 | 525.851947463768 | differs |
| 5|2026-08-01 | oasis | non_ltc_alos | 2.75004822530864 | 2.43375873515025 | differs |
| 5|2026-08-01 | oasis | available_bed_nights | 6293 | 6231 | differs |
| 4|2025-11-01 | oasis | available_beds | 244 | 256 | differs |
| 4|2025-11-01 | oasis | census | 941 | 966 | differs |
| 4|2025-11-01 | oasis | ltc_census | 91 | 118 | differs |
| 4|2025-11-01 | oasis | alos | 58.7487601842012 | 4.70407834580216 | differs |
| 4|2025-11-01 | oasis | ltc_alos | 580.814102564103 | 178.902314814815 | differs |
| 4|2025-11-01 | oasis | non_ltc_alos | 2.85705882352941 | 2.72704918032787 | differs |
| 4|2025-11-01 | oasis | available_bed_nights | 7320 | 7673 | differs |
| 4|2025-11-01 | oasis | occupancy_rate | 0.57568306010929 | 0.55102306790043 | differs |
| 6|2025-10-01 | oasis | available_beds | 209 | 166 | differs |
| 6|2025-10-01 | oasis | alos | 33.0885646108664 | 8.21342250164366 | differs |
| 6|2025-10-01 | oasis | ltc_alos | 181.324530516432 | 89.1712072649573 | differs |
| 6|2025-10-01 | oasis | non_ltc_alos | 5.60879025239338 | 4.97511111111111 | differs |
| 6|2025-10-01 | oasis | total_bed_nights | 3109 | 2531 | differs |
| 6|2025-10-01 | oasis | available_bed_nights | 6479 | 5139 | differs |
| 6|2025-10-01 | oasis | occupancy_rate | 0.479858002778207 | 0.492508270091457 | differs |
| 1|2025-11-01 | oasis | available_beds | 462 | 450 | differs |
| 1|2025-11-01 | oasis | alos | 172.24394977169 | 5.33153643530799 | differs |
| 1|2025-11-01 | oasis | ltc_alos | 616.98289183223 | 162.157852564103 | differs |
| 1|2025-11-01 | oasis | non_ltc_alos | 2.87300336275746 | 2.58019755585545 | differs |
| 1|2025-11-01 | oasis | total_bed_nights | 9896 | 10183 | differs |
| 1|2025-11-01 | oasis | available_bed_nights | 13860 | 13485 | differs |
| 1|2025-11-01 | oasis | occupancy_rate | 0.713997113997114 | 0.755135335558027 | differs |
| 5|2025-03-01 | oasis | available_beds | 203 | 224 | differs |
| 5|2025-03-01 | oasis | alos | 64.3003521126761 | 4.35683546651827 | differs |
| 5|2025-03-01 | oasis | ltc_alos | 453.168836805556 | 51.3931481481482 | differs |
| 5|2025-03-01 | oasis | non_ltc_alos | 3.50006786102063 | 3.14871099695586 | differs |
| 5|2025-03-01 | oasis | total_bed_nights | 4053 | 3502 | differs |
| 5|2025-03-01 | oasis | available_bed_nights | 6293 | 6954 | differs |
| 5|2025-03-01 | oasis | occupancy_rate | 0.6440489432703 | 0.503595053206787 | differs |
| 5|2025-07-01 | oasis | available_beds | 203 | 216 | differs |
| 5|2025-07-01 | oasis | alos | 76.9101542741528 | 6.4443463740458 | differs |
| 5|2025-07-01 | oasis | ltc_alos | 455.721064814815 | 237.831712962963 | differs |
| 5|2025-07-01 | oasis | non_ltc_alos | 2.66046581972172 | 2.40068365695793 | differs |
| 5|2025-07-01 | oasis | total_bed_nights | 3930 | 2446 | differs |
| 5|2025-07-01 | oasis | available_bed_nights | 6293 | 6683 | differs |
| 5|2025-07-01 | oasis | occupancy_rate | 0.624503416494518 | 0.36600329193476 | differs |
| 5|2025-01-01 | oasis | available_beds | 203 | 244 | differs |
| 5|2025-01-01 | oasis | alos | 46.623097826087 | 4.38390906169666 | differs |
| 5|2025-01-01 | oasis | ltc_alos | 522.115679824561 | 110.84246031746 | differs |
| 5|2025-01-01 | oasis | non_ltc_alos | 3.80623025276461 | 3.41735930969881 | differs |
| 5|2025-01-01 | oasis | total_bed_nights | 4166 | 3835 | differs |
| 5|2025-01-01 | oasis | available_bed_nights | 6293 | 7552 | differs |
| 5|2025-01-01 | oasis | occupancy_rate | 0.66200540282854 | 0.5078125 | differs |
| 6|2025-07-01 | oasis | available_beds | 209 | 144 | differs |
| 6|2025-07-01 | oasis | alos | 38.3142543859649 | 8.6576179245283 | differs |
| 6|2025-07-01 | oasis | ltc_alos | 151.956325301205 | 52.7948937908497 | differs |
| 6|2025-07-01 | oasis | non_ltc_alos | 6.55569584736251 | 5.6320788530466 | differs |
| 6|2025-07-01 | oasis | total_bed_nights | 3339 | 2224 | differs |
| 6|2025-07-01 | oasis | available_bed_nights | 6479 | 4464 | differs |
| 6|2025-07-01 | oasis | occupancy_rate | 0.515357308226578 | 0.498207885304659 | differs |
| 1|2025-08-01 | oasis | alos | 217.428813395277 | 6.3359752415459 | differs |
| 1|2025-08-01 | oasis | ltc_alos | 637.446449026346 | 116.392279411765 | differs |
| 1|2025-08-01 | oasis | non_ltc_alos | 2.99875730994152 | 2.83885903426791 | differs |
| 1|2025-08-01 | oasis | total_bed_nights | 9584 | 9759 | differs |
| 1|2025-08-01 | oasis | occupancy_rate | 0.669180282083508 | 0.684601894072255 | differs |
| 3|2025-12-01 | oasis | alos | 30.3496332518337 | 4.2444558950318 | differs |
| 3|2025-12-01 | oasis | ltc_alos | 314.931603773585 | 78.4436683006536 | differs |
| 3|2025-12-01 | oasis | non_ltc_alos | 3.4400089206066 | 3.0004848783695 | differs |
| 3|2025-12-01 | oasis | total_bed_nights | 5454 | 5203 | differs |
| 3|2025-12-01 | oasis | occupancy_rate | 0.74866163349348 | 0.716469292206004 | differs |
| 2|2025-08-01 | oasis | available_beds | 251 | 312 | differs |
| 2|2025-08-01 | oasis | alos | 35.2123871614845 | 4.35544097222222 | differs |
| 2|2025-08-01 | oasis | ltc_alos | 242.875626566416 | 80.1033333333333 | differs |
| 2|2025-08-01 | oasis | non_ltc_alos | 3.24570794753087 | 2.90802901627743 | differs |
| 2|2025-08-01 | oasis | total_bed_nights | 5698 | 5610 | differs |
| 2|2025-08-01 | oasis | available_bed_nights | 7781 | 9672 | differs |
| 2|2025-08-01 | oasis | occupancy_rate | 0.732296619971726 | 0.580024813895782 | differs |
| 6|2025-02-01 | oasis | available_beds | 209 | 138 | differs |
| 6|2025-02-01 | oasis | alos | 44.0422149122807 | 10.3212051066218 | differs |
| 6|2025-02-01 | oasis | ltc_alos | 113.823529411765 | 43.4032738095238 | differs |
| 6|2025-02-01 | oasis | non_ltc_alos | 8.80610561056105 | 7.80409118357488 | differs |
| 6|2025-02-01 | oasis | total_bed_nights | 1462 | 1356 | differs |
| 6|2025-02-01 | oasis | available_bed_nights | 5852 | 3872 | differs |
| 6|2025-02-01 | oasis | occupancy_rate | 0.249829118250171 | 0.350206611570248 | differs |
| 2|2025-11-01 | oasis | available_beds | 251 | 300 | differs |
| 2|2025-11-01 | oasis | alos | 29.3817757009346 | 6.55112489161402 | differs |
| 2|2025-11-01 | oasis | ltc_alos | 238.135854341737 | 123.623691239316 | differs |
| 2|2025-11-01 | oasis | non_ltc_alos | 3.26007711181213 | 3.05642141854829 | differs |
| 2|2025-11-01 | oasis | total_bed_nights | 5332 | 5239 | differs |
| 2|2025-11-01 | oasis | available_bed_nights | 7530 | 9000 | differs |
| 2|2025-11-01 | oasis | occupancy_rate | 0.708100929614874 | 0.582111111111111 | differs |
| 6|2025-03-01 | oasis | available_beds | 209 | 138 | differs |
| 6|2025-03-01 | oasis | alos | 65.7767412935324 | 14.7832536429872 | differs |
| 6|2025-03-01 | oasis | ltc_alos | 120.514705882353 | 53.5649305555556 | differs |
| 6|2025-03-01 | oasis | non_ltc_alos | 9.38005050505051 | 8.92941561844864 | differs |
| 6|2025-03-01 | oasis | total_bed_nights | 2165 | 1620 | differs |
| 6|2025-03-01 | oasis | available_bed_nights | 6479 | 4278 | differs |
| 6|2025-03-01 | oasis | occupancy_rate | 0.334156505633585 | 0.378681626928471 | differs |
| 7|2026-09-01 | oasis | available_beds | 128 | 127 | differs |
| 7|2026-09-01 | oasis | ltc_census | 64 | 65 | differs |
| 7|2026-09-01 | oasis | alos | 3.14974358974359 | 2.16494686800895 | differs |
| 7|2026-09-01 | oasis | ltc_alos | 6.38802083333333 | 2.55003531073446 | differs |
| 7|2026-09-01 | oasis | non_ltc_alos | 2.35568326947637 | 2.06988319386332 | differs |
| 7|2026-09-01 | oasis | available_bed_nights | 3840 | 3810 | differs |
| 6|2025-06-01 | oasis | available_beds | 209 | 146 | differs |
| 6|2025-06-01 | oasis | alos | 40.4973958333333 | 8.17113935969868 | differs |
| 6|2025-06-01 | oasis | ltc_alos | 161.01295045045 | 60.9008207070707 | differs |
| 6|2025-06-01 | oasis | non_ltc_alos | 6.45865139949109 | 5.59324382716049 | differs |
| 6|2025-06-01 | oasis | total_bed_nights | 2720 | 1951 | differs |
| 6|2025-06-01 | oasis | available_bed_nights | 6270 | 4384 | differs |
| 6|2025-06-01 | oasis | occupancy_rate | 0.433811802232855 | 0.445027372262774 | differs |
| 6|2025-05-01 | oasis | available_beds | 209 | 146 | differs |
| 6|2025-05-01 | oasis | alos | 52.8186490455213 | 11.5236157100809 | differs |
| 6|2025-05-01 | oasis | ltc_alos | 164.576923076923 | 53.5963541666667 | differs |
| 6|2025-05-01 | oasis | non_ltc_alos | 7.97736625514403 | 6.5372170781893 | differs |
| 6|2025-05-01 | oasis | total_bed_nights | 2299 | 1626 | differs |
| 6|2025-05-01 | oasis | available_bed_nights | 6479 | 4511 | differs |
| 6|2025-05-01 | oasis | occupancy_rate | 0.354838709677419 | 0.360452227887386 | differs |
| 6|2025-01-01 | oasis | available_beds | 209 | 138 | differs |
| 6|2025-01-01 | oasis | alos | 26.4849290780142 | 7.5054592457421 | differs |
| 6|2025-01-01 | oasis | ltc_alos | 130.733630952381 | 37.2400462962963 | differs |
| 6|2025-01-01 | oasis | non_ltc_alos | 8.24140625 | 6.83975953565506 | differs |
| 6|2025-01-01 | oasis | total_bed_nights | 1505 | 1459 | differs |
| 6|2025-01-01 | oasis | available_bed_nights | 6479 | 4284 | differs |
| 6|2025-01-01 | oasis | occupancy_rate | 0.232288933477388 | 0.340569561157796 | differs |
| 4|2025-04-01 | oasis | census | 682 | 709 | differs |
| 4|2025-04-01 | oasis | ltc_census | 66 | 93 | differs |
| 4|2025-04-01 | oasis | alos | 79.0244990224829 | 3.08567523640662 | differs |
| 4|2025-04-01 | oasis | ltc_alos | 795.372474747475 | 296.375 | differs |
| 4|2025-04-01 | oasis | non_ltc_alos | 2.2729301948052 | 2.04194098457889 | differs |
| 4|2025-04-01 | oasis | total_bed_nights | 2956 | 2704 | differs |
| 4|2025-04-01 | oasis | available_bed_nights | 7320 | 7359 | differs |
| 4|2025-04-01 | oasis | occupancy_rate | 0.403825136612022 | 0.367441228427775 | differs |
| 5|2025-10-01 | oasis | available_beds | 203 | 206 | differs |
| 5|2025-10-01 | oasis | alos | 58.2402512185977 | 3.16154329718686 | differs |
| 5|2025-10-01 | oasis | ltc_alos | 386.4169921875 | 134.832986111111 | differs |
| 5|2025-10-01 | oasis | non_ltc_alos | 3.04100963644328 | 2.7880072892041 | differs |
| 5|2025-10-01 | oasis | total_bed_nights | 5357 | 3198 | differs |
| 5|2025-10-01 | oasis | available_bed_nights | 6293 | 6372 | differs |
| 5|2025-10-01 | oasis | occupancy_rate | 0.851263308437947 | 0.501883239171375 | differs |
| 1|2025-09-01 | oasis | available_beds | 462 | 451 | differs |
| 1|2025-09-01 | oasis | alos | 198.29818802521 | 8.48395597738287 | differs |
| 1|2025-09-01 | oasis | ltc_alos | 642.728665521191 | 278.025297619048 | differs |
| 1|2025-09-01 | oasis | non_ltc_alos | 2.64120020171457 | 2.24663567493113 | differs |
| 1|2025-09-01 | oasis | total_bed_nights | 9301 | 9570 | differs |
| 1|2025-09-01 | oasis | available_bed_nights | 13860 | 13530 | differs |
| 1|2025-09-01 | oasis | occupancy_rate | 0.671067821067821 | 0.707317073170732 | differs |
| 6|2026-08-01 | oasis | available_beds | 209 | 192 | differs |
| 6|2026-08-01 | oasis | alos | 26.5101872246696 | 4.61189236111111 | differs |
| 6|2026-08-01 | oasis | ltc_alos | 186.902529761905 | 80.2116898148148 | differs |
| 6|2026-08-01 | oasis | non_ltc_alos | 3.94242043551089 | 3.3588570441989 | differs |
| 6|2026-08-01 | oasis | total_bed_nights | 2735 | 2782 | differs |
| 6|2026-08-01 | oasis | available_bed_nights | 6479 | 5949 | differs |
| 6|2026-08-01 | oasis | occupancy_rate | 0.422133045223028 | 0.46764162044041 | differs |
| 2|2026-09-01 | oasis | available_beds | 251 | 278 | differs |
| 2|2026-09-01 | oasis | alos | 18.8165526230042 | 4.65838668994956 | differs |
| 2|2026-09-01 | oasis | ltc_alos | 69.2581967213115 | 14.7475420321637 | differs |
| 2|2026-09-01 | oasis | non_ltc_alos | 3.01711596063329 | 2.48928964325004 | differs |
| 2|2026-09-01 | oasis | total_bed_nights | 4442 | 4495 | differs |
| 2|2026-09-01 | oasis | available_bed_nights | 7530 | 8351 | differs |
| 2|2026-09-01 | oasis | occupancy_rate | 0.589907038512616 | 0.53825889115076 | differs |
| 3|2026-08-01 | oasis | available_beds | 235 | 247 | differs |
| 3|2026-08-01 | oasis | alos | 27.9866148531952 | 4.90253646735991 | differs |
| 3|2026-08-01 | oasis | ltc_alos | 240.687647754137 | 87.9346420940171 | differs |
| 3|2026-08-01 | oasis | non_ltc_alos | 3.20079201101928 | 2.98867587667455 | differs |
| 3|2026-08-01 | oasis | total_bed_nights | 6570 | 6135 | differs |
| 3|2026-08-01 | oasis | available_bed_nights | 7285 | 7672 | differs |
| 3|2026-08-01 | oasis | occupancy_rate | 0.901853122855182 | 0.79966110531804 | differs |
| 5|2025-05-01 | oasis | available_beds | 203 | 217 | differs |
| 5|2025-05-01 | oasis | alos | 77.6371248660236 | 4.11923358074674 | differs |
| 5|2025-05-01 | oasis | ltc_alos | 493.067105263158 | 132.038541666667 | differs |
| 5|2025-05-01 | oasis | non_ltc_alos | 2.74936748893106 | 2.54645520264117 | differs |
| 5|2025-05-01 | oasis | total_bed_nights | 3530 | 2643 | differs |
| 5|2025-05-01 | oasis | available_bed_nights | 6293 | 6735 | differs |
| 5|2025-05-01 | oasis | occupancy_rate | 0.560940727792786 | 0.392427616926503 | differs |
| 4|2025-09-01 | oasis | available_beds | 244 | 284 | differs |
| 4|2025-09-01 | oasis | census | 740 | 767 | differs |
| 4|2025-09-01 | oasis | ltc_census | 74 | 101 | differs |
| 4|2025-09-01 | oasis | alos | 73.4484234234234 | 6.89884556984637 | differs |
| ... | | 413 more | | | |

## vw_rcm

Keys (hospital_id, period): old 88, new 88. Differences: 862.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 5|2025-06-01 | oasis | total_submitted_claims | 13012469.2500004 | 13278111.8099999 | differs |
| 5|2025-06-01 | oasis | not_submitted_claims | 259710.13 | 351404.31 | differs |
| 5|2025-06-01 | oasis | approved_amount | 10947421.6000001 | 10615786.93 | differs |
| 5|2025-06-01 | oasis | rejections | 2065047.64999999 | 2187886.99000001 | differs |
| 5|2025-06-01 | oasis | rejection_rate_pct | 15.87 | 17.09 | differs |
| 5|2025-06-01 | oasis | approval_rate_pct | 84.13 | 82.91 | differs |
| 5|2025-06-01 | oasis | total_orders | 9131 | 13393 | differs |
| 5|2025-06-01 | oasis | approved_orders | 6898 | 7376 | differs |
| 5|2025-06-01 | oasis | approved_not_done | 1626 | 1945 | differs |
| 5|2025-06-01 | oasis | approved_not_done_pct | 17.81 | 14.52 | differs |
| 5|2025-06-01 | oasis | avg_tat_minutes | 32.1 | 73.2 | differs |
| 6|2025-10-01 | oasis | not_submitted_claims | 28967.12 | 6860.28 | differs |
| 6|2025-10-01 | oasis | approved_amount | 9388807.1399999 | 7936905.88999995 | differs |
| 6|2025-10-01 | oasis | rejections | 437062.759999999 | 1866942.82000001 | differs |
| 6|2025-10-01 | oasis | rejection_rate_pct | 4.45 | 19.04 | differs |
| 6|2025-10-01 | oasis | approval_rate_pct | 95.55 | 80.96 | differs |
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
| 6|2025-09-01 | oasis | approved_amount | 9245407.72999987 | 7659806.60999987 | differs |
| 6|2025-09-01 | oasis | rejections | 219910.61 | 1804313.33 | differs |
| 6|2025-09-01 | oasis | rejection_rate_pct | 2.32 | 19.06 | differs |
| 6|2025-09-01 | oasis | approval_rate_pct | 97.68 | 80.94 | differs |
| 6|2025-09-01 | oasis | total_orders | 3502 | 5165 | differs |
| 6|2025-09-01 | oasis | approved_orders | 2716 | 2743 | differs |
| 6|2025-09-01 | oasis | approved_not_done | 890 | 1013 | differs |
| 6|2025-09-01 | oasis | approved_not_done_pct | 25.41 | 19.61 | differs |
| 6|2025-09-01 | oasis | avg_tat_minutes | 49 | 106.9 | differs |
| 6|2026-09-01 | oasis | not_submitted_claims | 1024721.27 | 3342087.50000001 | differs |
| 6|2026-09-01 | oasis | approved_amount | 3373235.46 | 0 | differs |
| 6|2026-09-01 | oasis | approval_rate_pct | 100 | 0 | differs |
| 6|2026-09-01 | oasis | total_orders | 5291 | 10139 | differs |
| 6|2026-09-01 | oasis | approved_orders | 3724 | 3694 | differs |
| 6|2026-09-01 | oasis | approved_not_done | 994 | 1084 | differs |
| 6|2026-09-01 | oasis | approved_not_done_pct | 18.79 | 10.69 | differs |
| 6|2026-09-01 | oasis | avg_tat_minutes | 37.7 | 70.8 | differs |
| 1|2025-07-01 | oasis | total_submitted_claims | 14411909.0200001 | 14696414.1199998 | differs |
| 1|2025-07-01 | oasis | not_submitted_claims | 56092.62 | 82359.5599999999 | differs |
| 1|2025-07-01 | oasis | approved_amount | 12613102.3599998 | 12451114.7499996 | differs |
| 1|2025-07-01 | oasis | rejections | 1798807.88 | 2068589.36999999 | differs |
| 1|2025-07-01 | oasis | rejection_rate_pct | 12.48 | 14.25 | differs |
| 1|2025-07-01 | oasis | approval_rate_pct | 87.52 | 85.75 | differs |
| 1|2025-07-01 | oasis | total_orders | 16794 | 27826 | differs |
| 1|2025-07-01 | oasis | approved_orders | 12687 | 14690 | differs |
| 1|2025-07-01 | oasis | approved_not_done | 3019 | 3881 | differs |
| 1|2025-07-01 | oasis | approved_not_done_pct | 17.98 | 13.95 | differs |
| 1|2025-07-01 | oasis | avg_tat_minutes | 42.6 | 68 | differs |
| 2|2025-01-01 | oasis | not_submitted_claims | 50772.11 | 37575.02 | differs |
| 2|2025-01-01 | oasis | total_orders | 17524 | 30107 | differs |
| 2|2025-01-01 | oasis | approved_orders | 12869 | 14031 | differs |
| 2|2025-01-01 | oasis | approved_not_done | 3006 | 3408 | differs |
| 2|2025-01-01 | oasis | approved_not_done_pct | 17.15 | 11.32 | differs |
| 2|2025-01-01 | oasis | avg_tat_minutes | 29.4 | 66.7 | differs |
| 1|2025-05-01 | oasis | total_submitted_claims | 15053524.2500005 | 15579635.5300008 | differs |
| 1|2025-05-01 | oasis | not_submitted_claims | 268355.33 | 294693.640000001 | differs |
| 1|2025-05-01 | oasis | approved_amount | 13359950.0600002 | 12976818.1000006 | differs |
| 1|2025-05-01 | oasis | rejections | 1693574.35000001 | 2059059.95000001 | differs |
| 1|2025-05-01 | oasis | rejection_rate_pct | 11.25 | 13.69 | differs |
| 1|2025-05-01 | oasis | approval_rate_pct | 88.75 | 86.31 | differs |
| 1|2025-05-01 | oasis | total_orders | 16882 | 27576 | differs |
| 1|2025-05-01 | oasis | approved_orders | 12635 | 14786 | differs |
| 1|2025-05-01 | oasis | approved_not_done | 2998 | 3802 | differs |
| 1|2025-05-01 | oasis | approved_not_done_pct | 17.76 | 13.79 | differs |
| 1|2025-05-01 | oasis | avg_tat_minutes | 36.5 | 57.9 | differs |
| 1|2025-06-01 | oasis | total_submitted_claims | 13407745.4 | 13677873.4799998 | differs |
| 1|2025-06-01 | oasis | not_submitted_claims | 13079.13 | 265698.07 | differs |
| 1|2025-06-01 | oasis | approved_amount | 11726232.3599999 | 11608385.0299997 | differs |
| 1|2025-06-01 | oasis | rejections | 1681513.2 | 1788466.13000001 | differs |
| 1|2025-06-01 | oasis | rejection_rate_pct | 12.54 | 13.35 | differs |
| 1|2025-06-01 | oasis | approval_rate_pct | 87.46 | 86.65 | differs |
| 1|2025-06-01 | oasis | total_orders | 15540 | 24788 | differs |
| 1|2025-06-01 | oasis | approved_orders | 11655 | 13820 | differs |
| 1|2025-06-01 | oasis | approved_not_done | 2955 | 3704 | differs |
| 1|2025-06-01 | oasis | approved_not_done_pct | 19.02 | 14.94 | differs |
| 1|2025-06-01 | oasis | avg_tat_minutes | 34.3 | 52.9 | differs |
| 4|2025-12-01 | oasis | total_submitted_claims | 17850224.6200004 | 18112267.3599996 | differs |
| 4|2025-12-01 | oasis | not_submitted_claims | 37687.45 | 304147.63 | differs |
| 4|2025-12-01 | oasis | approved_amount | 15834265.1799994 | 15744626.649999 | differs |
| 4|2025-12-01 | oasis | rejection_rate_pct | 11.29 | 11.36 | differs |
| 4|2025-12-01 | oasis | total_orders | 19435 | 28742 | differs |
| 4|2025-12-01 | oasis | approved_orders | 14015 | 14908 | differs |
| 4|2025-12-01 | oasis | approved_not_done | 2619 | 3379 | differs |
| 4|2025-12-01 | oasis | approved_not_done_pct | 13.48 | 11.76 | differs |
| 4|2025-12-01 | oasis | avg_tat_minutes | 27.1 | 41.4 | differs |
| 3|2025-03-01 | oasis | total_submitted_claims | 17732864.4500004 | 7181519.06000009 | differs |
| 3|2025-03-01 | oasis | not_submitted_claims | 11677417.3200002 | 1124753.89 | differs |
| 3|2025-03-01 | oasis | approved_amount | 15889611.9700003 | 4145155.69000002 | differs |
| 3|2025-03-01 | oasis | rejections | 1843252.91000001 | 1895095.51 | differs |
| 3|2025-03-01 | oasis | rejection_rate_pct | 10.39 | 31.37 | differs |
| 3|2025-03-01 | oasis | approval_rate_pct | 89.61 | 68.63 | differs |
| 3|2025-03-01 | oasis | total_orders | 11498 | 15373 | differs |
| 3|2025-03-01 | oasis | approved_orders | 8617 | 8389 | differs |
| 3|2025-03-01 | oasis | approved_not_done | 1690 | 2085 | differs |
| 3|2025-03-01 | oasis | approved_not_done_pct | 14.7 | 13.56 | differs |
| 3|2025-03-01 | oasis | avg_tat_minutes | 29.7 | 58.8 | differs |
| 3|2026-08-01 | oasis | total_submitted_claims | 34533461.6600026 | 35120773.7700039 | differs |
| 3|2026-08-01 | oasis | not_submitted_claims | 587.77 | 695135.29 | differs |
| 3|2026-08-01 | oasis | approved_amount | 27897998.6000007 | 27581561.2400008 | differs |
| 3|2026-08-01 | oasis | rejections | 6635464.11999959 | 6705372.2799994 | differs |
| 3|2026-08-01 | oasis | rejection_rate_pct | 19.21 | 19.56 | differs |
| 3|2026-08-01 | oasis | total_orders | 17499 | 28113 | differs |
| 3|2026-08-01 | oasis | approved_orders | 13833 | 14384 | differs |
| 3|2026-08-01 | oasis | approved_not_done | 2322 | 2909 | differs |
| 3|2026-08-01 | oasis | approved_not_done_pct | 13.27 | 10.35 | differs |
| 3|2026-08-01 | oasis | avg_tat_minutes | 32.5 | 58.5 | differs |
| 4|2025-08-01 | oasis | total_submitted_claims | 13159436.9699999 | 13805359.7999996 | differs |
| 4|2025-08-01 | oasis | not_submitted_claims | 3458.26 | 696314.939999999 | differs |
| 4|2025-08-01 | oasis | approved_amount | 12078085.8399998 | 11603419.1599997 | differs |
| 4|2025-08-01 | oasis | rejections | 1081351.37 | 1494508.41 | differs |
| 4|2025-08-01 | oasis | rejection_rate_pct | 8.22 | 11.41 | differs |
| 4|2025-08-01 | oasis | approval_rate_pct | 91.78 | 88.59 | differs |
| 4|2025-08-01 | oasis | total_orders | 15247 | 21228 | differs |
| 4|2025-08-01 | oasis | approved_orders | 10143 | 10294 | differs |
| 4|2025-08-01 | oasis | approved_not_done | 2308 | 2388 | differs |
| 4|2025-08-01 | oasis | approved_not_done_pct | 15.14 | 11.25 | differs |
| 4|2025-08-01 | oasis | avg_tat_minutes | 26.6 | 47.9 | differs |
| 1|2025-10-01 | oasis | total_submitted_claims | 17560139.7099999 | 17859306.8499994 | differs |
| 1|2025-10-01 | oasis | not_submitted_claims | 24594.04 | 178754.53 | differs |
| 1|2025-10-01 | oasis | approved_amount | 15769118.8399999 | 15313794.2999992 | differs |
| 1|2025-10-01 | oasis | rejections | 1842719.97 | 2324109.17999995 | differs |
| 1|2025-10-01 | oasis | rejection_rate_pct | 10.49 | 13.18 | differs |
| 1|2025-10-01 | oasis | approval_rate_pct | 89.8 | 86.82 | differs |
| 1|2025-10-01 | oasis | total_orders | 18737 | 33222 | differs |
| 1|2025-10-01 | oasis | approved_orders | 14439 | 17153 | differs |
| 1|2025-10-01 | oasis | approved_not_done | 3811 | 4756 | differs |
| 1|2025-10-01 | oasis | approved_not_done_pct | 20.34 | 14.32 | differs |
| 1|2025-10-01 | oasis | avg_tat_minutes | 36 | 49.8 | differs |
| 1|2025-09-01 | oasis | total_submitted_claims | 14911107.4899993 | 15452252.9499998 | differs |
| 1|2025-09-01 | oasis | not_submitted_claims | 57196.26 | 573406.260000001 | differs |
| 1|2025-09-01 | oasis | approved_amount | 13129438.2099994 | 12787351.6099998 | differs |
| 1|2025-09-01 | oasis | rejections | 1801132.76000001 | 2065121.99000001 | differs |
| 1|2025-09-01 | oasis | rejection_rate_pct | 12.08 | 13.9 | differs |
| 1|2025-09-01 | oasis | approval_rate_pct | 88.05 | 86.1 | differs |
| 1|2025-09-01 | oasis | total_orders | 17204 | 28944 | differs |
| 1|2025-09-01 | oasis | approved_orders | 13271 | 15801 | differs |
| 1|2025-09-01 | oasis | approved_not_done | 3419 | 3916 | differs |
| 1|2025-09-01 | oasis | approved_not_done_pct | 19.87 | 13.53 | differs |
| 1|2025-09-01 | oasis | avg_tat_minutes | 40.4 | 53.6 | differs |
| 1|2026-09-01 | oasis | total_submitted_claims | 12800428.7499996 | 12974066.6799991 | differs |
| 1|2026-09-01 | oasis | not_submitted_claims | 1136060.59 | 12129553.2299991 | differs |
| 1|2026-09-01 | oasis | approved_amount | 12743815.5799996 | 266356.780000001 | differs |
| 1|2026-09-01 | oasis | rejection_rate_pct | 0.44 | 17.57 | differs |
| 1|2026-09-01 | oasis | approval_rate_pct | 99.56 | 82.43 | differs |
| 1|2026-09-01 | oasis | total_orders | 26255 | 39739 | differs |
| 1|2026-09-01 | oasis | approved_orders | 19055 | 22083 | differs |
| 1|2026-09-01 | oasis | approved_not_done | 3798 | 5181 | differs |
| 1|2026-09-01 | oasis | approved_not_done_pct | 14.47 | 13.04 | differs |
| 1|2026-09-01 | oasis | avg_tat_minutes | 35.8 | 50.2 | differs |
| 6|2025-07-01 | oasis | not_submitted_claims | 280 | 16700.34 | differs |
| 6|2025-07-01 | oasis | total_orders | 3017 | 4518 | differs |
| 6|2025-07-01 | oasis | approved_orders | 2289 | 2090 | differs |
| 6|2025-07-01 | oasis | approved_not_done | 615 | 772 | differs |
| 6|2025-07-01 | oasis | approved_not_done_pct | 20.38 | 17.09 | differs |
| 6|2025-07-01 | oasis | avg_tat_minutes | 51.5 | 110.6 | differs |
| 6|2025-05-01 | oasis | not_submitted_claims | 309.31 | 891.62 | differs |
| 6|2025-05-01 | oasis | total_orders | 1807 | 2240 | differs |
| 6|2025-05-01 | oasis | approved_orders | 1504 | 1156 | differs |
| 6|2025-05-01 | oasis | approved_not_done | 333 | 331 | differs |
| 6|2025-05-01 | oasis | approved_not_done_pct | 18.43 | 14.78 | differs |
| 6|2025-05-01 | oasis | avg_tat_minutes | 80.9 | 142.1 | differs |
| 5|2025-01-01 | oasis | total_submitted_claims | 6078477.63000003 | 6253507.56999992 | differs |
| 5|2025-01-01 | oasis | not_submitted_claims | 548496.04 | 335407.77 | differs |
| 5|2025-01-01 | oasis | approved_amount | 4576746.71000003 | 4066478.09999998 | differs |
| 5|2025-01-01 | oasis | rejections | 1501731.01000001 | 1514047.47000002 | differs |
| 5|2025-01-01 | oasis | rejection_rate_pct | 24.71 | 27.13 | differs |
| 5|2025-01-01 | oasis | approval_rate_pct | 75.29 | 72.87 | differs |
| 5|2025-01-01 | oasis | total_orders | 11014 | 17108 | differs |
| 5|2025-01-01 | oasis | approved_orders | 8765 | 8857 | differs |
| 5|2025-01-01 | oasis | approved_not_done | 2328 | 2573 | differs |
| 5|2025-01-01 | oasis | approved_not_done_pct | 21.14 | 15.04 | differs |
| 5|2025-01-01 | oasis | avg_tat_minutes | 35.7 | 57.4 | differs |
| 3|2025-12-01 | oasis | total_submitted_claims | 27804646.9500017 | 28124480.0500015 | differs |
| 3|2025-12-01 | oasis | not_submitted_claims | 2801.75 | 415955.35 | differs |
| 3|2025-12-01 | oasis | approved_amount | 25209346.2400004 | 24837681.9000003 | differs |
| 3|2025-12-01 | oasis | rejections | 2854401.69999998 | 2941247.43999992 | differs |
| 3|2025-12-01 | oasis | rejection_rate_pct | 10.27 | 10.59 | differs |
| 3|2025-12-01 | oasis | approval_rate_pct | 90.67 | 89.41 | differs |
| 3|2025-12-01 | oasis | total_orders | 14967 | 23051 | differs |
| 3|2025-12-01 | oasis | approved_orders | 12252 | 12794 | differs |
| 3|2025-12-01 | oasis | approved_not_done | 2189 | 2514 | differs |
| 3|2025-12-01 | oasis | approved_not_done_pct | 14.63 | 10.91 | differs |
| 3|2025-12-01 | oasis | avg_tat_minutes | 36.8 | 57.7 | differs |
| 6|2025-06-01 | oasis | total_submitted_claims | 8672530.50999988 | 8886884.51999986 | differs |
| 6|2025-06-01 | oasis | not_submitted_claims | 360.58 | 213461.46 | differs |
| 6|2025-06-01 | oasis | rejections | 754213.550000001 | 784126.13 | differs |
| 6|2025-06-01 | oasis | rejection_rate_pct | 8.7 | 9.04 | differs |
| 6|2025-06-01 | oasis | total_orders | 2175 | 3327 | differs |
| 6|2025-06-01 | oasis | approved_orders | 1721 | 1468 | differs |
| ... | | 662 more | | | |

## vw_work_force

Keys (branch_id, period): old 112, new 112. Differences: 314.

| Key | Source | Column | Old | New | Status |
|---|---|---|---|---|---|
| 4|2026-08-01 | both | headcount | 623 | 631 | differs |
| 4|2026-08-01 | both | medical_headcount | 424 | 432 | differs |
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
| 3|2026-09-01 | both | medical_headcount | 500 | 525 | differs |
| 3|2026-09-01 | both | doctors_headcount | 159 | 156 | differs |
| 3|2026-09-01 | both | pt_doctors_headcount | 59 | 69 | differs |
| 3|2026-09-01 | both | FTE | 728.5 | 721.5 | differs |
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
| 6|2026-09-01 | both | doctors_headcount | 151 | 159 | differs |
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
| 8|2026-08-01 | both | doctors_headcount | 37 | 83 | differs |
| 8|2026-08-01 | both | pt_doctors_headcount | 37 | 8 | differs |
| 8|2026-08-01 | both | FTE | 19.5 | 142 | differs |
| 4|2026-09-01 | both | medical_headcount | 412 | 427 | differs |
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
| ... | | 114 more | | | |

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
