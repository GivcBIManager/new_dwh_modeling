# HNH Data Warehouse — SSAS Tabular Model `HNH_Analytics`

- **Date:** 2026-10-07
- **Status:** Draft for review
- **Parent specs:** `2026-10-01-hnh-dwh-gold-layer-design.md` (sections 8 KPIs, 9 security, 11 orchestration, 12 SSAS handoff contract) and the six phase specs, whose "KPI definitions" and "Security and SSAS handoff" sections this model implements. `docs/receiving_project_config.md` → "Notes for the SSAS model" is a binding input: every note there is a modelling or measure rule here.
- **Profile:** measured 2026-10-07 (read-only) on `gold` (ClickHouse 26.5) and on the developer laptop's tools.

---

## 1. Purpose and decisions

The aim is one semantic model over the gold layer that self-service users and new Power BI Report Server reports connect to live. It covers all six subject areas, gives one definition per KPI (the dbt-defined fields, aggregated thinly), and enforces the warehouse's access rules.

Decisions made by the user during design (2026-10-07):

| # | Decision |
|---|---|
| D1 | First version serves **self-service across all six subject areas**; the existing PBIRS reports stay on their old models (repointing is later work). |
| D2 | Non-functional requirements: optimised model size, fast measures, perspectives, partitioned large tables, a designed deployment method. |
| D3 | **One model** `HNH_Analytics` with perspectives (not one model per subject area, not aggregates only). |
| D4 | Server HNHANALYTICSSRV has 256 GB RAM and also runs PBIRS. |
| D5 | **Production instance only** (`HNHANALYTICSSRV\REPORTSERVERDB`); a second database `HNH_Analytics_Test` on the same instance is the test slot. |
| D6 | Processing: after each successful dbt run reload dimensions and the **last 3 months** of each large fact; **full process weekly** (Friday). |
| D7 | `rec_*` tables, `etl_run_log` and all `legacy_*` columns are **not** in the model. |
| D8 | Document numbers stay **only on document-level facts**; dropped from the four big line facts. |
| D9 | Security is **fully dynamic, one role**; pay and PII access come from warehouse flags `can_see_pay`, `can_see_pii`. |
| D10 | A specialty restriction narrows only facts that relate to `dim_staff`; branch-wide facts (finance, supply, invoices, claims, receipts) are filtered by branch only. |
| D11 | Sections 4–6 of the design (measures, processing, deployment) approved as presented, including the dbt `ssas_*` views. |

---

## 2. Environment and findings

| Item | Value | Consequence |
|---|---|---|
| SSAS | 17.0.25.218 = SQL Server 2025 Analysis Services | Compatibility level up to **1700**. The model uses **1700**. |
| PBIRS | 1.26.9637.31070 (May 2026) | Reports connect live; only the server evaluates the model, so the compatibility level does not constrain PBIRS. Calculation groups, perspectives and RLS work over live connections. |
| Power BI Desktop RS on the laptop | 2.143.954.0 | Possibly older than the May 2026 Desktop RS. Older files upload to a newer server; install the May 2026 Desktop RS so authors get the server's features (open item O-S7). |
| Tabular Editor 2 | 2.27.9403, AMO/TOM 17.0.39.18 | Authoring and command-line deployment. TMDL save at 1700 is verified in plan task 1 (O-S1). |
| SSMS 21, DAX Studio | installed | Administration; VertiPaq Analyzer and server timings. |
| Visual Studio AS projects extension | not installed | Not used. |
| ClickHouse ODBC driver | 64-bit ANSI and Unicode on the laptop | Must also be installed on HNHANALYTICSSRV (O-S2). |
| ClickHouse | 26.5 | Supports `SQL SECURITY DEFINER` views. |

Gold size (2026-10-07): about 260M fact rows. Largest: `fact_charge_line` 66.3M, `fact_order_line` 58.8M, `fact_stock_movement` 32.3M, `fact_patient_consumption` 26.5M, `fact_claim_line` 23.3M, `fact_cash_receipt` 16.8M, `hnh_fact_gl_journal_line` 9.7M, `fact_preauth_line` 6.9M, `fact_encounter` 5.8M, `fact_episode` 4.6M, `fact_invoice` 3.7M, `fact_bed_occupancy_daily` 3.7M, `dim_patient` 3.5M. History runs 2022–2026 and is even across years (about 13M charge lines per year).

Memory drivers found by profiling: line surrogate keys (23–66M distinct values), source line ids and document numbers (`delivery_charge_id` 42M, `invoice_doc_no` 28M text, `order_line` 30M, `oasis_line_id` 26M, `oasis_doc_no` 13M text, `master_order_no` 12M), `fact_patient_consumption.charge_line_key` 20M, and `Float64` amounts. A handful of rows are dated 2027 (charge, order, encounter) and absence days are planned into 2027.

`sec_user_access`: 276 users, 74 admins, 4 with a specialty restriction; no user has different specialties in different branches.

`dim_date`: 2008-01-01 to 2028-12-31, `fiscal_year = year` on every row (fiscal year = calendar year). Monthly facts key on the **month-end** date (`month_date_key`, e.g. 20260131). `dim_gl_period` has 12 quarterly adjustment periods (`Adj-Q1-24` …) with an `end_date_key`.

---

## 3. Architecture

```
gold.dim_* / fact_* / agg_* / sec_user_access        (dbt, unchanged)
        │
gold.ssas_<table>   views (dbt, new)  — column pruning, types, Yes/No flags
        │   Power Query Odbc.Query → ClickHouse ODBC (system DSN HNH_Gold, read-only user bi_user)
        ▼
SSAS 2025  HNHANALYTICSSRV\REPORTSERVERDB
   HNH_Analytics        (production)
   HNH_Analytics_Test   (deploy → process → test → promote; data cleared after)
        │   live connection, viewer's Windows identity → USERPRINCIPALNAME()
        ▼
PBIRS May 2026 reports and Power BI Desktop RS / Excel self-service
```

