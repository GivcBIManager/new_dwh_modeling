# Moving the hnh models into the receiving dbt project

Receiving project: GitHub `GivcBIManager/dlt`, folder `dbt/` (dbt project `oasis`, profile `oasis`, `dbt-clickhouse>=1.9,<1.10`), deployed on the Ubuntu server where ClickHouse runs (`host: localhost`).

Checked on 2026-10-01 against a copy of the server's `dbt/` folder: the integrated project parses, all `hnh` models resolve their Oasis inputs to the `oasis_lake` models, and `dbt build --select tag:hnh` completes from the integrated project (see "Deployment checklist").

## What to copy

| From this repository | To `dbt/` |
|---|---|
| `hnh_dwh/models/hnh/` | `models/hnh/` |
| `hnh_dwh/macros/hnh/` | `macros/hnh/` |
| `hnh_dwh/tests/hnh/` | `tests/hnh/` |

Do not copy our `generate_schema_name.sql`: `dbt/macros/generate_schema_name.sql` is already identical, so `+schema: stg|int|gold` lands in the databases `stg`, `int` and `gold`. There are no packages and no seeds.

## Add to `dbt/dbt_project.yml`

```yaml
vars:
  hnh_oasis_as_ref: true                 # staging reads the oasis_lake models via ref(), so dbt orders the DAG
  hnh_oasis_source_only: []               # every Oasis table used has an oasis_lake model on the server
  hnh_history_start_date: "2022-01-01"
  hnh_ssas_machine_name: "SSAS-SERVER"   # machine name of the SSAS server

models:
  oasis:
    hnh:                                 # new block, next to fusion: and oasis_lake:
      +tags: ["hnh"]
      staging:
        +schema: stg
        +materialized: view
        +tags: ["hnh_stg"]
      intermediate:
        +schema: int
        +materialized: table
        +tags: ["hnh_int"]
      marts:
        +schema: gold
        +materialized: table
        +tags: ["hnh_gold"]

data_tests:                              # top level; makes --select tag:hnh run the singular tests too
  oasis:
    hnh:
      +tags: ["hnh"]
```

Merge into the existing keys: `vars:` already holds `iceberg_root` — keep it and add the four `hnh_` vars under it; put the `hnh:` block under `models: oasis:` next to `fusion:` and `oasis_lake:`. The server project has no `data_tests:` or `on-run-end:` key yet, so add those at top level. The project default is `+materialized: table`; the `hnh` block overrides it for staging (views).

## How the models read Oasis

With `hnh_oasis_as_ref: true`, staging models call `ref('<raw_table>')` on the `oasis_lake` incremental models (`appointments`, `codes_data`, ...; the names match the raw tables), so dbt knows the `hnh` models depend on them. `dbt build --select tag:hnh` builds only the `hnh` models and reads the `oasis_lake` tables as they are; it never rebuilds them. (`--select +tag:hnh` would also build the `oasis_lake` models first; `tag:hnh+` means `hnh` and everything downstream of it.) With `false` the staging models use `source('oasis', ...)` instead. Var `hnh_oasis_source_only` lists tables to read with `source('oasis', ...)` even when `hnh_oasis_as_ref` is true; it is empty on the server because `operating_diary_slots` and `operating_slot_details` now have `oasis_lake` models (the GitHub copy of the repo does not have them yet — if you deploy from a revision without those two models, set the var to `['operating_diary_slots', 'operating_slot_details']`). `api_pull_response_details` was ingested on 2026-10-05. If the server's `oasis_lake` project has no model of that name, add `'api_pull_response_details'` to `hnh_oasis_source_only` so staging reads it with `source()`; `claim_visit_detail` and `claim_service_detail` already have `oasis_lake` models. The `hnh` YAML declares a source named `oasis` and one named `reference`; the project's own sources are `oasis_lake` and `ofusion_conformed`, so there is no clash.

