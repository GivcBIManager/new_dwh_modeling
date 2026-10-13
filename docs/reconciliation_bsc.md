# bsc views: reconciliation against the old server

Spec: `docs/superpowers/specs/2026-10-12-hnh-bsc-views-design.md`, section 9.3.

**How it was compared:**
- Run on 2026-10-12 with `scripts/compare_bsc.ps1`. It reads the old server (`chDWH`, 172.22.25.165) and the new one (`HNH_Gold`, 172.22.25.214), read-only.
- Period: August and September 2026, and the whole of 2025.
- The raw differences are in `docs/reconciliation_bsc_differences.md`. That file lists up to 200 rows per view; a difference means above 0.5% relative, or above 1 in absolute terms when the value is below 1.
- This document ties every difference group to its cause: a Section 1 item from the design review (numbered 1–24 in the spec's decisions) or a spec finding (F1–F13).

**Build checked on 2026-10-12:**
- 12 objects, 192 columns.
- Every column's name, type and position equal the old server's (`system.columns` compared with the contracts).
- Reference tables loaded: `map_gl_cutover` 7, `map_budget_line_item` 48, `bsc_targets` 3,024, `bsc_patient_satisfaction` 56. The sum of `target_value` equals the old server's to the last digit: 13,473,711,017.999613628.

## Result

| View | Keys old / new | Outcome |
|---|---|---|
| `vw_income_statement_budget` | 576 / 576 | Identical |
| `vw_date_dim` | 426 / 426 | Identical |
| `targets` | 2,916 / 2,916 | Identical |
| `patient_satisfaction` | 56 / 56 | Identical |
| `vw_hospital` | 8 / 8 | Khamis's city is `Aseer` (old `Asser`), as decided (spec 7.1) |
| `vw_gl_transactions` | 7,032 / 8,581 | 2025 (Oasis only): every branch × month × element equal to the cent. Other differences explained below. |
| `vw_gl_openning_balance` | 2,690 / 8,581 | Explained (F7, spec 6.1) |
| `vw_financial` | 85 / 88 | Explained. Khamis's balance sheet from September 2026 is O-B10. |
| `vw_customer` | 89 / 112 | Explained (corrected definitions, B3) |
| `vw_hospital_beds_utilization` | 88 / 88 | Explained (Section 1 items 9, 10; spec 7.3) |
| `vw_rcm` | 88 / 88 | Explained (Section 1 items 11–15) |
| `vw_work_force` | 112 / 112 | Explained after one fix (below) |

One defect was found and fixed (commit `adbeefe`): Abha's 2025 resignations were 0.
- Cause: Abha takes leavers from Fusion, which has none before 2026.
- Fix: Fusion leavers now count only from the Fusion HR start (2026-01); Oasis termination is used before it for every branch.
- After the fix, 2025 resignations equal the old view for every branch: 51, 24, 9, 23, 36, 11, 0, 0.
- **The view must be rebuilt on the receiving server for this to take effect** (`dbt build --select bsc_vw_work_force`).

No unexplained difference remains.

## Finance views

### `vw_gl_transactions`

**2025 (all branches on Oasis).** Summed per branch × month × FS element, all 424 keys that exist on both sides are equal to the cent. The new view has 76 extra keys:
- 75 carry 0 movement: opening-only rows, such as equity and ECL elements.
- 1 carries 188,833 SAR (Abha, December 2025). It sits under an unmapped element in the old view and a mapped element in the new one: same money, newer `map_oasis_fs_account`.

**Row-level differences:**

| Group | Cause |
|---|---|
| `OpeningBalance` on income-statement rows (e.g. Alrabwah 2025-07 G&A: old 0, new 1,845,138) | The old opening summed only GL periods still open (`GL_STATUS = 'O'`). All of 2025 is closed, so 2025 income-statement openings were 0. The new view rolls the fiscal year to date (F7, spec 5.2). |
| Keys only in the old view (66 listed) | FS text: the old view kept padded and double-spaced labels (e.g. `inma supervising expenses `, `prepaid  maintenance`) that `dim_oasis_gl_account` normalises. Also zero-only rows the new fact does not keep, and Oasis postings after a branch's cutover month (e.g. Khamis, September 2026), which now come from Fusion (B5). |
| Fusion months | Fusion vocabulary (revenue by payer, `depreciation and amortization`, `charges from head office`, `not mapped`; F5) and Fusion amounts from each branch's cutover month. |

### `vw_gl_openning_balance`
- The old view covered only open GL periods and accumulated `forwarded_balance` over them. The new view covers every month from 2022.
- `forwarded_balance` is now the month's brought-forward (Oasis) or go-live (Fusion) amount, not a running total. `OpeningBalance + forwarded_balance` keeps the old meaning (spec 6.1).

### `vw_financial`

| Group | Example | Cause |
|---|---|---|
| `assets`, `account_receivable_actual` and their openings | Alrabwah, September 2026: assets 330.7M → 550.9M, receivables 161.2M. Abha, November 2025: receivables 10.0M → 80.9M. | Same open-period opening as above (F7). Recomputed from the old server's raw `tr_gl_distribution` (all posted lines of the year up to the month, brought-forward included): 550.863M, 161.151M and 80.948M, equal to the new view. The old values were understated. |
| `operating_expenses`, `ebitda_actual` | 2025: Alrabwah 220.594M → 220.040M, Jazan 177.523M → 174.851M, Abha 96.747M → 96.148M; other branches equal | Depreciation the old filter missed (`'depreciation On Rou'` against lower-case text, `'deprecition'`; F6). |
| `consumables_actual`, `consumables_budget` | 2025: equal to the old view (medical consumables only) | Changed 2026-10-13: cost of goods sold is not consumables (O-B6 closed). The budget now takes the Consumables line only; the old view also added Cost Of Medicines. Fusion months show 0 actuals until finance maps a consumables account (O-P3-8). The comparison of 2026-10-12 predates this change. |
| `net_revenue_actual` | 2025: equal for every branch (Alrabwah 297.355M, Khamis 314.742M, Jazan 297.426M, Unaizah 184.769M, Madinah 179.102M, Abha 111.140M) | — |
| Revenue after cutover | Unaizah, September 2026: old 2.91M, new 0 | From its cutover month a branch takes Fusion only. The old figure was Oasis-feed revenue (B5). Fusion holds almost nothing for September 2026 yet: its last load was 2026-09-30 (O-B9). |
| Extra months | Budget-only months (October–December 2026) | The old view dropped them (`ANY LEFT JOIN`, spec 6.3). |

**Balance sheet across each branch's cutover** (`vw_financial`, M SAR; spec 5.2, O-B10):

| Branch | Month before | Assets | Receivables | Cutover month | Assets | Receivables |
|---|---|---|---|---|---|---|
| 2 Khamis | 2026-08 | 898.9 | 185.7 | 2026-09 | **1,741.0** | **317.3** |
| 3 Jazan | 2026-06 | 661.9 | 242.1 | 2026-07 | 688.2 | 293.6 |
| 4 Unaizah | 2026-07 | 284.1 | 128.4 | 2026-08 | 301.8 | 168.1 |
| 5 Madinah | 2026-08 | 145.1 | 100.3 | 2026-09 | 147.1 | 146.4 |
| 6 Abha | 2026-04 | 103.5 | 114.7 | 2026-05 | 103.0 | 123.9 |

- Khamis has two near-identical Fusion opening batches for August 2026 (O-B10), so its balance sheet is doubled from September.
- Receivables step up at every cutover: Jazan +51M, Unaizah +40M, Madinah +46M, Abha +9M. Finance should review them with O-B10.
- Ghirnata and Muhayil have no Oasis GL before their cutover.

## `vw_customer`

| Group | Example (August 2026) | Cause |
|---|---|---|
| Keys 89 → 112 | Ghirnata and Muhayil 2025 | The new view lists every branch × month (zeros where there is no activity); the old one listed months with data. |
| `revenue` and splits | Within 0.5% (Alrabwah 29.12M against 29.04M) | SSAS `Revenue` (item 1). |
| `insurance_revenue`, `non_moh_revenue`, `credit_revenue` | Unaizah insurance 7.32M → 7.47M | Episode payer, as before, on corrected charge lines (item 2). |
| `admissions`, `discharges` and the admission counts | Jazan 1,163 → 1,349; Muhayil 32 → 46 | Countable-admission rule (B3). |
| `alos_non_ltc` | Unaizah 2.72 → 2.64 | LTC fixed at discharge (B3). |
| `readmission_within_30days`, `icu_discharge` | ±1–2 | Corrected readmission and critical-bed rules (B3, item 6). |
| `available_slots` | +6% to +23% (Alrabwah 30,256 → 32,080; Abha 20,144 → 23,768) | `legacy_capacity_slots` counts a doctor-day per department, so a doctor in two clinics on one day counts twice (item 3, O-B3). |
| `op_episodes` | Unaizah 10,063 → 9,866 | True OP episodes (item 4). |
| `er_census`, `op_waiting_time_in_minutes`, `referrals_revenue` | Within 1–3% | Cancellation outcome group, guarded wait minutes, episode referral policy (B3, items 7, 8). |

## `vw_hospital_beds_utilization`

| Group | Example (Jazan, June 2025) | Cause |
|---|---|---|
| `alos`, `ltc_alos` | 32.3 → 2.8; 320.5 → 61.0 | The old view averaged the to-date stay of every stay open in the month; the new one averages the month's discharges (SSAS ALOS; item 10). |
| `census` | 1,060 → 1,207 | Countable stays (B3). |
| `available_beds`, `available_bed_nights` | 235 → 244 | The month's average available inpatient beds, not today's count repeated (item 9). |
| `total_bed_nights`, `occupancy_rate` | 4,216 → 3,847; 0.598 → 0.526 | Daily bed occupancy of inpatient, non-excluded wards (SSAS Bed Occupancy %), not stay overlap (spec 7.3). |

## `vw_rcm`

| Group | Example (Madinah, June 2025) | Cause |
|---|---|---|
| `total_submitted_claims` | 13.01M → 13.28M | Latest submission, cancelled claims excluded (item 11). |
| `not_submitted_claims` | 0.26M → 0.35M | Now the amount pending adjudication (item 12, F9). |
| `approved_amount`, `rejections`, rates | Approval 84.1% → 74.0% | Outcome-aware amounts; rates over adjudicated submitted (item 13). |
| `total_orders`, `approved_orders`, `approved_not_done` | 9,131 → 13,393 | Pre-authorisation services including unsent, error and pended lines, payer advances excluded (item 14). |
| `avg_tat_minutes` | 32.1 → 73.2 | Sent to final response, capped at 1,440 minutes; the old view capped at 480 (item 15). |

## `vw_work_force`

| Group | Example | Cause |
|---|---|---|
| `headcount`, `FTE`, `medical_headcount`, `doctors_headcount` | Unaizah, August 2026: 623 → 631 | Fusion month-end headcount from 2026, paid headcount before (item 16). |
| `pt_doctors_headcount` | Unaizah, August 2026: 48 → 17 | Doctors in the Fusion headcount are no longer counted as revenue-only (item 16). |
| `resignations` 2026 | Ghirnata, August 2026: 11 → 12; Abha, September 2026: 0 → 2 | Fusion voluntary leavers for branches 6–8 from 2026 (item 17, F10). |
| `resignations` 2025, Abha | 11 → 0 for the year | **Defect, fixed in `adbeefe`** (see Result). |

## Before repointing the report

1. Rebuild `bsc_vw_work_force` on the receiving server (resignation fix).
2. The first build of 2026-10-12 16:33 logged one failed node (`gold.etl_run_log`: 13 built, 1 failed). The rerun of `fact_gl_fs_monthly+` at 16:34 succeeded. Confirm which node failed. If it was a unit test or a data test, re-run `dbt build --select tag:hnh_bsc fact_gl_fs_monthly` and check that all tests pass.
3. Create the scorecard's ClickHouse login and grant it `SELECT` on `bsc.*` (O-B2).
4. Finance: O-B10 (Khamis opening batches; receivables at the cutovers), O-B5 (Jazan and Unaizah cutover months).