Repository layout (all new, portable on its own):

```
hnh_dwh/models/hnh/marts/ssas/        ssas_<table>.sql views + _ssas.yml (contracts, tests)
ssas/HNH_Analytics/                   TMDL model (Tabular Editor 2)
ssas/bpa_rules.json                   Best Practice Analyzer rules
ssas/scripts/deploy.ps1               validate → test DB → promote
ssas/scripts/partitions.ps1           create/merge partitions on a database
ssas/scripts/process.ps1              daily | weekly processing with the etl_run_log gate
ssas/scripts/test.ps1                 measure, security and performance tests
ssas/tests/measures/<group>.dax|.sql  measure check pairs
ssas/tests/security.json              sample users and expected visibility
ssas/README.md                        operator guide
```

---

## 4. Model scope

### 4.1 Tables

| In the model | Notes |
|---|---|
| All `dim_*` (incl. the `hnh_dim_*` models under their alias names) | `dim_patient_pii` only in the Patient Details perspective, rows filtered by `can_see_pii` |
| All `fact_*` (incl. `hnh_fact_*`) | |
| `agg_clinic_capacity_daily`, `agg_episode_billing`, `agg_staff_productivity_monthly` | |
| `sec_user_access` | hidden, used by the role only |
| Staff role-playing copies: **Booked Doctor**, **Admission Treating Doctor**, **Anaesthetist** | from `gold.ssas_dim_staff_role` (name, specialty, unified specialty, category, grade columns only) |
| Calculation group **Time Calculation** | section 8.3 |

Not in the model: `rec_*`, `etl_run_log`, `bridge_employee_staff` (every HR fact already carries `employee_key` and `staff_key`), `legacy_*` columns, `_loaded_at`, `fact_preauth_line.payer_comment` (payer free text that can echo member details).

### 4.2 Column rules (implemented in the `gold.ssas_*` views)