## Aliased models

`hnh_dim_branch` and `hnh_dim_department` are built into `gold.dim_branch` and `gold.dim_department` (`alias`). The model names carry the `hnh_` prefix because `dim_branch` and `dim_department` already exist in `models/fusion/staging/conformed/`; dbt model names must be unique per project. Always `ref('hnh_dim_branch')` / `ref('hnh_dim_department')` in dbt code.

## Reference tables that must exist in `default`

Loaded once by `scripts/load_reference_data.py` and `scripts/load_hijri_calendar.py` (outside dbt): `branch_dict_source`, `map_purchasers`, `map_referral_policies`, `budget_data`, `bi_users`, `map_unified_department_v2`, `map_bed_classification`, `map_ward_tower`, `map_clinic_duration`, `map_clinic_count`, `map_home_care_entity`, `map_termination_reason`, `map_product_category`, `map_claim_status`, `map_nphies_reason`, `map_hijri_calendar`, `map_public_holiday`. Re-run `load_hijri_calendar.py` once a year to extend the calendar.

## Security table and dim_date

`gold.sec_user_access.login_name` is `<SSAS machine>\<user name>`. The source `UserName` already has an old domain prefix (for example `HNHRIYADH\name` or `INMA-BINTELLIGE\name`) in mixed case. The model keeps the part after the last backslash, lower-cased, as `user_name`, and puts the SSAS machine name in front of it. The original text is kept in `source_user_name`. The DAX comparison against `USERNAME()` must be case-insensitive (DAX `=` on text is case-insensitive). Administrators get every real branch (never branch 0) and keep the specialty of their own source rows.

`dim_date` offset columns: a positive value means the date is in the past (for example a day offset of 1 is yesterday).

## Run log

Add this to the receiving `dbt_project.yml` so every run appends a row to `gold.etl_run_log`. The hook fires on every `dbt run`/`build` in the project, including Fusion and `oasis_lake` runs (it creates `gold` if needed); those rows have their own `selected` text and do not affect the gate. SSAS processing should start only when the latest `etl_run_log` row whose `selected = 'tag:hnh'` has `status = 'success'` (`selected` records the `--select` text exactly, backslashes and quotes removed; `status` is `success` only when no node failed).

```yaml
on-run-end:
  - "{{ hnh_log_run(results) }}"
```

## Notes for the SSAS model

