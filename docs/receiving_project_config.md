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
  hnh_ssas_machine_name: "HNHANALYTICSSRV"   # machine name of the SSAS server (instance `HNHANALYTICSSRV\REPORTSERVERDB`; the instance is not part of a login)
  hnh_fusion_as_ref: true                # staging reads the project's own Fusion models via ref()
  hnh_head_office_fusion_branch_code: 101
  hnh_head_office_ledger_id: 300000005003375
  hnh_fusion_oasis_feed_source: "300000007046804"   # Fusion journal source id of the Oasis integration
  hnh_hr_snapshot_start: "2026-01-01"    # first month-end of the workforce snapshot facts
  hnh_hr_snapshot_end: ""                # empty = through the current month
  hnh_fusion_inventory_start: "2026-02-01"          # first month of the Fusion inventory integration window
  hnh_fusion_item_master_org_id: 300000005019401    # Fusion item master organisation
  hnh_stock_month_end_last: ""           # empty = the current month-end (not the last closed one); fixed value only for unit tests

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
        ssas:                            # SSAS views, inside marts:
          +materialized: view
          +sql_security: definer
          +definer: CURRENT_USER
          +tags: ["hnh_ssas"]

data_tests:                              # top level; makes --select tag:hnh run the singular tests too
  oasis:
    hnh:
      +tags: ["hnh"]
