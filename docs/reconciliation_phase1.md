# Phase 1 reconciliation

`gold.rec_patient_flow_monthly` holds, per branch and month, each KPI under the new rules beside the value the old warehouse rules give on the same data.

## How to compare with the old warehouse

1. Pick a closed month with the business.
2. On the old server, export that month from `bsc.vw_customer` (`census`, `op_census`, `er_census`, `admissions`, `discharges`, `alos_non_ltc`, `op_waiting_time_in_minutes`) and `bsc.vw_hospital_beds_utilization` (`occupancy_rate`).
3. Compare each exported value with the matching `legacy_*` column:

| Old view column | Compare with |
|---|---|
| `census` | `legacy_census` |
| `op_census` | `legacy_op_census` |
| `er_census` | `legacy_er_census` |
| `admissions` | `legacy_admissions` |
| `discharges` | `legacy_discharges` |
| `alos_non_ltc` | `legacy_alos_non_ltc` |
| `op_waiting_time_in_minutes` | `legacy_wait_minutes_sum` |
| `occupancy_rate` | `legacy_occupancy_rate` (from `legacy_available_bed_nights`) |

4. Acceptance: every legacy value is within 0.5% of the old view. A larger gap means the data differs, not the rule, and must be explained before sign-off.

## Why the new values differ from the legacy values

| KPI | Reason |
|---|---|
| Census, OP visits, ER visits | Cancellation uses the outcome group. The old list (93, 94, 106, 107) missed "rescheduled by hospital" (108) and included 106, which is not an outcome. |
| Admissions, discharges | A stay is excluded when it is closed and shorter than one hour, or its outcome is "Wrong admission". The old rule used one hour or less measured to the current time, and dropped stays whose last bed was in an excluded ward. |
| ALOS | Closed stays only, measured to discharge. LTC is fixed at discharge. |
| Occupancy | New: occupied and available bed nights from the daily bed state, inpatient wards only, excluded wards left out. Legacy: `legacy_available_bed_nights` is today's bed count (`hnh_dim_branch.legacy_current_available_beds`) times (days in the month minus 1), the old view's denominator, which uses today's bed count for every month and loses one night per month. `legacy_occupancy_rate` is occupied bed nights divided by that denominator (null when 0). |
| Waiting time | Reported as average and median. `legacy_wait_minutes_sum` is the old sum of minutes. |

## Known limits

- `episodes` in the reconciliation table counts `fact_episode` rows that have at least one arrived, non-cancelled, non-follow-up OP or ER encounter, grouped by the episode's start month. It is not comparable to a visit-month count.
- Walk-in appointments have no slot start time; their visit time is the arrival time (or the slot date when there is none), so they are counted in the month they happened.
- `prior_encounters_4m` and "returning patients" are understated for January to April 2022, because encounters before 2022 are not in staging.
- `legacy_care_type` and `legacy_purchaser_code` are approximate. The old values were picked arbitrarily by `any()`, so they are excluded from the 0.5% threshold.
- Bed availability before a bed's first recorded row is unknown; the bed is treated as not existing until then.

## Latest closed month at build time

Month: the calendar month before the build date (September 2026, built 2026-10-01).

| branch_key | census | legacy_census | census_diff | admissions | legacy_admissions | admission_diff |
|---|---|---|---|---|---|---|
| 1 | 21922 | 22000 | -78 | 901 | 833 | 68 |
| 2 | 15543 | 15507 | 36 | 964 | 864 | 100 |
| 3 | 16968 | 16944 | 24 | 1239 | 1033 | 206 |
| 4 | 15100 | 15141 | -41 | 844 | 736 | 108 |
| 5 | 11788 | 11793 | -5 | 1047 | 941 | 106 |
| 6 | 5108 | 5104 | 4 | 334 | 303 | 31 |
| 7 | 5466 | 5472 | -6 | 340 | 308 | 32 |
| 8 | 1188 | 1197 | -9 | 72 | 51 | 21 |

| branch_key | alos | legacy_alos | occupancy_pct | legacy_occupancy_pct | available_bed_nights | legacy_available_bed_nights |
|---|---|---|---|---|---|---|
| 1 | 2.31 | 2.32 | 84.0 | 75.7 | 13518 | 14993 |
| 2 | 2.41 | 2.49 | 57.3 | 50.5 | 7851 | 8903 |
| 3 | 2.39 | 2.56 | 74.5 | 60.0 | 7126 | 8845 |
| 4 | 2.31 | 2.35 | 56.6 | 52.4 | 7350 | 7946 |
| 5 | 2.41 | 2.53 | 58.7 | 58.5 | 6031 | 6061 |
| 6 | 3.47 | 3.52 | 33.5 | 30.0 | 6255 | 6989 |
| 7 | 2.08 | 2.04 | 19.7 | 14.3 | 3600 | 4959 |
| 8 | 2.00 | 2.13 | 2.2 | 2.1 | 4770 | 5075 |