- Do not relate the facts to each other on `encounter_key` or `episode_key`. Their windows differ (facts start at 2022-01-01, intermediate look-backs do not), and admissions open from before 2022 have no matching rows elsewhere.
- Visit and patient KPIs filter `encounter_type in ('OP', 'ER')`; `IP` rows in `fact_encounter` are admissions, not visits.
- Occupancy uses inpatient wards only (`is_inpatient_ward = 1`) and excludes excluded wards (`is_excluded_ward = 0`).
- ER wait is arrival to treatment start (`wait_minutes`); ER length of stay is arrival to completion.
- Admission source maps `EMERGENCY` as well as the department descriptions.
- Run `dbt build --full-refresh --select agg_clinic_capacity_daily` weekly: no-show flips and late dimension members change past days that the incremental load does not revisit.
- `fact_admission` does not yet carry critical-bed timestamps, the admission request reason or the discharging ward (planned).
- `fact_target_daily`: `target_cost_total` and `target_patient_days` are additive; `target_cost_per_episode` and `target_alos` are episode-weighted averages for one row and must not be summed. Compute cost per episode as `SUM(target_cost_total) / SUM(target_episodes)`.
- `fact_charge_line` relates to `dim_payer` twice: `billed_payer_key` (who the line is billed to; co-pay is 8888 Deductible) and `episode_payer_key` (the episode's payer). Revenue is `SUM(revenue_amount)`; never sum `net_amount` for revenue, it includes package components and cancelled rows.
- `fact_charge_line` is rebuilt in full every night (about 3 minutes, 66M rows); it was planned as incremental but an incremental build could not stay equal to a full refresh.
- Pre-authorisation approval and rejection rates restrict both the numerator and the denominator to lines with `has_final_response = 1` (approved: `is_approved = 1 and has_final_response = 1`; rejected: `preauth_outcome = 'Rejected' and has_final_response = 1`; denominator: `has_final_response = 1`; `rec_preauth_monthly.approved_final`, `rejected_final` and `final_responses`). The RCM Authorization report's all-lines denominator is reproduced by `rec_preauth_monthly.legacy_*`.
- `fact_preauth_line.payer_comment` is payer free text and can echo member details; keep it out of general perspectives (treat like dim_patient_pii).
- Claim KPIs filter `fact_claim_line.is_latest_submission = 1` unless the measure is first-pass (`submission_number = 1`). Rejection rate divides `rejected_amount` by `submitted_amount` of lines with `adjudication_status = 'Adjudicated'`.
- Claim KPIs also filter `is_cancelled_claim = 0`: `is_latest_submission` is the last submission whether cancelled or not.
- `fact_claim_payment` is claim-level remittance from NPHIES only; it is not insurer AR (Phase 3).
- `fact_claim_line.invoice_key` and `fact_claim_payment.invoice_key` equal `fact_invoice.invoice_key`; do not relate facts to each other in SSAS, use them for drill-through or SQL.
- Remittance money for advances (no claim link, about 372M SAR) is only in `fact_claim_payment` (`detail_type = 'advance'`); it is not in `rec_claims_monthly`.
- `days_to_payment` is skewed by bulk back-settlements (2025-05 and 2026-04); report medians per month, not averages or per year.

## Deployment checklist (Ubuntu server)

1. Copy `models/hnh/`, `macros/hnh/`, `tests/hnh/` into `dbt/` (commit them to the repo and pull on the server, so line endings and file-name case come from git).
2. Edit `dbt/dbt_project.yml` as above (vars, `hnh:` block, `data_tests:`, `on-run-end:`).
3. Add `use_lw_deletes: true` to the `oasis` output in the server's `profiles.yml`.
4. Check the reference tables listed above exist in `default` on the server's ClickHouse.
5. `cd dbt && dbt parse` — must finish without errors.
6. `dbt build --select tag:hnh` — the first run creates the `stg`, `int` and `gold` objects; expect `ERROR=0` and about a dozen warnings from `warn_*` tests.
7. Add a flow step after the `oasis_lake` loads: `dbt build --select tag:hnh`. Flows that run "all models" with no selector also include the `hnh` models (they run after `oasis_lake`, because of `ref()`), but `dbt run` skips the tests, so keep the `build` step as the one SSAS waits on.

The Python scripts in `scripts/` (`run_dbt.py`, `ch_env.py`, the loaders) belong to the development repository and are not needed on the server.

## Running

```bash
dbt build --select tag:hnh          # all hnh models and tests, in dependency order
dbt build --select tag:hnh_gold+    # marts only
```

Tests named `warn_*` report data gaps and never fail a run. Any other failing test means the SSAS model must not be processed.

## Profile setting

`agg_clinic_capacity_daily` is incremental with the `delete+insert` strategy and needs `use_lw_deletes: true` in the `oasis` profile output. The server's `profiles.yml` does not have it yet.

## Version notes

Developed on dbt-core 1.11.12 and dbt-clickhouse 1.9.8. This repository's YAML uses the `tests:` key with top-level test arguments; the receiving project uses `data_tests:` with `arguments:`. dbt 1.11 accepts both and prints a deprecation warning (`MissingArgumentsPropertyInGenericTestDeprecation`) for the old style; move `columns:` under `arguments:` for `hnh_unique_combination` if you want it quiet. Rule logic is tested through macros with literal inputs (`tests/hnh/assert_hnh_*_macros.sql`).