```

Merge into the existing keys: `vars:` already holds `iceberg_root` — keep it and add the thirteen `hnh_` vars under it; put the `hnh:` block under `models: oasis:` next to `fusion:` and `oasis_lake:`. The server project has no `data_tests:` or `on-run-end:` key yet, so add those at top level. The project default is `+materialized: table`; the `hnh` block overrides it for staging (views).

## How the models read Oasis

With `hnh_oasis_as_ref: true`, staging models call `ref('<raw_table>')` on the `oasis_lake` incremental models (`appointments`, `codes_data`, ...; the names match the raw tables), so dbt knows the `hnh` models depend on them. `dbt build --select tag:hnh` builds only the `hnh` models and reads the `oasis_lake` tables as they are; it never rebuilds them. (`--select +tag:hnh` would also build the `oasis_lake` models first; `tag:hnh+` means `hnh` and everything downstream of it.) With `false` the staging models use `source('oasis', ...)` instead. Var `hnh_oasis_source_only` lists tables to read with `source('oasis', ...)` even when `hnh_oasis_as_ref` is true; it is empty on the server because `operating_diary_slots` and `operating_slot_details` now have `oasis_lake` models (the GitHub copy of the repo does not have them yet — if you deploy from a revision without those two models, set the var to `['operating_diary_slots', 'operating_slot_details']`). `api_pull_response_details` was ingested on 2026-10-05. If the server's `oasis_lake` project has no model of that name, add `'api_pull_response_details'` to `hnh_oasis_source_only` so staging reads it with `source()`; `claim_visit_detail` and `claim_service_detail` already have `oasis_lake` models. Order fulfilment reads `orders_master`, `order_lines` and `generics`. If the server's `oasis_lake` project has no model of those names, add them to `hnh_oasis_source_only`. The `hnh` YAML declares a source named `oasis` and one named `reference`; the project's own sources are `oasis_lake` and `ofusion_conformed`, so there is no clash.

Phase 6 (patient experience) adds a source named `press_ganey` (tables `pg_survey_responses`, `pg_survey_questions`, `pg_survey_answer_options`, `dim_pg_service`), always read with `source()`. The receiving project has no source of that name and no model named `stg_pg__*`, `int_survey_*`, `dim_survey_*`, `fact_survey_*` or `rec_survey_monthly` (checked against `dbt/models` on 2026-10-07). The staging never reads the database's own views (`pg_survey_answers`, `pg_survey_answers_detail`, `*_v`); it expands the `responses` JSON itself.

## How the models read Fusion

With `hnh_fusion_as_ref: true`, `hnh_fusion_source('<table>')` calls `ref('<table>')` on the project's Fusion models (`models/fusion/staging/...`, same names as the tables: `fact_gl_journal_line`, `dim_gl_account`, `dim_coa_segment_value`, `dim_gl_period`, `fact_gl_balance`, `fact_ap_invoice_distribution`, `fact_ap_payment`, `fact_ap_payment_schedule`, `dim_supplier`, `dim_business_unit`) and, for the HCM (workforce) staging, 19 more: `dim_employee`, `dim_assignment`, `fact_period_of_service`, `fact_worker_movement`, `fact_assignment_work_measure`, `dim_department`, `dim_organization`, `dim_job`, `dim_grade`, `dim_position`, `dim_location`, `dim_worker_action`, `fact_payroll_run_result`, `dim_payroll_element`, `dim_payroll_input_value`, `fact_absence_entry`, `dim_absence_type`, `dim_absence_plan`, `fact_absence_balance`. Phase 5 (supply chain) adds 16 more: `dim_inventory_org`, `dim_subinventory`, `dim_item`, `dim_item_category`, `dim_inv_transaction_type`, `dim_lot`, `fact_inventory_transaction`, `fact_inventory_transaction_lot`, `fact_inventory_valuation`, `fact_inventory_onhand`, `fact_cost_distribution`, `fact_po_distribution`, `fact_po_schedule`, `dim_po_line_type`, `fact_receipt_transaction`, `fact_requisition_distribution` (all have models of those names in `models/fusion/`). They are ReplacingMergeTree, so staging reads them with `final`. The supply-chain staging reads the Oasis tables `doc`, `docl`, `docl_by_serial`, `product_base`, `bintran`, `control_contexts_data` and `delivery_lines` through `hnh_oasis_source` (all have `oasis_lake` models on the server; `docl` is read with `final`, because it over-counts by about 10% without it). Oasis payroll (`stg_oasis__payroll_transactions`) reads the Oasis `account_transactions` table through `hnh_oasis_source('account_transactions')` (an `oasis_lake` model of that name must exist, or add it to `hnh_oasis_source_only`). The hnh YAML declares a source named `fusion`; the project's own Fusion sources are named `ofusion_*`, so there is no clash.

## Aliased models

`hnh_dim_branch` and `hnh_dim_department` are built into `gold.dim_branch` and `gold.dim_department` (`alias`). The model names carry the `hnh_` prefix because `dim_branch` and `dim_department` already exist in `models/fusion/staging/conformed/`; dbt model names must be unique per project. Always `ref('hnh_dim_branch')` / `ref('hnh_dim_department')` in dbt code. `hnh_dim_gl_period`, `hnh_dim_gl_account`, `hnh_dim_supplier`, `hnh_fact_gl_journal_line` and `hnh_fact_ap_payment` are built into `gold.dim_gl_period`, `gold.dim_gl_account`, `gold.dim_supplier`, `gold.fact_gl_journal_line` and `gold.fact_ap_payment` for the same reason (the project's Fusion models already use those names). Phase 4 adds eight more: `hnh_dim_employee`, `hnh_dim_job`, `hnh_dim_grade`, `hnh_dim_position`, `hnh_dim_location`, `hnh_dim_worker_action`, `hnh_dim_absence_type` and `hnh_fact_worker_movement` are built into `gold.dim_employee`, `gold.dim_job`, `gold.dim_grade`, `gold.dim_position`, `gold.dim_location`, `gold.dim_worker_action`, `gold.dim_absence_type` and `gold.fact_worker_movement`. Phase 5 adds `hnh_dim_item`, built into `gold.dim_item` (the project's Fusion `dim_item` model exists), and `hnh_dim_supplier` now also holds Oasis supplier accounts (`source_system = 'oasis'`, with `supplier_code` and `oasis_branch_key`). Always `ref()` the `hnh_` names.

## Reference tables that must exist in `default`

Loaded once by `scripts/load_reference_data.py` and `scripts/load_hijri_calendar.py` (outside dbt): `branch_dict_source`, `map_purchasers`, `map_referral_policies`, `budget_data`, `bi_users`, `map_bi_user_permission` (SSAS pay and PII permissions, see below), `map_unified_department_v2`, `map_bed_classification`, `map_ward_tower`, `map_clinic_duration`, `map_clinic_count`, `map_home_care_entity`, `map_termination_reason`, `map_product_category`, `map_claim_status`, `map_nphies_reason`, `map_hijri_calendar`, `map_public_holiday`, `map_order_fulfilment_packages`, `map_pay_category`, `map_payroll_cutover`, `map_fs_account`, `map_oasis_fs_account`, `map_fs_line_order`, `map_budget_fs_line`, `map_fusion_specialty_unified`, `income_statement_budget`, `map_opening_balance_batch` (Fusion journal batches that are opening balances although not categorised MRC Open Balances, O-P3-12; add a row with `branch_id`, `je_batch_id`, `reason` when finance loads a go-live batch under another category). Phase 5 adds `map_scm_cutover` (one row per branch: inventory go-live date and first Fusion purchasing month; set Alrabwah's and Head Office's go-live dates when they move, O-P5-6), `map_store_department` (drafted by `scripts/draft_store_department_map.py`) and `map_item_group` (drafted by `scripts/draft_item_group_map.py`); both drafts await BI-manager review (O-P5-4). `bal_product_base` (table `default.old_bal_product_base`, the source's `identifier`) is optional: until the user loads the old warehouse's daily snapshots (columns `BRANCH_ID`, `C_ID`, `PRODUCT_CODE`, `Snapshot_timestamp`, `QTY_ON_HAND`, `AVERAGE_COST`; other names are set in the `cols` dict at the top of `stg_ref__stock_snapshot.sql`), `stg_ref__stock_snapshot` is empty and Oasis month-end stock starts at 2026-08-31 (Fusion-valuation months start at each live branch's go-live month: Ghirnata 2026-04, Abha 2026-05, Jazan and Muhayil 2026-07, Unaizah 2026-08, Khamis and Madinah 2026-09); the next `dbt build` after the load adds the snapshot and derived months. Re-run `load_hijri_calendar.py` once a year to extend the calendar.

The finance tables are loaded with `python scripts/load_reference_data.py --only <table>`; `fusion_specialty_unified.csv` is drafted by `scripts/draft_fusion_specialty_map.py` for the BI manager to complete.

`map_pay_category` is drafted by `scripts/draft_pay_category_map.py` for the BI manager to review (open item O-P4-1) and loaded with `--only map_pay_category`; `map_payroll_cutover` holds one row per branch when it moves payroll to Fusion (`branch_id`, `first_fusion_month`): add a row when Al-Rabwa, Khamis or Madinah move, and the models switch that branch from Oasis to Fusion payroll from that month.

`map_order_fulfilment_packages` (46 rows, from `static_mappings/order_fulfilment_packages.csv`) is loaded with `python scripts/load_reference_data.py --only map_order_fulfilment_packages`.

Phase 6 adds `map_pg_question_role` (61 rows: the Hospital NPS and Physician NPS question of each Press Ganey service, and the background attribute each background or routing question feeds) and `map_pg_background_value` (104 rows: the conformed value of each background answer code). Both are drafted by `scripts/draft_pg_maps.py` and loaded with `python scripts/load_reference_data.py --only map_pg_question_role map_pg_background_value`; the review is pending (O-P6-7). The loader never overwrites, so a reviewed version is loaded by truncating the table first. Every Press Ganey service with invitations must keep exactly one Hospital NPS question (test `assert_survey_hospital_nps_per_service`).

## Security table and dim_date

`gold.sec_user_access.login_name` is `<SSAS machine>\<user name>`. The source `UserName` already has an old domain prefix (for example `HNHRIYADH\name` or `INMA-BINTELLIGE\name`) in mixed case. The model keeps the part after the last backslash, lower-cased, as `user_name`, and puts the SSAS machine name in front of it. The original text is kept in `source_user_name`. The DAX comparison against `USERPRINCIPALNAME()` must be case-insensitive (DAX `=` on text is case-insensitive). Administrators get every real branch (never branch 0) and keep the specialty of their own source rows.

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
- `fact_preauth_line` also holds payer-initiated advance authorisations (`line_source = 'Payer advance'`, about 16.4K in 2026): they have no request, send, service, delivery or turnaround. Every existing pre-authorisation measure (services, requests, approval and rejection rates, unutilised, lost revenue, delivered not approved, turnaround, reasons) must filter `line_source <> 'Payer advance'`. Measure advance authorisations on their own: count = rows with `line_source = 'Payer advance'`, amount = Σ `payer_approved_amount` over them (sent as is, 0 and 1-SAR placeholders included), by `request_date_key` (the payer's creation date), sliced by `advance_reason`, `payer_license` or `care_type_key`; `rec_preauth_monthly.advance_authorisations` and `advance_approved_amount` reconcile them. `patient_key` is -1 when the payer's identity value matches no single patient; `episode_link_method` and `episode_match_count` show how the episode was found (filter `episode_match_count = 1` for unambiguous links).
- `fact_cash_receipt.receipt_kind`: Receipt, Cancellation (a negative receipt matching an earlier receipt of the same patient, episode and amount) or Refund (money paid back). Cash collected = Σ `receipt_amount` over Receipt and Cancellation; refunds = Σ over Refund.
- `fact_claim_line.legacy_in_scope` and the `legacy_*` amounts exist only for reconciliation with the old claims model; keep them out of user-facing perspectives.
- `fact_preauth_line.payer_comment` is payer free text and can echo member details; keep it out of general perspectives (treat like dim_patient_pii).
- Claim KPIs filter `fact_claim_line.is_latest_submission = 1` unless the measure is first-pass (`submission_number = 1`). Rejection rate divides `rejected_amount` by `submitted_amount` of lines with `adjudication_status = 'Adjudicated'`.
- Claim KPIs also filter `is_cancelled_claim = 0`: `is_latest_submission` is the last submission whether cancelled or not.
- `fact_claim_payment` is claim-level remittance from NPHIES only; it is not insurer AR (Phase 3).
- `fact_claim_line.invoice_key` and `fact_claim_payment.invoice_key` equal `fact_invoice.invoice_key`; do not relate facts to each other in SSAS, use them for drill-through or SQL.
- Remittance totals at the 2026-10-05 build: payment lines 634.4M SAR, advances 188.4M SAR. Money for advances (not claim remittance) is only in `fact_claim_payment` (`detail_type = 'advance'`); it is not in `rec_claims_monthly`. Each payer reconciliation is counted once, identified by its content (payers re-issue a new `fullUrl` on every pull); revised re-issues of a payment are listed by `warn_duplicate_claim_payments`. 213 details with payer payment dates in 2078 and 2115 (about 144K SAR) are outside the window and not in the fact.
- `days_to_payment` is skewed by bulk back-settlements (2025-05 and 2026-04); report medians per payment month, not averages or per year.
- `rec_claims_monthly.first_pass_*` include cancelled claims (submission 1 as sent); this is the one exception to the `is_cancelled_claim = 0` rule.
- A Rejected claim line can keep a token payer benefit in `approved_amount` (9,635 lines, about 123K SAR in total); it still counts as rejected in full.
- Reason codes of 2022 to October 2023 are mostly legacy `N-DC-0xx` codes and show as Unknown (open item O-P2B-8).
- `fact_order_line` KPI filters (spec section 8). Lost = `is_lost = 1`; inpatient lines stay in the fact for separate analysis; speciality comes from `dim_staff` through `ordering_staff_key`.
  - Order lines, Lost lines, Leak rate, Census, Contribution and Share of total lost: `is_in_leak_scope = 1` and `is_inpatient = 0`.
  - Lost value: as Lost lines, plus `is_unit_outlier = 0` (pharmacy orders in ml or mg that are delivered in packs).
  - Unit fulfilment rate: average of `unit_fulfilment_ratio` over `is_in_leak_scope = 1` and `is_inpatient = 0` lines (not a ratio of sums). Outlier lines are deliberately kept: the ratio is capped at 1 per line, so they cannot distort the average.
  - Partially delivered lines: `is_partially_delivered = 1` and `is_in_leak_scope = 1` and `is_inpatient = 0` and `is_unit_outlier = 0`. Without the scope filter about 79% of flagged lines are inpatient or out of scope.
  - Orders and Cancellation rate: over all lines (cancelled lines are out of leak scope) with `is_inpatient = 0` by default.
  - Order-to-delivery time (turnaround): median of `order_to_delivery_minutes` over delivered, non-inpatient lines, per category, leaving out the Consultation and Package categories (their charge is posted at order time, so the value is always 0). Negative values are kept and monitored.
- `fact_order_line.first_delivery_date_key` is NULL (not -1) for undelivered lines. `charged_amount` includes patient co-pay rows. `urgency_code` is the raw Oasis `urgent_flag` (R, S, H, A; meaning unconfirmed).
- Finance statements: multiply `fact_gl_balance_monthly` and journal amounts by `dim_fs_line.display_sign`. Default `balance_view = 'posted'` (ties to the Fusion trial balance); offer an "including unposted" measure set, because most Oasis-feed batches are unposted. Relate `fact_gl_balance_monthly` to `dim_gl_account`, `dim_gl_period` and `dim_branch`; filter one `balance_view` in every measure.
- Monthly trends use `period_movement_excl_opening`; each branch's go-live month carries one opening-balance journal with the year to date before go-live. Balances and year-to-date use the full measures.
- EBITDA, gross profit, net profit and every budget comparison come from `fact_income_statement_monthly` (`budget_line_code`); do not re-derive subtotals in DAX. Always slice income-statement measures by `budget_line_code`: detail codes mix credit-side and debit-side values, and subtotal codes already contain their details, so a sum across codes is meaningless.
- The balance sheet balances only with the current year's result: `fact_gl_balance_monthly` carries earlier years' results on each branch's prior-year roll account, but the current fiscal year's income-statement result stays on the income-statement accounts. Add an equity line *Profit for the year* = −Σ `closing_balance` of `balance_side = 'IS'` accounts for the selected period and view (display sign applied), so Assets = Liabilities + Equity in every period.
- DC_MEDICINES compares with Oracle's *Cost of Medicines* caption; DC_CONSUMABLES is medical consumables (not medicines, O-P3-8), and Fusion has no medical-consumables account yet, so DC_CONSUMABLES actual is 0 until finance maps one. Do not combine the two lines. Compare DC_MEDICINES actual with DC_MEDICINES + DC_CONSUMABLES budget (spec O-P3-8); TOTAL_DC and every subtotal are unaffected.
- `dim_budget_line.natural_side` is per code; UNBUDGETED rows take the side of their `statement_group` (credit for Revenue, Other income and OCI, debit otherwise), so favourable/unfavourable formatting of UNBUDGETED must read `fact_income_statement_monthly.statement_group`.
- `fact_ap_open_item` ages credit memos with a negative `amount_remaining` like invoices (as Fusion's ageing does), so they reduce the overdue buckets; filter `invoice_type` to see invoices only.
- Budget covers branches 1–6; Ghirnata, Muhayil and Head Office have actuals only.
- `fact_ap_open_item` is a snapshot at the last refresh (`snapshot_date`); payables ageing at a past date is not available.
- Head Office is `branch_key = 100`; the branch role must list it explicitly; admins receive it in `sec_user_access`.

- Headcount is a month-end snapshot from January 2026: use the last month of the selection or an average, never a sum across months; exclude contingent workers (`is_contingent = 0`) by default. Before 2026 only paid headcount (distinct `paid_person_key` with gross pay in `fact_payroll_monthly`) exists; do not count distinct `payee_key` across months, because it hashes source, branch and person or staff, so a person paid by Oasis and then by Fusion counts twice across a cutover (branch 3 over 202601–202609: 1,461 payees against 841 people).
- `fact_headcount_monthly.is_closed_month = 0` marks the projected current month-end (its snapshot includes scheduled changes); a "latest month" headcount KPI filters `is_closed_month = 1`.
- Payroll measures use `cost_amount` and `gross_pay`, which already exclude parallel-run rows. Do not sum `fact_payroll_monthly.amount`: hide it in SSAS, or use it only with a pay-category filter and `is_parallel_run = 0`. For 2026, Σ `amount` is 541.9M against Σ `cost_amount` 379.5M: parallel-run rows add 50.1M and the *Not pay* category (GOSI reference earnings) adds 123.5M.
- Turnover = leavers (`fact_worker_movement.is_leaver`) ÷ average month-end headcount, from 2026. The headcount snapshot has no leaver flag: a leaver normally has no month-end row.
- Put `fact_payroll_monthly`, `fact_leave_balance_monthly` and `agg_staff_productivity_monthly` in an HR/finance-only perspective and role; they carry pay.
- Leave balances are weekly running balances (about 3.7 accrual periods per month): summing `end_balance` or `leave_liability_amount` across a month overstates the liability about 4.4 times. Monthly KPIs filter `is_latest_in_month = 1` (the last accrual period of each employee and plan in the calendar month); the latest-position KPI filters `is_current_balance = 1` (the latest closed period). `is_closed_period = 0` marks future accrual periods (they run into 2027); do not count them in current-position KPIs.
- Leave liability = end balance × monthly salary ÷ 30, monthly salary = recurring pay (basic, housing, transport, food, clinical and other allowances) of the latest payroll month with positive Basic pay; null where the person has not been paid yet. Negative liabilities (overdrawn balances) are kept.
- `fact_absence_daily` keeps future-dated planned absence days (into 2027): year-to-date and trend measures must filter by `dim_date` (dates up to today).
- `fact_absence.absence_days` and `absence_hours` include entries that are not counted (awaiting, denied, saved, withdrawn): absence measures filter `is_counted = 1`. `fact_absence_daily` holds counted days only.
- Oasis payroll that is not yet closed is included (Phase 4 spec §12): `is_closed_payroll` (0 = Oasis status P, the staff's latest run only), `payroll_status` per payee and month (Closed, Open, Partly closed) and `open_run_date`. Open figures change until the branch closes the month; show `payroll_status` as a slicer and split gross pay into closed (`is_closed_payroll = 1`) and open. Build the workforce models after the daily Oasis copy (about 09:10), or the build misses payroll closed that morning.
- `agg_staff_productivity_monthly` covers linked doctors and nurses; compute revenue per payroll SAR as Σ `revenue_amount` ÷ Σ `payroll_cost`, never an average of ratios. Its FTE is the highest FTE per staff and month over non-contingent employees.

- Supply chain (Phase 5). Put `fact_stock_movement`, `fact_patient_consumption`, `fact_stock_monthly`, `fact_purchase_line` and `fact_goods_receipt` in a finance and supply-chain perspective and role; they carry cost and purchase prices. Every one joins `dim_branch`, so branch row-level security applies; `fact_patient_consumption` carries keys only.
- Consumption = Σ `consumption_cost` / `consumption_quantity` (positive) of `fact_stock_movement` where `is_consumption = 1`; transfers move stock but are never consumption; opening balances are never receipts or consumption. Department consumption slices this by `dim_store` (store type, unified department) and `dim_item` (item group).
- `fact_stock_monthly` is a snapshot: use the last month-end of the selection or an average, never a sum across months; filter `is_expiry_store = 0` for stock KPIs; `is_closed_month = 0` is the current month. Days of stock = stock value ÷ (the month's consumption cost ÷ days in month); turnover = 12 months' consumption cost ÷ average month-end stock value.
- Fusion month-end stock sits on the organisation-level `*` store except in September (the only on-hand snapshot). Days of stock and turnover therefore work at branch or item level, and expiry-store exclusion works only where on-hand exists.
- Every movement, stock and purchase row has `source_system`; `is_fusion_gap = 1` marks Oasis lines that Fusion has not received yet; a gap-filled line moves to Fusion on a later build without changing its date. `is_in_oasis` / `is_in_fusion` exist only on `fact_stock_movement` and `fact_patient_consumption`.
- Margin = Σ `revenue_amount` − Σ `consumption_cost` over `fact_patient_consumption` rows with `revenue_basis = 'charge'` (not `is_linked_to_charge = 1`). Package-component dispenses carry cost but their revenue is on the package header, so they are reported separately (`package_component_cost`; 52.0M SAR of 2026 cost). Revenue is on one line per charge line, so never average or repeat it.
- Costs are as recorded (CEFODOX in Abha at 6,241,137 SAR per bottle); check `warn_unit_cost_outliers` before publishing a month.
- In Khamis, Jazan, Unaizah, Madinah and Muhayil the Fusion valuation cost of pack items equals one base unit's Oasis cost. `cost_amount` keeps the recorded Fusion cost; `oasis_cost_amount` and `is_cost_mismatch` let SSAS show the Oasis cost instead, and `warn_cost_mismatch` reports it monthly.
- Quantities are in the item's primary unit (Fusion primary unit for Fusion-mapped items, Oasis base unit otherwise); purchase quantities are in the ordering unit (`uom_code`): compare purchase prices per item and supplier within one `source_system`.
- Supplier KPIs filter `fact_goods_receipt.is_supplier_receipt = 1` (every Oasis GRN and return to supplier; Fusion rows with a PO line); `is_po_receipt` only says the PO line is resolved in `fact_purchase_line`. `lead_time_days` is null when negative. Fusion `quantity_received` is net of returns; Oasis counts GRNs gross.
- `fact_purchase_line.ordered_value` is net of cancellations (`gross_ordered_value` keeps quantity x price): filter `is_approved_po = 1` (0 for CANCELED, REJECTED, WITHDRAWN, INCOMPLETE and PENDING APPROVAL).
- Role-playing relationships: `fact_stock_movement` to `dim_store` on `store_key` is active and on `transfer_store_key` inactive; `fact_purchase_line` to `dim_date` on `po_date_key` is active, `requisition_approved_date_key` and `first_receipt_date_key` inactive. Follow a store across the Oasis-to-Fusion cutover with `dim_store.store_group_key`.
- Never divide receipt quantities (primary unit) by purchase-line quantities (ordering unit).
- Fusion month-end stock does not yet deduct gap-filled sales (about 42% of lines from go-live), and Ghirnata's Fusion stock value is about 3x Oasis (pack items costed per pack); both inflate days of stock.
- Oasis lead times above 365 days (260 lines) skew the average: prefer the median.
- ABC class, slow-moving, near-expiry, fill rate, lead time, last PO price and price change follow spec 7; `hnh_abc_class` gives the A/B/C thresholds (0.80 / 0.95).
- Known data findings (Abha PON-numbered POs, Al-Hayat sister-hospital suppliers, Fusion cost errors, the interface gap) are listed in `docs/reconciliation_phase5.md`.

Patient experience (Phase 6, spec `2026-10-07-hnh-dwh-phase6-patient-experience-design.md` sections 7 and 9):

- Put `fact_survey_response` and `fact_survey_answer` in a patient-experience perspective. Both join `dim_branch`, so branch row-level security applies. `fact_survey_answer` → `fact_survey_response` is not a relationship: the answer fact carries the response's keys itself.
- Relationships: both facts → `dim_branch`, `dim_survey_service`, `dim_staff` (survey doctor; specialty is `dim_staff.unified_specialty`), `dim_department` (clinic), `dim_care_type`, `dim_date` on `visit_date_key` (active). `fact_survey_response` also → `dim_patient`, `dim_payer`, and `dim_date` on `sms_sent_date_key` and `survey_date_key` (inactive). `fact_survey_answer` → `dim_survey_question`.
- Survey quality (spec 7.1) counts primary invitations (`is_primary_for_encounter = 1`): Invitations = rows; SMS reach = `is_sms_sent` ÷ invitations; Response rate = `is_responded` ÷ invitations (not ÷ SMS sent: a third of submitted surveys have no SMS date, see `docs/reconciliation_phase6.md`); Completion = `is_submitted` ÷ `is_responded`; Answer completeness = Σ `scored_questions_answered` ÷ Σ `scored_questions_offered` over responded invitations; Median days visit → answer = median `days_visit_to_answer`, which exists for submitted surveys only (`survey_date` is the close date of partial and not-started surveys, and `survey_date_key` is null on them); Link % = `link_status = "Linked"` ÷ invitations; Doctor attribution = responded with `staff_key <> -1` ÷ responded.
- NPS (spec 7.2) = (Σ `is_promoter` − Σ `is_detractor`) ÷ COUNTROWS × 100 over `fact_survey_answer` with `is_scored = 1`. Hospital NPS filters `nps_role = "Hospital NPS"` and Physician NPS `nps_role = "Physician NPS"`; domain and question NPS use the same measure under a `dim_survey_question` filter. Show the answer count (n) and % promoter / passive / detractor next to every NPS, and display "insufficient sample" when n < 30. Label it "NPS (5-point)": it is not comparable to external 0–10 NPS benchmarks.
- Background attributes (`respondent_type`, `first_visit`, `booking_channel`, `used_lab`, …) are columns on `fact_survey_response`. To slice answer-level NPS by them, filter through `survey_response_key` in DAX (`TREATAS`) or build a survey-attribute dimension in SSAS. Response-level Hospital NPS (`fact_survey_response.nps_band`) gives the same figure and slices by them directly.

## SSAS views and access (2026-10-07)

- `models/hnh/marts/ssas/` builds 79 `gold.ssas_*` views (tag `hnh_ssas`, `SQL SECURITY DEFINER`, enforced contracts). SSAS reads only these views.
- After changing a view's columns on purpose, run `python scripts/gen_view_contracts.py` in the development repository and copy the regenerated `_ssas__models.yml`.
- Reference table `default.map_bi_user_permission (bi_user_name, can_see_pay, can_see_pii)` holds the pay and PII permissions; a user not listed has neither (fail closed). Load it with `scripts/load_reference_data.py --only map_bi_user_permission`.
- ClickHouse user `ssas_reader` (`readonly = 2`, `SELECT ON gold.ssas_*`) is created by `scripts/create_ssas_reader.py`; the SSAS server's system DSN `HNH_Gold` uses it.

## Deployment checklist (Ubuntu server)

1. Copy `models/hnh/`, `macros/hnh/`, `tests/hnh/` into `dbt/` (commit them to the repo and pull on the server, so line endings and file-name case come from git).
2. Edit `dbt/dbt_project.yml` as above (vars, `hnh:` block, `data_tests:`, `on-run-end:`).
3. Add `use_lw_deletes: true` to the `oasis` output in the server's `profiles.yml`.
4. Check the reference tables listed above exist in `default` on the server's ClickHouse.
5. `cd dbt && dbt parse` — must finish without errors.
6. `dbt build --select tag:hnh` — the first run creates the `stg`, `int` and `gold` objects; expect `ERROR=0` (Phase 6 full build of 2026-10-07: PASS=1135 WARN=50 ERROR=0 in about 17 minutes, Phase 6 models under 3.1 GiB; Phase 5 full build of 2026-10-06: PASS=1037 WARN=49 ERROR=3 in about 17.5 minutes, peak query memory 45.3 GiB (Phase 2 fact_charge_line), Phase 5 maximum 22.4 GiB (fact_patient_consumption); the 3 errors were Phase 4 position-key relationship tests, fixed by commit 271be60 and green on re-test, so a clean build is expected to be ERROR=0; Phase 4 full build of 2026-10-06: PASS=813 WARN=38 ERROR=0 in about 12.5 minutes; Phase 3 of 2026-10-05 was PASS=642 WARN=31 ERROR=0). The WARN count is the `warn_*` monitors and warn-severity tests that return data findings (Phase 1–3), so a few more or fewer is normal; only ERROR > 0 is a failure.
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
