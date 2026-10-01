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

- `prior_encounters_4m` and "returning patients" are understated for January to April 2022, because encounters before 2022 are not in staging.
- `legacy_care_type` and `legacy_purchaser_code` are approximate. The old values were picked arbitrarily by `any()`, so they are excluded from the 0.5% threshold.
- Bed availability before a bed's first recorded row is unknown; the bed is treated as not existing until then.

## Latest closed month at build time

Month: the calendar month before the build date (September 2026, built 2026-10-01).

| branch_key | census | legacy_census | census_diff | admissions | legacy_admissions | admission_diff |
|---|---|---|---|---|---|---|
| 1 | 12192 | 12270 | -78 | 901 | 833 | 68 |
| 2 | 4306 | 4270 | 36 | 964 | 864 | 100 |
| 3 | 6523 | 6499 | 24 | 1239 | 1033 | 206 |
| 4 | 7331 | 7372 | -41 | 844 | 736 | 108 |
| 5 | 3277 | 3282 | -5 | 1047 | 941 | 106 |
| 6 | 2427 | 2423 | 4 | 334 | 303 | 31 |
| 7 | 1578 | 1584 | -6 | 340 | 308 | 32 |
| 8 | 165 | 174 | -9 | 72 | 51 | 21 |

| branch_key | alos | legacy_alos | occupancy_pct | legacy_occupancy_pct |
|---|---|---|---|---|
| 1 | 2.31 | 2.32 | 84.2 | 75.9 |
| 2 | 2.41 | 2.49 | 57.8 | 51.0 |
| 3 | 2.39 | 2.56 | 74.5 | 60.0 |
| 4 | 2.31 | 2.35 | 56.7 | 52.4 |
| 5 | 2.41 | 2.53 | 58.8 | 58.5 |
| 6 | 3.47 | 3.52 | 34.4 | 30.8 |
| 7 | 2.08 | 2.04 | 19.7 | 14.3 |
| 8 | 2.00 | 2.13 | 2.2 | 2.1 |