1. **Line surrogate keys** (`*_line_key`, `movement_key`, `*_key` of the fact's own grain) are dropped.
2. **Fact-to-fact keys** (`episode_key`, `encounter_key`, `invoice_key`, `admission_key`, `purchase_line_key`, `charge_line_key`) are kept only where a listed measure needs them, hidden; otherwise dropped. Facts are never related to each other.
3. **Document numbers** (D8) are kept on `fact_invoice`, `fact_episode`, `fact_encounter`, `fact_admission`, `fact_surgery`, `fact_purchase_line`, `fact_goods_receipt`, `fact_claim_payment`, AP facts and GL journal lines; dropped from `fact_charge_line`, `fact_order_line`, `fact_stock_movement`, `fact_patient_consumption` and `fact_claim_line` (`invoice_doc_no`, `delivery_charge_id`, `delivery_line`, `master_order_no`, `order_line`, `order_key`, `oasis_line_id`, `oasis_doc_no`, `fusion_transaction_id`, `claim_invoice_no`, `stat_invoice_no`, `visit_id`, `sequence_no`, `lot_number`).
4. **Amounts** are cast to `Decimal(18,4)` → SSAS *Fixed decimal* (Currency). **Quantities, ratios and minutes** stay `Float64` → *Decimal*.
5. **Flags**: a flag users slice by becomes a `'Yes'`/`'No'` text column (visible); a flag used only inside measures stays `UInt8` (hidden). A flag is never loaded twice.
6. **Arrays** (`fact_claim_line.reason_codes`) are dropped; `primary_reason_code` covers analysis.
7. **Nullable date keys** stay nullable; null means "no date". The view never maps a null date to a sentinel.
8. **High-cardinality free text** (`fact_order_line.status_reason`, 109K values) is dropped unless a KPI uses it.
9. `fact_gl_balance_monthly` gains `period_end_date_key` (from `dim_gl_period.end_date_key`; an adjustment period takes its quarter's end date) so it relates to the Date table.
10. Each view is `materialized='view'` with `SQL SECURITY DEFINER`, selects explicit columns, and has a dbt column contract (names and types) so a gold change that breaks the model fails the dbt build.

The exact kept/dropped column list per table is written in the implementation plan from this rule set and the measure catalogue (section 8); the plan may only drop more, never keep a column these rules drop.

### 4.3 Model-side settings

- Compatibility level 1700, culture en-US, default mode Import, `DiscourageImplicitMeasures = true`.
- Every fact column hidden; users see measures and dimension attributes only.
- Every hidden key, hidden flag and amount column: `IsAvailableInMDX = false` (no attribute hierarchy), `SummarizeBy = None`; keys `EncodingHint = Value`.
- No calculated columns and no calculated tables. Text sort orders use the gold columns (`month_name` by `month`, `day_name` by `day_of_week`, FS lines by their order column).
- One user hierarchy: Date → Calendar (Year › Quarter › Month › Day). No others in version 1.
- `dim_date` is marked as the date table on `date_day`; relationships use `date_key`.

---

## 5. Relationships

All relationships are many-to-one, single direction, dimension filters fact. Every fact relates to `dim_branch`. No fact relates to another fact.

### 5.1 Dates, staff and role-playing dimensions per fact

Active date = the partition column of section 9.3. Inactive relationships are used by named measures through `USERELATIONSHIP`.

| Fact | Active date | Inactive dates | Staff (active, carries RLS) | Other role-playing |
|---|---|---|---|---|
| `fact_charge_line` | `delivery_date_key` | — | `staff_key` | payer: `billed_payer_key` active, `episode_payer_key` inactive |
| `fact_order_line` | `order_date_key` | `first_delivery_date_key` | `ordering_staff_key` | department: `ordering_department_key` |
| `fact_stock_movement` | `date_key` | — | — | store: `store_key` active, `transfer_store_key` inactive |
| `fact_patient_consumption` | `date_key` | — | `treating_staff_key` | payer: `billed_payer_key` |
| `fact_claim_line` | `statement_end_date_key` | `submitted_date_key`, `response_date_key` | — | |
| `fact_claim_payment` | `payment_date_key` | `statement_end_date_key` | — | |
| `fact_cash_receipt` | `receipt_date_key` | — | — | time: `receipt_time_key` |
| `fact_invoice` | `invoice_date_key` | service start/end, statement end/sent/approved | — | |
| `fact_revenue_adjustment` | `adjustment_date_key` | — | — | payer: `billed_payer_key` |
| `fact_preauth_line` | `request_date_key` | first sent, final response, valid from/to | `requesting_staff_key` | |
| `agg_episode_billing` | `last_delivery_date_key` | first/last invoice date | — | |
| `fact_encounter` | `encounter_date_key` | `arrival_date_key`, `booking_date_key` | `treating_staff_key` | `booked_staff_key` → Booked Doctor; time: `encounter_time_key` active, `arrival_time_key` inactive |
| `fact_episode` | `start_date_key` | `end_date_key` | `consultant_staff_key` | |
| `fact_admission` | `admit_date_key` | clinical/physical/financial discharge | `consultant_staff_key` | `treating_staff_key` → Admission Treating Doctor; department: `first_department_key` active, `last_department_key` inactive; bed: `last_bed_key` |
| `fact_bed_occupancy_daily` | `date_key` | — | — | |
| `fact_surgery` | `operation_date_key` | — | `surgeon_staff_key` | `anaesthetist_staff_key` → Anaesthetist |
| `agg_clinic_capacity_daily` | `date_key` | — | `staff_key` | |
| `fact_target_daily` | `date_key` | — | — | |
| `fact_survey_response` | `visit_date_key` | `sms_sent_date_key`, `survey_date_key` | `staff_key` | |
| `fact_survey_answer` | `visit_date_key` | — | `staff_key` | |
| `hnh_fact_gl_journal_line` | `accounting_date_key` | `posted_date_key` | — | `period_key` → `dim_gl_period`; `intercompany_branch_key` hidden, no relationship |
| `fact_gl_balance_monthly` | `period_end_date_key` | — | — | `period_key` → `dim_gl_period` |
| `fact_income_statement_monthly`, `fact_budget_monthly` | `month_date_key` | — | — | |
| `fact_ap_invoice_line` | `accounting_date_key` | `invoice_date_key` | — | `period_key` → `dim_gl_period` |
| `fact_ap_open_item` | `invoice_date_key` | `due_date_key` | — | |
| `hnh_fact_ap_payment` | `payment_date_key` | — | — | |
| `fact_stock_monthly` | `month_date_key` | — | — | |
| `fact_purchase_line` | `po_date_key` | requisition approved, first receipt | — | store: `ship_to_store_key` |
| `fact_goods_receipt` | `date_key` | — | — | |
| `fact_headcount_monthly` | `month_date_key` | — | `staff_key` | |
| `hnh_fact_worker_movement` | `action_date_key` | — | `staff_key` | `previous_*` HR keys inactive to their dims; `previous_branch_key` hidden, no relationship |
| `fact_payroll_monthly` | `month_date_key` | — | `staff_key` | |
| `fact_leave_balance_monthly` | `accrual_period_date_key` | — | — | |
| `fact_absence` | `start_date_key` | `end_date_key` | `staff_key` | |
| `fact_absence_daily` | `date_key` | — | `staff_key` | |
| `agg_staff_productivity_monthly` | `month_date_key` | — | `staff_key` | |

Every other `*_key` on a fact relates actively to its dimension of the same name (patient, service, department, payer, care type, item, store, supplier, GL account, employee, HR department, job, grade, position, location, pay category, etc.).

### 5.2 Why staff role-playing uses copies

SSAS does not allow `USERELATIONSHIP` over a relationship whose table carries a row filter, and `dim_staff` carries the specialty filter. Each fact therefore relates to `dim_staff` through its primary staff role only (the one security applies through), and secondary roles relate actively to their own small copy table (no row filter; the fact rows are already secured through branch and the primary role). For the same reason `previous_branch_key` and `intercompany_branch_key` have no relationship to `dim_branch`.

### 5.3 Patient PII

`dim_patient_pii` relates one-to-one to `dim_patient` on `patient_key`, cross-filtering both directions, so PII attributes filter facts through `dim_patient`. Its rows are filtered by `can_see_pii` (section 6). The relationship's security filtering behaviour is **one direction** (`dim_patient` → `dim_patient_pii`): the PII row filter must never propagate to `dim_patient`, or a user without PII access would lose every fact row. Security test 11.4 checks that a non-PII user sees the same fact totals as a PII user of the same branches.

---

## 6. Security

### 6.1 Warehouse changes

- New reference table `default.map_bi_user_permission` (`bi_user_name` String — the user name as in `bi_users`, normalised like `sec_user_access.user_name`, `can_see_pay` UInt8, `can_see_pii` UInt8), loaded once by a loader script and maintained by the BI manager (delivery constraint: no seeds, no CSV in git).
- `gold.sec_user_access` gains `can_see_pay` and `can_see_pii`, left-joined from that table, **default 0**. Admins get nothing automatically.
- New tests: both flags are 0/1 and not null; every `map_bi_user_permission.bi_user_name` (normalised) exists in `sec_user_access` (warn).

### 6.2 Role "HNH Readers"

- Permission: Read. Member: the local group `HNHANALYTICSSRV\HNH_BI_Users` (created by the BI manager on the server; individual users are added to the group, never to the role). Deployments never change role membership.
- `USERPRINCIPALNAME()` returns `HNHANALYTICSSRV\<user>` for a local account, the same as `USERNAME()` (spike 2026-10-08, logged on as `BI_Developer`); `sec_user_access.login_name` has the same form; DAX `=` on text is case-insensitive.

| Table | Row filter (DAX, abbreviated) |
|---|---|
| `sec_user_access` | `FALSE()` |
| `dim_branch` | `dim_branch[branch_key] IN CALCULATETABLE(VALUES(sec_user_access[branch_key]), sec_user_access[login_name] = USERPRINCIPALNAME())` |
| `dim_staff` | `dim_staff[staff_key] = -1` **or** the user has a `sec_user_access` row with a blank `unified_specialty` **or** `dim_staff[unified_specialty]` is one of the user's `unified_specialty` values (specialty only, no branch match — P15) |
| `dim_pay_category` | the user has any row with `can_see_pay = 1` |
| `fact_leave_balance_monthly`, `agg_staff_productivity_monthly` | the user has any row with `can_see_pay = 1` |
| `dim_patient_pii` | the user has any row with `can_see_pii = 1` |

- **Fail closed:** a user with no `sec_user_access` row passes no branch, so every fact is empty (every fact relates to `dim_branch`). A user who is not in the local group cannot connect.
- Head Office is `branch_key = 100`; it is filtered like any branch.
- Specialty (D10): facts without a staff relationship are filtered by branch only.
- Payroll is filtered through `dim_pay_category` (every payroll row has a pay category; Unknown −1 included in the filter).
- Server administrators (SSAS server role) bypass row filters; they are the BI manager's accounts only.

### 6.3 PBIRS identity

PBIRS and SSAS are on the same machine, so the viewer's Windows identity should reach SSAS without Kerberos delegation. Plan task verifies `USERPRINCIPALNAME()` from a published report (O-S3). Fallback: the report's data source uses a stored Windows credential of a service account that is an SSAS administrator, with "Impersonate the authenticated user" (`EffectiveUserName`), which keeps `USERPRINCIPALNAME()` = the viewer.

---

## 7. Perspectives

Perspectives are navigation, not security. Each lists its facts, their measures, and the shared dimensions those facts relate to (Date, Time, Branch, Care Type, Staff, Department, Payer, Patient, …). `sec_user_access` is in none.

| Perspective | Facts and aggregates |
|---|---|
| **Executive** | encounters, admissions, charge lines (revenue measures), invoices, claim lines, income statement, budget, targets, headcount, survey responses |
| **Patient Flow** | encounters, admissions, episodes, bed occupancy, surgery, clinic capacity, targets |
| **Revenue Cycle** | charge lines, order lines, invoices, cash receipts, revenue adjustments, episode billing |
| **Claims & Pre-auth** | claim lines, claim payments, pre-auth lines |
| **Finance** | GL journal lines, GL balance, income statement, budget, AP invoice lines, AP open items, AP payments |
| **Workforce** | headcount, worker movements, absence, absence daily, payroll, leave balances, staff productivity |
| **Supply Chain** | stock movements, stock monthly, patient consumption, purchase lines, goods receipts |
| **Patient Experience** | survey responses, survey answers |
| **Patient Details** | `dim_patient_pii` with encounters, admissions, episodes, invoices |

---

## 8. Measures

### 8.1 Catalogue

The measure catalogue is the union of the "KPI definitions" sections of the eight specs (about 180 rows): gold layer §8 (35), Phase 2 revenue cycle (47), order fulfilment (13), Phase 2B claims (20), Phase 3 finance (21), Phase 4 workforce (13), Phase 5 supply chain (17), Phase 6 patient experience (17), plus the measure rules in `receiving_project_config.md` "Notes for the SSAS model". Each KPI is one measure; no measure is invented beyond the base measures the ratios reuse and the time items of 8.3. The plan lists every measure with its DAX.

Placement: each measure lives on the fact (or aggregate) it reads, in display folders `<KPI group>` (e.g. *Claims › Rejection*, *Finance › Statement*). A measure that combines two facts (e.g. revenue per payroll SAR) lives on the fact of its denominator.

### 8.2 Rules

1. **Base measures** are `SUM`/`COUNTROWS` with column filters inside `CALCULATE` (`KEEPFILTERS` when the filter must intersect the user's selection). No `FILTER(<fact table>, …)` and no `SUMX`/`AVERAGEX` over a fact with more than 1M rows: every per-row quantity is a stored column.
2. **Distinct counts** are not taken on high-cardinality keys of the facts above 20M rows. Visits, episodes and admissions are `COUNTROWS` of their own fact; billed episodes come from `agg_episode_billing`. `DISTINCTCOUNT` is allowed on facts under 10M rows or on keys under 1M distinct values (e.g. pre-auth requests).
3. **Ratios** use `DIVIDE` with variables over base measures; no rule is repeated inside a ratio.
4. **Snapshots and balances** (GL balance, headcount, stock on hand, leave balance, AP open items) return the value at the **last period in the filter context** (`LASTNONBLANK` over the month-end `date_key`, or the snapshot rule of the spec), never a sum over time. Leave balances follow `is_latest_in_month` / `is_current_balance`; headcount excludes contingent workers and uses `is_closed_month` as specified.
5. **Medians** (days to pay, days to payment, order turnaround, lead time) use `MEDIAN` over a filtered column, per the spec's grain (e.g. days to payment per payment month).
6. **Receiving notes are measure rules.** Among them: payroll sums `cost_amount`/`gross_pay`, never `amount`; visit KPIs use `encounter_type IN {"OP","ER"}`; claim KPIs use `is_latest_submission = 1` and `is_cancelled_claim = 0` except first-pass; occupancy uses inpatient, non-excluded wards; finance multiplies by `dim_fs_line.display_sign` and defaults to `balance_view = "posted"`; EBITDA and subtotals come from `fact_income_statement_monthly`; supply margin uses `revenue_basis = "charge"`; NPS is labelled "NPS (5-point)" and shows "insufficient sample" below n = 30 (format string expression); absence and leave measures stop at today through `dim_date[is_past]`.
7. **Formats:** SAR `#,0` (a "SAR thousands" variant only where the spec asks), percentages `0.0%`, counts `#,0`, durations `#,0.0` with the unit in the measure name.

### 8.3 Calculation group "Time Calculation"

Items: **Current**, **MTD**, **QTD**, **YTD**, **PY**, **PY YTD**, **YoY Δ**, **YoY %**, **MoM Δ**, **MoM %**, **Rolling 12M**. Calendar fiscal year (`fiscal_year = year`). Percentage items set their own format string; Δ items keep the measure's format.

Snapshot and balance measures (rule 8.2.4) are excluded from MTD, QTD, YTD and Rolling 12M: those items return `SELECTEDMEASURE()` unchanged for them, using a named list (`ISSELECTEDMEASURE(…)`) kept in one calculation item expression variable. PY, YoY and MoM apply to them normally.

---

## 9. Data source, partitions and processing

### 9.1 Data source

- Structured (Power Query) ODBC data source `HNH_Gold` over the ClickHouse ODBC Unicode driver, system DSN `HNH_Gold` on HNHANALYTICSSRV, database `gold`, user `bi_user`. Every partition is an M partition `Odbc.Query("dsn=HNH_Gold", <SQL>)` (decision P24).
- The password lives only in the DSN on the server; the data source credential is `Anonymous` and carries no secret.
- `bi_user` (O-S6): read-only (`readonly = 2`), `max_execution_time` 3600, generous enough for a full year partition.

### 9.2 Partition queries

Every partition is `SELECT * FROM gold.ssas_<table> WHERE <date column> …`. Single-partition tables have no `WHERE`. Column shaping lives only in the view.

### 9.3 Partition scheme

**Large tables** (partition column in brackets):
`fact_charge_line` (`delivery_date_key`), `fact_order_line` (`order_date_key`), `fact_stock_movement` (`date_key`), `fact_patient_consumption` (`date_key`), `fact_claim_line` (`statement_end_date_key`), `fact_cash_receipt` (`receipt_date_key`), `hnh_fact_gl_journal_line` (`accounting_date_key`), `fact_preauth_line` (`request_date_key`), `fact_encounter` (`encounter_date_key`), `fact_episode` (`start_date_key`), `fact_invoice` (`invoice_date_key`), `fact_bed_occupancy_daily` (`date_key`), `agg_episode_billing` (`last_delivery_date_key`), `agg_clinic_capacity_daily` (`date_key`), `fact_target_daily` (`date_key`), `fact_payroll_monthly` (`month_date_key`).

For each large table, in a year Y:

| Partition | Rows |
|---|---|
| `<table> YYYY` | one per year from 2022 to Y−2 |
| `<table> YYYY-MM` | one per month of Y−1 and Y (all 12 months of Y are created in January; future months are empty) |
| `<table> Later` | date key after Y-12-31 |
| `<table> No date` | date key null |

The union of the partitions' `WHERE` clauses covers every row exactly once (tested, section 11). `dim_patient` and every other table: one partition.

**Partition upkeep** (`partitions.ps1 -Database <db>`), idempotent: creates any missing partition of the scheme for today's year, and in January merges the twelve monthly partitions of Y−2 into `<table> Y−2` (TMSL `mergePartitions`) before creating Y's months. Git holds one template partition per table; real partitions exist only on the server.

### 9.4 Processing (`process.ps1`)

**Gate:** proceed only if the latest `gold.etl_run_log` row with `selected = 'tag:hnh'` has `status = 'success'` and is newer than the last successful processing (recorded in `ssas/state/last_processed.json`; the folder is git-ignored). Otherwise exit with a non-zero code and process nothing.

**Daily** (`-Mode Daily`), one TMSL `sequence` transaction (`maxParallelism` 6):
1. `dataOnly` refresh of every dimension, the staff copies and `sec_user_access`.
2. `dataOnly` refresh of, per large table, the current month and the two months before it, `Later` and `No date`; `full` refresh of every single-partition fact.
3. `calculate` refresh of the database.

**Weekly** (`-Mode Weekly`, Friday): `full` refresh of the database in one transaction.

Users keep querying the previous data until the transaction commits; a failure rolls back and leaves yesterday's model in place (parent spec rule).

**Trigger:** manual for now (open item O9 of the parent spec); the script runs unchanged from Task Scheduler or a SQL Agent job later.

### 9.5 Memory

Expected model size after the column rules: 6–10 GB (measured in plan; budget ≤ 10 GB). Recommended SSAS instance settings, applied by the BI manager (O-S5): `LowMemoryLimit` 45, `TotalMemoryLimit` 60, `HardMemoryLimit` 70 (percent of 256 GB), `VertiPaqPagingPolicy` 1. The SQL Server engine that hosts the PBIRS catalog should have `max server memory` set so the three services cannot starve each other. The test database's data is cleared after each promotion.

---

## 10. Source control and deployment

### 10.1 Source control

- `ssas/HNH_Analytics/` is a TMDL folder saved by Tabular Editor 2. Fallback if TE 2.27 cannot save TMDL at level 1700 (O-S1): TE2's "Save to folder" JSON format.
- Git holds measures, relationships, roles (without members), perspectives, the calculation group and template partitions. It holds no credentials and no membership.
- `ssas/bpa_rules.json` (Best Practice Analyzer) includes at least: no `Double` amount columns; hidden columns have `IsAvailableInMDX = false`; no implicit measures; no calculated columns or tables; every measure has a format string and a display folder; every relationship is single-direction except the PII one-to-one; no `FILTER(<table>)` over a fact in a measure; every visible object has a description.

### 10.2 `deploy.ps1`

1. **Validate:** TE2 CLI loads the model and runs `bpa_rules.json` (any error-severity violation stops). There is no TE2 schema check (P17): schema drift is caught by the enforced dbt contracts on the `gold.ssas_*` views and by the Test stage (full process and SSAS-vs-ClickHouse row counts) before production is touched.
2. **Test:** deploy to `HNH_Analytics_Test` with partitions (`-O -P -R`, no members), run `partitions.ps1`, full process, run `test.ps1`. Any failure stops.
3. **Back up** `HNH_Analytics` to `HNH_Analytics_<timestamp>.abf` in the SSAS backup folder (keep the last 5).
4. **Promote:** deploy the same commit to `HNH_Analytics` with `-O -R`, **without** `-P` (server partitions kept), `-M` (members kept) and `-C` (data source kept). Then run `partitions.ps1` and a `calculate` refresh, and read `$System.TMSCHEMA_PARTITIONS`: any partition not in state Ready (a new table, or a table whose columns changed) gets a `full` refresh, followed by a final `calculate`. If only measures, formats, perspectives or the calculation group changed, every partition is Ready and nothing is reloaded. The script prints which partitions it refreshed.
5. **Clear** `HNH_Analytics_Test` (`clearValues`).
6. **Tag** the commit `ssas-YYYY.MM.DD[-n]`.

**Rollback:** `Restore-ASDatabase` of the latest `.abf` over `HNH_Analytics`.

**First deployment:** same steps, without the backup; then the BI manager adds `HNHANALYTICSSRV\HNH_BI_Users` as the role member once.

---

## 11. Testing

Run by `test.ps1` against the test database at every deploy, and on demand against production.

1. **dbt:** contracts and tests on the `ssas_*` views; a singular test that each large view's rows equal the sum over the partition scheme's `WHERE` clauses (no row lost or doubled); `sec_user_access` flag tests (6.1).
2. **Measures:** for each KPI group at least one pair `ssas/tests/measures/<group>.dax` / `.sql` evaluated for a fixed month and branch (and one all-branch total). Sums must match ClickHouse within 0.01 SAR, counts exactly; where a `rec_*` table already holds the figure the SQL reads it.
3. **Partitions:** row count per table in SSAS (`DMV` / `COUNTROWS`) equals ClickHouse `count()` of the view.
4. **Security** (each query under the test user's own Windows logon, password from `C:\HNH\secrets\bi_user_credentials.xml`; O-S10): users from `ssas/tests/security.json` — an admin (all 9 branches incl. Head Office), a single-branch user (only that branch), a specialty user (only that specialty's staff rows plus Unknown, branch-wide facts of the branch), a pay user and a non-pay user (payroll rows vs none), a PII user and a non-PII user (PII rows vs none, identical fact totals), and a user absent from `sec_user_access` (zero rows in every fact).
5. **Size and speed:** VertiPaq Analyzer total ≤ 10 GB; a fixed set of report-style DAX queries in `ssas/tests/performance/` (one card and one matrix per perspective, one month by branch) runs under 1 s warm and under 3 s cold (server timings), recorded in the deploy log.
6. **Processing:** a daily run on the test database finishes and the row counts of 3 still match; the duration is recorded (no hard limit in version 1).

---

## 12. Open items

| # | Item | Needed for | Status |
|---|---|---|---|
| O-S1 | Tabular Editor 2.27 saves/deploys TMDL at compatibility level 1700 | Source control format | Plan task 1 |
| O-S2 | ClickHouse ODBC driver installed on HNHANALYTICSSRV and system DSN `HNH_Gold` created; SSAS 2025 processes through `MSDASQL` | Data source | Done 2026-10-08: driver 1.4.3 (64-bit); the user renamed the existing DSN `NewDWH` to `HNH_Gold` (ClickHouse user `bi_user`, `readonly = 2`, `max_execution_time = 600`, database `gold`). The spike processed through `MSDASQL` |
| O-S3 | Viewer identity reaches SSAS from PBIRS (`USERPRINCIPALNAME()`) | Security | Plan verifies with a published test report |
| O-S4 | List of users with `can_see_pay` / `can_see_pii` | `map_bi_user_permission` | User supplies |
| O-S5 | SSAS (and SQL engine) memory settings | Processing on a shared server | User applies the recommended values |
| O-S6 | ClickHouse user `ssas_reader` and its grants | Data source | Replaced (user, 2026-10-08): `HNH_Gold` logs in as `bi_user` (`readonly_role`: `SELECT` on every database; profile `readonly_profile`, used only by `bi_user`). Its `max_execution_time = 600` is too short (a year of charge lines took 456 s through Power Query); the user raises it to 3600 with `ALTER SETTINGS PROFILE readonly_profile` |
| O-S7 | Power BI Desktop RS May 2026 on authoring machines | Report authoring | User installs |
| O-S8 | Rows dated 2027 in charge, order and encounter facts | Data quality | Kept in the `Later` partition; raised as a data finding |
| O-S9 | Local group `HNHANALYTICSSRV\HNH_BI_Users` and its members | Role membership | Done 2026-10-08: `bi_users.csv` (user's list, not in git) → `scripts/create_bi_windows_users.ps1` created 154 local accounts, all in `HNH_BI_Users`, plus 28 department groups `HNH_BI_<dep>` and 8 branch groups `HNH_BI_Branch_<branch>` (users of the branch and users without `branch_key`; the groups are for administration and report folders, SSAS security still comes from `sec_user_access`); `scripts/load_bi_users.ps1` replaces `default.bi_users` / `default.map_bi_user_permission` with the same list (P25) |
| O-S10 | `EffectiveUserName` fails on HNHANALYTICSSRV (workgroup, no Active Directory: "your domain isn't available"), so the security tests (11.4), P14 and the PBIRS fallback in 6.3 cannot impersonate. The only `HNH_BI_Users` member is `Administrator`, an SSAS administrator, who bypasses row filters | Security tests | Spike 2026-10-08. Replacement: test queries run under the test user's own Windows logon (`LogonUser`, credential entered at run time); the user created the non-admin test account `HNHANALYTICSSRV\BI_Developer` in `HNH_BI_Users`. Spike 2026-10-08 passed with it: `USERPRINCIPALNAME()` = `login_name`, the `FALSE()` row filter and the filter through a relationship work |
| O-S11 | Through `MSDASQL` the ClickHouse ODBC driver 1.4.3 reports `Decimal` with scale 0 (1,233.5678 loads as 1,233) and `String` as `SQL_VARCHAR`, so on ANSI code page 1252 Arabic arrives as UTF-8 bytes (U+0646 loads as 217) | Amounts and Arabic text | Spike 2026-10-08: a structured ODBC data source with Power Query partitions (`Odbc.Query("dsn=HNH_Gold", <SQL>)`, the fallback in section 7) loads both correctly and faster. Model switched (P24) |

---

## 13. Out of scope (version 1)

- Repointing the existing PBIRS reports (Executive Dashboard, Outpatient, RCM Authorization, claims, Financial Statements, Order Fulfillment, Client Profile) to `HNH_Analytics`.
- New PBIRS reports.
- Arabic metadata translations (the model is English; Arabic names stay as attributes).
- Automated scheduling of dbt + processing (parent O9).
- DirectQuery, hybrid tables, aggregations over DirectQuery.

---

## 14. Decisions made while planning (2026-10-07)

These amend the sections named; the implementation plan `plans/2026-10-07-ssas-model-foundation.md` follows them.

| # | Section | Decision | Why |
|---|---|---|---|
| P1 | 3, 10 | Deploy, process and test scripts run **on HNHANALYTICSSRV** (Windows PowerShell 5.1); the developer laptop builds and validates offline. The user chose this. | The laptop has no network path to the server (name does not resolve, no port answers). |
| P2 | 4.2 rule 5 | Every `is_*`/`has_*` `UInt8` flag becomes `'Yes'`/`'No'` text; only flags that measures **sum** (e.g. `is_occupied`, `is_promoter`) stay integers (`int_flags`). | One flag column serves both slicing and measure filters; text equality on a two-value column is as fast as an integer filter. |
| P3 | 4.2 | Every integer column becomes `Int64`; a nullable non-date `*_key` becomes `-1` when null; `LowCardinality(String)` becomes `String`; `Date32` becomes `Date`. | One integer type over ODBC; a blank key would hide fact rows from every row-filtered user (blank dimension members are filtered out). |
| P4 | 4.3 | Fact **numeric** columns are hidden; fact **text and date** columns (degenerate attributes, Yes/No flags) stay visible for slicing. | Clarifies "every fact column hidden"; users must be able to slice by encounter type, claim status, etc. |
| P5 | 4.3 | Surrogate keys get `encodingHint: hash`; date and time keys `value`. | Surrogate keys are 63-bit hashes (`cityHash64 >> 1`), which value encoding stores poorly. |
| P6 | 6.2 | `Patient` (`dim_patient`) also gets a row filter: Unknown (−1) or the user's branches. | Otherwise slicers list other branches' patient ids and MRNs. The filter does not change fact totals, which are already filtered by branch. |
| P7 | 6.2 | `isAvailableInMdx: false` is set only on hidden **fact** and security columns; dimension keys keep their attribute hierarchy. | Dimension tables are small; avoids any risk on relationship "to" columns. |
| P8 | 9.1, 11 | The server scripts use the AMO/TOM object model (DLLs shipped with Tabular Editor 2) instead of hand-written TMSL, and run DAX through the MSOLAP OLE DB provider. Two extra views: `gold.ssas_etl_run_log` (processing gate) and `is_admin` kept in `gold.ssas_sec_user_access` (tests), so the grant stays `gold.ssas_*` only. `ssas_reader` uses `readonly = 2` (the ODBC driver sets session settings). | TOM refresh requests in one `SaveChanges` are one transaction; Tabular Editor 2 does not ship ADOMD.NET. |
| P9 | 9.3, 11.1 | The first yearly partition is open below (`< 2023-01-01`), so a stray earlier date is never lost. Partition coverage is tested with Pester on the partition planner and by SSAS-vs-ClickHouse row counts, instead of a dbt singular test. Measure checks are JSON files (`ssas/tests/measures/*.json`). | The planner is pure code; row counts prove the deployed result. |
| P10 | 10.1 | The Best Practice Analyzer "has a description" rule applies to tables and measures, not columns. | Column names are generated from the warehouse names. |
| P11 | 3, 10 | `ssas/tools/generate.py` writes the table, relationship, perspective, model, database and data source files from the `gold.ssas_*` columns and `ssas/tools/model_config.py`. Roles, the calculation group, measures and hierarchies are hand-written; the generator keeps measure and hierarchy blocks of existing table files. | Relationships and perspectives are derived from the same column list, so they cannot drift from the views. |
| P12 | 8 | This plan builds the model foundation with 16 starter measures (one or more per subject area, the three snapshot measures, and a `Current User` diagnostic). The full KPI catalogue (section 8.1) is a second plan. | The catalogue is about 180 measures; it is written against the deployed column names. |
| P13 | 4.3 | Where a measure name equals a column name in the same table, the column gets an explicit display name (`COLUMN_NAMES` in `model_config.py`), e.g. `headcount` → *Headcount Units*. | SSAS forbids a measure and a column with the same name in one table. |
| P14 | 11.5 | Performance queries run as a single-branch user (under that user's own logon, O-S10), not as an administrator. | Server administrators bypass row filters, so timings without a user would miss the security cost. |
| P15 | 6.2 | The Staff filter matches specialty only (no branch match). **Confirmed by the user on 2026-10-08:** each employee has one staff record, in the branch of their last assignment (`bridge_employee_staff`), and each month's HR row keeps the branch the person worked in that month. | HR facts reference staff of other branches (611 headcount, 1,147 payroll rows): 107 of the 110 employees are transfers whose earlier months point to the staff record of their new branch. The other 3 are a Fusion mismatch: the legal employer of the latest period of service differs from the assignment's; they are a data finding. Facts stay branch-secured through Branch; unrestricted users can list other branches' staff names. |
| P16 | 4.2 | order_key dropped; an Orders count needs a gold flag (catalogue plan) | Spec 4.2 rule 3 drops order ids from the big line facts; `order_key` had 22.7M distinct 63-bit values on 58.8M rows |
| P17 | 10.2 | Validate runs the Best Practice Analyzer only, without TE2's `-SC` schema check; schema drift is caught by the enforced dbt contracts and by the Test stage. | TabularEditor.exe is 32-bit and opens the model's ODBC data source in-process; the server has only the 64-bit ClickHouse ODBC driver and DSN. |
| P18 | 4.2 | An amount that is not finite or has abs ≥ 1e14 loads as blank (`hnh_ssas_column`); `warn_ssas_amount_out_of_range` lists the source rows (15 order lines, 2 pre-auth lines at the 2026-10-07 build) | SSAS fixed decimal cannot hold them; they are source typos (e.g. 3.3e24 units) to fix in Oasis |
| P19 | 8 | `Response Rate %` = responded ÷ primary invitations; `Patient Collections` = Σ receipt_amount over Receipt and Cancellation; `Headcount` = last closed month (`is_closed_month`) | The receiving notes are binding and supersede the older phase-spec wording |
| P20 | 8.2.4 | Snapshot measures (Headcount, Stock Value, GL Closing Balance) take the last period of each branch and add the branches | Branches end on different periods; one group-wide maximum dropped branches from totals |
| P21 | 9.3 | `fact_invoice` is partitioned on `invoice_date_key` | Listed as large in 9.3; the first plan draft missed it |
| P22 | 1, 12 | The ClickHouse user `ssas_reader` is created by the user (`scripts/create_ssas_reader.py`, password from `HNH_SSAS_READER_PASSWORD`); the server probe (`ssas/spike/spike.ps1`) and the first deployment (plan Task 16) are run by the user on HNHANALYTICSSRV | The password and the server are the user's; the laptop cannot reach the server |
| P23 | 1, 10 | HNHANALYTICSSRV is the production server, and the working copy (`D:\new_dwh_modeling`) is now on it; scripts run from there. Anything that changes the SSAS instance, the server or ClickHouse needs the user's go-ahead each time (`CLAUDE.md`) | The same instance serves PBIRS users (D5); recorded 2026-10-08 |
| P24 | 9.1, 9.2 | The data source is a structured ODBC source and every partition an M partition `Odbc.Query("dsn=HNH_Gold", <SQL>)` (the 9.1 fallback), instead of `MSDASQL` query partitions. `hnh_tmdl.odbc_expression` and `ConvertTo-HnhOdbcExpression` build the same text; `Sync-HnhPartitions` compares whole expressions | Spike 2026-10-08: through `MSDASQL` the ClickHouse ODBC driver 1.4.3 loses decimal fractions and garbles Arabic (O-S11); Power Query loads both correctly and was faster on 14.1M charge lines (456 s; `MSDASQL` passed 600 s without finishing) |
| P25 | 6.1, 6.2 | The BI users source is `bi_users.csv` (login, department, branch, specialty, `is_admin`, `can_see_pay`, `can_see_pii`), loaded into `default.bi_users` and `default.map_bi_user_permission` by `scripts/load_bi_users.ps1`; the dbt models are unchanged. A user without `branch_key` sees every branch (user, 2026-10-08): the loader sets `IsAdmin = 1`, so `sec_user_access` grants all branches and Head Office while keeping the specialty and pay/PII rules | One list drives the Windows accounts and the warehouse grants; the old `ALWAFA\…` rows are kept in `*_backup_<timestamp>` tables |
| P26 | 4.3, 7 | Every measure lives in one table `_Measures` (user, 2026-10-08), display folder `<domain>\<topic>` with the domain a perspective name or `Diagnostics`. `_Measures` is an import table with an empty Power Query partition `#table(type table [Measure = text], {})` and one hidden column, not a calculated table (`HNH_NO_CALCULATED_TABLES`). A perspective lists the `_Measures` measures of its domain plus Diagnostics; Executive shows all, Patient Details shows Patient Flow and Revenue Cycle (`PERSPECTIVE_MEASURE_DOMAINS`) | One place to find a measure; with measures off the fact tables, a perspective must name its measures, so the folder domain drives it |

Parked for the KPI catalogue plan or the server run: the processing gate also accepts a `dbt run` (no tests) because `etl_run_log` does not record the command; the Arabic-text test is weak; the size test reads `EstimatedSize`, not the VertiPaq total; the specialty user's branch-wide fact rows are not checked; the out-of-range warning covers only two columns.
