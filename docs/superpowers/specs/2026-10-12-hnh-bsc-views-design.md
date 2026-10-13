# HNH Data Warehouse — Balanced Scorecard (`bsc`) Views on the New Server

- **Date:** 2026-10-12
- **Status:** Approved 2026-10-12. Implemented 2026-10-12 (plan `docs/superpowers/plans/2026-10-12-bsc-views.md`); built on 172.22.25.214; reconciliation in `docs/reconciliation_bsc.md`. Report not yet repointed.
- **Parent specs:**
  - `2026-10-01-hnh-dwh-gold-layer-design.md`: architecture, keys, conventions. Everything in it applies unless this document says otherwise.
  - Phase 1 (patient flow), Phase 2 and 2b (revenue, claims, pre-authorisation), Phase 3 (finance), Phase 4 (workforce).
  - `2026-10-07-hnh-ssas-tabular-model-design.md`: the SSAS measures whose definitions these views follow.
- **Inputs:**
  - `old_dwh_views_definition.csv`: the old warehouse's view DDL (git-ignored).
  - `oasis sample queries for business logic and relations understanding/`: the Oasis extract scripts (git-ignored).

---

## 1. Purpose and decisions

The balanced-scorecard Power BI report reads the `bsc` database on the old ClickHouse server (`172.22.25.165`):
- 10 views;
- 2 hand-loaded tables.

Those views read Oasis only. From each branch's Oracle Fusion go-live in 2026, finance, payroll and supply figures are missing or wrong. For example, the September 2026 headcount for Ghirnata is 76 against about 304 real staff.

This design re-creates the same 12 objects on the new server (`172.22.25.214`), built on the `gold` layer:
- same database name;
- same object names;
- same column names and types.

`gold` already merges Oasis and Fusion. The scorecard then needs only a connection change.

Usage on the old server over the last 30 days, from `system.query_log` (users `default` and `pwc`, ODBC):

| Object | Queries |
|---|---|
| `vw_financial` | 151 |
| `vw_customer` | 134 |
| `vw_income_statement_budget` | 89 |
| `vw_hospital_beds_utilization`, `patient_satisfaction`, `vw_hospital` | 47 each |
| `vw_rcm` | 46 |
| `targets` | 44 |
| `vw_work_force` | 7 |
| `vw_gl_transactions`, `vw_gl_openning_balance` | 2–3 each |

Decisions made in review (2026-10-12):

| # | Decision |
|---|---|
| B1 | **Drop-in replacement.** Database `bsc`, the same 12 object names, the same column names and ClickHouse types. The report changes only its host. |
| B2 | **The new `bsc` lives on the new server (`.214`), built on `gold`.** The old `bsc` on `.165` stays untouched until the report is switched and the old server retired. |
| B3 | **Corrected definitions.** Every column follows the SSAS `HNH_Analytics` measure for the same KPI, not the `legacy_*` fields. Where SSAS has no measure, the column keeps the old meaning computed on corrected gold data. Scorecard values for 2025–2026 will move; section 9 reconciles them. |
| B4 | **Oasis GL is combined with Fusion GL** through a new gold table `fact_gl_fs_monthly`. The Oasis GL (`oasis.gl_distribution`) was ingested on 2026-10-12, with models `stg_oasis__gl_*`, `gold.fact_oasis_gl_line` and `gold.dim_oasis_gl_account`. |
| B5 | **One GL source per branch and month**, chosen by a reference table `default.map_gl_cutover` (`branch_id`, `first_fusion_gl_month`). Before that month every account comes from Oasis; from it, every account comes from Fusion. A branch with no row stays on Oasis. |
| B6 | **dbt models in `hnh`, deployed as views in database `bsc`**, configured like the `ssas` views (definer security), with enforced contracts. Approaches rejected: nightly `bsc` tables (little gain: the slowest view runs in about 6 s) and hand-written DDL (no tests, no lineage). |
| B7 | **`targets` and `patient_satisfaction` become reference tables** in `default`, loaded with `load_reference_data.py`. They are exposed as `bsc.targets` and `bsc.patient_satisfaction` views. |
| B8 | **Branches 1–8 only.** Group (0) and Head Office (100) are excluded, as in the old views. |

---

## 2. Findings that shape the design

| # | Finding | Consequence |
|---|---|---|
| F1 | Gold `branch_key` 1–8 equals the old `default.branch.id`, and branch names are identical. Gold also has 0 (Group) and 100 (Head Office). | Output `toUInt64(branch_key)` and filter `branch_key BETWEEN 1 AND 8`. |
| F2 | Phase 3 finance is Fusion-only (Phase 3 spec, F1). Alrabwah has no Fusion journals. Khamis and Madinah have only their August go-live batch. | Finance needs the Oasis GL (B4). |
| F3 | After go-live, Oasis keeps posting **revenue** through the Oasis-to-Fusion feed, so the same revenue shows in both systems. **Costs stop** in Oasis. | Adding the two sources together double counts revenue. Each branch-month takes exactly one source (B5). |
| F4 | Measured 2026 transitions. Ghirnata: Fusion from January (Oasis revenue duplicates it). Abha: May. Muhayil: June. Jazan: July, with costs split across both systems in July. Unaizah: August, with costs split in August. Khamis and Madinah: September (go-live batch in August). Alrabwah: none. | Initial `map_gl_cutover` values (section 5.1). The costs that stayed in Oasis in the split months are lost until finance confirms the dates (O-B5). |
| F5 | The Fusion FS hierarchy (`gold.dim_fs_line`, lower-cased) uses the same vocabulary as the old `fs_mapping`, which `gold.dim_oasis_gl_account` carries for Oasis accounts. There are four differences. (a) Fusion has a category `depreciation and amortization`; Oasis keeps depreciation captions under `direct cost`. (b) Oasis medicines are caption `cost of goods sold`; Fusion's are `cost of medicines`. (c) Fusion revenue captions are by payer (`revenue cash`, `revenue insurance companies`, …); Oasis's are `revenue inpatient` and `revenue out patient`. (d) Fusion has `charges from head office` and `not mapped`; Oasis has elements `expected credit loss` and `oci`. | The `vw_financial` filters are written at element, category and caption level, with value lists that cover both vocabularies (section 6.3). |
| F6 | Two old `vw_financial` filters never matched. `'depreciation On Rou'` was compared with lower-cased text, and `'deprecition'` is misspelt. Old `operating_expenses` therefore included most depreciation. | Corrected (section 6.3). |
| F7 | The old opening balances summed over every *open* period, so they double counted when two fiscal years were open (Phase 3, G13). `vw_financial` took opening balances with `lagInFrame`, which gives 0 on a branch's first row and is wrong across missing months. | Opening balances are rolled per fiscal year (section 5.2). |
| F8 | `gold.agg_clinic_capacity_daily.slots_total` counts every appointment-template row, about 144 per doctor-day. Khamis, August 2026: 3.0M slots against 18K visits. `legacy_capacity_slots` holds the old capacity rule. | `available_slots` uses `legacy_capacity_slots`. SSAS `Clinic Utilisation %` has the same defect (O-B3). |
| F9 | Every `gold.fact_claim_line` row has been sent to NPHIES, so the old "not submitted" (an AR-statement status) has no equivalent. | `not_submitted_claims` becomes the amount pending adjudication (section 7.4). |
| F10 | Fusion leaver reasons are not maintained for branches 1–5. 2026 Fusion voluntary leavers by branch 1–8: 1, 4, 4, 4, 0, 29, 42, 4. Oasis staff termination for the same branches: 49, 23, 11, 15, 26, 26, 40, 0, which reproduces the old column exactly. | Resignations come from Oasis for branches 1–5 and from Fusion for 6–8 (section 7.5). |
| F11 | `budget.income_statement_line_items` (line names and categories, 48 rows) exists only on the old server. The budget values are identical on both servers: 576 rows, FY2026, branches 1–6. | Load the line items as `default.map_budget_line_item`. |
| F12 | The new server already has `default.date_dim`, identical to the old one. The old `FiscalYear` is Year + 1 for every month, and `FiscalMonth` starts at December. | `vw_date_dim` is built on `gold.dim_date` and reproduces the old values, odd fiscal columns included (section 7.1). |
| F13 | The Oasis GL models (`stg_oasis__gl_*`, `fact_oasis_gl_line`, `dim_oasis_gl_account`) exist on the server but not in this repository. | They are read through a switch macro, like Oasis and Fusion (section 4.2). Their code is brought into the repository (O-B1). |

---

## 3. Scope

**In scope:**
- 12 `bsc` views;
- one new gold table, `fact_gl_fs_monthly`;
- four reference tables;
- contract and unit tests;
- a read-only comparison script;
- an update to `docs/receiving_project_config.md`.

**Out of scope:**
- Changing the scorecard report. Only its connection host changes, and the report owner does that.
- Adding Oasis GL months to the SSAS model. `fact_gl_fs_monthly` makes this possible later; it is a separate change.
- Rebuilding `targets` and `patient_satisfaction` from Press Ganey or the budget. They stay hand-loaded.
- The other old-server databases (`budget`, `default` views).

---

## 4. Components

### 4.1 Layout

```
oasis.gl_distribution ─► gold.fact_oasis_gl_line ──┐
                         gold.dim_oasis_gl_account ┤
gold.fact_gl_balance_monthly ─┐                    ├─► gold.fact_gl_fs_monthly ─► bsc.vw_gl_transactions
gold.dim_gl_account, dim_fs_line, dim_gl_period ───┤                              bsc.vw_gl_openning_balance
default.map_gl_cutover ────────────────────────────┘                              bsc.vw_financial ◄─ gold.fact_income_statement_monthly (budget)
gold facts ─► bsc.vw_customer, bsc.vw_rcm, bsc.vw_work_force, bsc.vw_hospital_beds_utilization
gold.dim_branch, gold.dim_date ─► bsc.vw_hospital, bsc.vw_date_dim
default.bsc_targets, bsc_patient_satisfaction ─► bsc.targets, bsc.patient_satisfaction
gold.fact_budget_monthly + default.map_budget_line_item + default.income_statement_budget ─► bsc.vw_income_statement_budget
```

### 4.2 dbt layout

- `hnh_dwh/models/hnh/marts/finance/fact_gl_fs_monthly.sql`: a table in `gold`, built by the existing `marts` config.
- `hnh_dwh/models/hnh/marts/bsc/`: 12 models named `bsc_<object>.sql`, each with `alias='<object>'`. For example, `bsc_vw_customer` is built as `bsc.vw_customer`. dbt model names must be unique across the project, the same reason as `hnh_dim_branch`.
- `hnh_dwh/models/hnh/marts/bsc/_bsc__models.yml`: column docs plus enforced contracts. The contracts are generated from the **old** server's `system.columns` by `scripts/gen_bsc_contracts.py`, which reads the old server only, through DSN `chDWH`.
- `dbt_project.yml`, under `marts:`:

  ```yaml
  bsc:
    +schema: bsc
    +materialized: view
    +sql_security: definer
    +definer: CURRENT_USER
    +tags: ["hnh_bsc"]
  ```

  `generate_schema_name` puts `+schema: bsc` in database `bsc`, as it does for `stg`, `int` and `gold`.
- New var `hnh_oasis_gl_as_ref` (default `false`) and macro `hnh_oasis_gl_source(name)`. They return `ref(name)` when the var is true (receiving project) and `source('gold_oasis_gl', name)` otherwise (this repository). This follows `hnh_fusion_source`. It is removed when the model code is brought into `hnh_dwh/` (O-B1).

### 4.3 Reference tables (`default`, loaded by `scripts/load_reference_data.py`)

| Table | Rows | Source | Columns |
|---|---|---|---|
| `map_gl_cutover` | 7 | Section 5.1, reviewed by finance | `branch_id UInt8`, `first_fusion_gl_month Date`, `note String` |
| `map_budget_line_item` | 48 | Export of `budget.income_statement_line_items` from the old server | As the old table (`code`, `name`, `category`, …) |
| `bsc_targets` | 3,024 | Export of `bsc.targets` from the old server | As the old table |
| `bsc_patient_satisfaction` | 56 | Export of `bsc.patient_satisfaction` from the old server | As the old table |

- The CSVs go to `static_mappings/` (git-ignored, like the other data exports).
- Whoever maintains the targets and satisfaction sheets today reloads these two tables on the new server after the switch (O-B7).
- The loader never overwrites: a reload truncates the table first.

---

## 5. `gold.fact_gl_fs_monthly`

**Grain:** branch × month × source system × account.

**Window:** from `hnh_history_start_date` (2022-01-01) to the last month with a posting.

**Rows:** only where any amount is non-zero.

| Column | Type | Meaning |
|---|---|---|
| `branch_key` | UInt8 | 1–8 |
| `month_start` | Date | Month. A Fusion adjustment period folds into the last month of its quarter, as in `fact_income_statement_monthly`. |
| `source_system` | LowCardinality(String) | `oasis` or `fusion` |
| `account_code` | String | Oasis `oasis_account` (main + sub account) or the Fusion account combination |
| `fs_type`, `fs_element`, `fs_category`, `fs_caption`, `fs_line` | LowCardinality(String) | Lower-cased, `''` when unmapped. Oasis values come from `dim_oasis_gl_account`, Fusion values from `dim_fs_line`. |
| `opening_balance` | Float64 | Balance at the start of the month (debit positive) |
| `movement` | Float64 | Month movement, excluding brought-forward rows (Oasis) and go-live opening-balance journals (Fusion) |
| `opening_journal_amount` | Float64 | Oasis brought-forward and retained-income rows (`is_brought_forward = 1`); Fusion go-live opening-balance journals (`period_movement − period_movement_excl_opening`) |
| `closing_balance` | Float64 | `opening_balance + opening_journal_amount + movement` |

### 5.1 Source selection

A row from source S for branch b and month m is kept when:
- `S = 'fusion'` and `map_gl_cutover` has a row for b with `first_fusion_gl_month ≤ m`; or
- `S = 'oasis'` and there is no such row (no row for b, or `m < first_fusion_gl_month`).

Initial `map_gl_cutover`:

| branch_id | Branch | first_fusion_gl_month | Note |
|---|---|---|---|
| 2 | Khamis | 2026-09-01 | Go-live batch August |
| 3 | Jazan | 2026-07-01 | Costs split across both systems in July (O-B5) |
| 4 | Unaizah | 2026-08-01 | Costs split across both systems in August (O-B5) |
| 5 | Madinah | 2026-09-01 | Go-live batch August |
| 6 | Abha | 2026-05-01 | |
| 7 | Ghirnata | 2026-01-01 | Oasis revenue before this date duplicates Fusion |
| 8 | Muhayil | 2026-06-01 | |

Alrabwah (1) has no row, so it stays on Oasis.

### 5.2 Amounts

**Oasis:**
- Lines: `gold.fact_oasis_gl_line` with `is_posted = 1`.
- Within fiscal year Y (the calendar year), for every account:
  - `opening_journal_amount(m)` = Σ brought-forward rows of month m;
  - `movement(m)` = Σ other rows of month m;
  - `opening_balance(m)` = Σ brought-forward rows of Y in months before m + Σ movements of Y in months before m.
- Income-statement accounts have no brought-forward rows, so they reset each year. Balance-sheet accounts carry their year-open balance.
- This is the old `vw_gl_openning_balance` logic restricted to one fiscal year, which removes the double count (F7).
- The plan's first task checks that it holds: closing balance at December = opening balance plus brought-forward at January, for every balance-sheet account (test 9.2).

**Fusion:**
- Source: `gold.fact_gl_balance_monthly` with `balance_view = 'including_unposted'`, through `dim_gl_account → dim_fs_line` and `dim_gl_period`.
- Columns:
  - `opening_balance` = `opening_balance` of the non-adjustment period;
  - `movement` = `period_movement_excl_opening`;
  - `opening_journal_amount` = `period_movement − period_movement_excl_opening`.
- "Including unposted" is used because Oasis-feed batches stay unposted in Fusion. The posted view shows almost no revenue: Jazan, July 2026, posted −2.8M against 21.0M including unposted.

**At a branch's cutover month:**
- Oasis balance-sheet balances stop.
- Fusion opens from its go-live batch, which sits in `opening_journal_amount` of the go-live month.
- Balance-sheet continuity across the cutover is not enforced. It is reported per branch in the reconciliation (section 9.3).

---

## 6. Finance views

### 6.1 `bsc.vw_gl_openning_balance`

Grain: `BranchId` × `Period` × `AccountType` × FS levels. It is grouped from `fact_gl_fs_monthly`.

| Column | Type | Expression |
|---|---|---|
| `BranchId` | UInt64 | `toUInt64(branch_key)` |
| `Period` | Nullable(Date32) | `month_start` |
| `AccountType` | LowCardinality(String) | `upper(fs_type)`: `'BS'` or `'IS'`, upper case like the old `TYPE` (the old view did not lower-case it, and `vw_financial` consumers filter on `'IS'`) |
| `FS_ELEMENT` … `FS_LINE` | LowCardinality(String) | `fs_element` … `fs_line` |
| `OpeningBalance` | Decimal(38,10) | Σ `opening_balance` |
| `forwarded_balance` | Decimal(38,10) | Σ `opening_journal_amount` |

### 6.2 `bsc.vw_gl_transactions`

Same grain and columns as 6.1. The window is `toYear(month_start) >= toYear(yesterday()) − 2`, as old.

| Column | Expression |
|---|---|
| `Transaction_Balance` | Σ `movement`. Debit positive, so revenue is negative, as old. |
| `OpeningBalance` | Σ (`opening_balance` + `opening_journal_amount`) |

`OpeningBalance + Transaction_Balance` = closing balance.

### 6.3 `bsc.vw_financial`

Grain: branch × `month_date`. Actuals come from `fact_gl_fs_monthly`, filtered with the shared value lists below (F5). Months come from both sources, each branch-month from one source.

| Column | Expression |
|---|---|
| `net_revenue_actual` | −Σ `movement` where `fs_element = 'revenue'` |
| `sub_revenue_actual` | −Σ `movement` where `fs_element = 'revenue'` and `fs_caption != 'revenue - settlement discount'` |
| `operating_expenses` | Σ `movement` where `fs_element = 'expenses'`, `fs_category NOT IN ('finance cost', 'zakat', 'depreciation and amortization')` and `fs_caption NOT IN ('depreciation', 'depreciation on rou', 'amortization of intangible assets', 'depreciation expense', 'amortization expense')`. Head Office charges and unmapped expenses stay in, as old (element `expenses`). |
| `ebitda_actual` | `net_revenue_actual − operating_expenses` |
| `account_receivable_actual` | Σ `closing_balance` where `fs_caption = 'trade receivables, net'` |
| `account_receivable_actual_opening_balance` | Σ (`opening_balance` + `opening_journal_amount`) for the same caption |
| `ga_expenses_actual` | Σ `movement` where `fs_category = 'general and administrative expenses'` |
| `consumables_actual` | Σ `movement` where `fs_caption = 'medical consumables'`. Cost of goods sold (Oasis) and cost of medicines (Fusion) are not consumables (user, 2026-10-13). Fusion has no consumables caption yet, so Fusion months show 0 until finance maps one (O-P3-8). |
| `assets` | Σ `closing_balance` where `fs_element = 'assets'` |
| `assets_opening_balance` | Σ (`opening_balance` + `opening_journal_amount`) where `fs_element = 'assets'` |
| `income` | −Σ `movement` where `fs_type = 'is'` |
| `net_revenue_budget` … `consumables_budget` | `gold.fact_income_statement_monthly.budget_most_likely`. Lines: `REV_NET`; `REV_SUB`; `TOTAL_DC + TOTAL_GA`; `EBITDA`; `TOTAL_GA − GA_MARKETING`; `DC_CONSUMABLES` (the old view also added `Cost Of Medicines`; dropped 2026-10-13 so budget and actual compare the same thing). NULL when the branch-month has no budget. |

- Actuals and budget are joined with a `FULL OUTER JOIN` on (branch, month). Months that have only a budget (October–December 2026) appear; the old `ANY LEFT JOIN` dropped them.
- Window: from January two years back, as old.
- Decimal columns: `CAST(round(x, 2) AS Decimal(38,10))`. A plain cast of Float64 shows binary noise.

### 6.4 `bsc.vw_income_statement_budget`

| Column | Expression |
|---|---|
| `branch_id` UInt32, `fiscal_year` Int32, `line_item_code` | From `gold.fact_budget_monthly` (`scenario = 'most_likely'`) |
| `line_name`, `category` | `default.map_budget_line_item` on `code = line_item_code` |
| `assumption_percentage` | `default.income_statement_budget` (`is_latest`, `scenario = 'most_likely'`) |
| `month_date` Date | `month_start` |
| `month_value` Nullable(Decimal(18,2)) | `CAST(round(budget_amount, 2) AS Nullable(Decimal(18,2)))` |

---

## 7. Operational views

The common window is from `subtractYears(toStartOfYear(yesterday()), 1)` to `yesterday()`, evaluated at query time as in the old views. Months are `toStartOfMonth` of the fact's date key.

### 7.1 `bsc.vw_hospital`, `bsc.vw_date_dim`

- **`vw_hospital`:**
  - `Id = toUInt64(branch_key)`;
  - `Hospital = branch_name`;
  - `City = city`, from `gold.dim_branch`, branches 1–8.
  - Khamis's city becomes `Aseer` (old: `Asser`).
- **`vw_date_dim`:**
  - Built on `gold.dim_date`, from the start of the year five years back to `today()`.
  - All 33 old columns, with the expressions verified against the old view (2,111 rows, 0 mismatches).
  - `FiscalYear = year + 1`, `FiscalMonth = month % 12 + 1`, `FiscalQuarter = intDiv(month % 12, 3) + 1`, as old.
  - Offsets are `dateDiff(unit, date_day, today())`. They are not taken from gold's build-time offsets.

### 7.2 `bsc.vw_customer` (branch × month)

All branches × all months in the window, as old. The charge-line payer is the **episode payer** (`episode_payer_key → dim_payer`).

| Column(s) | Source and expression | SSAS measure |
|---|---|---|
| `revenue` | `fact_charge_line`, Σ `revenue_amount` by `delivery_date_key` | Revenue |
| `op_revenue`, `non_ltc_ip_revenue` | `care_type_key = 1`; `care_type_key = 3 AND is_ltc = 0` | Revenue × Care Type, × Is LTC |
| `ancillary_services_revenue` | OP and `dim_product_category.category_code IN ('MD','MED','CSM','RTL','MLK','PH','LAB','RAD')` | — |
| `non_moh_revenue`, `insurance_revenue`, `credit_revenue` | Episode payer: `is_moh = 0`; `category = 'Insurance'`; `billing_type = 'Credit'` | Revenue by Episode Payer |
| `referrals_revenue` | `fact_episode.is_referral_policy = 1` on `episode_key` | — |
| `high_value_service_revenue` | `dim_staff.is_high_value_specialty = 1` on `staff_key` | — |
| `census`, `op_census`, `er_census` | `fact_encounter` by `encounter_date_key`. OP: `is_arrived = 1 AND is_cancelled = 0`. ER: `is_cancelled = 0`. | Census, OP Visits, ER Visits |
| `insurance_census` | Census with `dim_payer.category = 'Insurance'` on `payer_key` | — |
| `distinct_patients`, `returning_patients` | `uniqExact(patient_key)` of arrived, non-cancelled OP and ER; also `is_returning = 1` | Unique Patients, Returning Patients |
| `new_op_census` | OP, arrived, `visit_type = 'New patient'` | New Patients (OP) |
| `op_episodes` | `fact_episode` by `start_date_key`, `care_type_key = 1 AND has_arrived_non_follow_up_encounter = 1` | Episodes (OP) |
| `op_waiting_time_in_minutes` | Σ `wait_minutes`, OP, arrived, not cancelled. A sum; the report divides it by `op_census`. | Total Wait (min), OP |
| `high_value_service_volume` | Census with `is_high_value_specialty` on **`booked_staff_key`**, plus countable admissions with a high-value `consultant_staff_key` | — |
| `referrals_volume` | Census plus admissions with an episode referral policy | — |
| `available_slots` | `agg_clinic_capacity_daily`, Σ `legacy_capacity_slots` (F8) | — |
| `admissions`, `readmission_within_30days`, `readmitted_to_ICU_with_48hrs`, `insurance_admissions` | `fact_admission`, `is_countable = 1`, by `admit_date_key`: count; `is_readmission_30d`; `is_icu_readmission_48h`; payer category Insurance | Admissions, Readmission Rate 30d % (numerator), ICU Readmissions 48h |
| `discharges`, `icu_discharge`, `alos_non_ltc` | `fact_admission`, countable, by `physical_discharge_date_key`: count; last bed `dim_bed.is_critical = 1` on `last_bed_key` (O-B4); `ifNull(avgIf(los_days, is_ltc = 0), 0)` | Discharges, ALOS (days) × Is LTC = No |
| `*_target` | `fact_target_daily`, `scenario = 'most_likely'`, with the old filters on `creditor`, `care_type_key` and `stay_type`. `ancillary_revenue_target = op_revenue_target × 0.6`, as old. | Target Revenue, Target Census, Target Episodes |

- Rounding of targets and the casts to `UInt64`, `Decimal(38,10)`, `Decimal(38,20)`, `Nullable(Int64)` and `Float64` are as old.
- A draft SELECT returning the old column types exists and runs in about 6 s. It returns 176 rows (8 branches × 22 months).

### 7.3 `bsc.vw_hospital_beds_utilization` (branch × month, months with census > 0)

| Column | Expression | SSAS |
|---|---|---|
| `available_beds` | `toUInt64(round(sum(is_available) / uniqExact(date_key)))` from `fact_bed_occupancy_daily` where `is_inpatient_ward = 1 AND is_excluded_ward = 0`. The month's average, not today's count. | — |
| `census`, `ltc_census` | `fact_admission`, `is_countable = 1`, stays overlapping the month; `is_ltc_to_date = 1` | — |
| `alos`, `ltc_alos`, `non_ltc_alos` | `avg(los_days)` of the month's countable discharges, `ifNull(…, 0)`; `avgOrNullIf` by `is_ltc` | ALOS (days) |
| `total_bed_nights` | `toInt64(sum(is_occupied))` from the occupancy fact, same filter | Bed Occupancy % numerator |
| `available_bed_nights` | `toFloat64(sum(is_available))` | Bed Occupancy % denominator |
| `occupancy_rate` | `total_bed_nights / available_bed_nights` | Bed Occupancy % |

### 7.4 `bsc.vw_rcm` (branch × month, union of claim and pre-authorisation months)

**Claims** (`fact_claim_line`):
- Month: the statement month (`statement_end_date_key`).
- L means `is_latest_submission = 1 AND is_cancelled_claim = 0`.

| Column | Expression | SSAS |
|---|---|---|
| `total_submitted_claims` | Σ `claimed_amount` where `is_sent = 1` and L | Claims Submitted |
| `not_submitted_claims` | Σ `claimed_amount` where L and the claim is pending adjudication (the filter of `rec_claims_monthly.pending`) | — |
| `approved_amount` | Σ `ifNull(approved_amount, 0)`, L | Claims Approved |
| `rejections` | Σ `ifNull(rejected_amount, 0)`, L | Claims Rejected |
| `rejection_rate_pct` | `round(100 × rejections / adjudicated submitted, 2)` | Claim Rejection Rate % |
| `approval_rate_pct` | `round(100 × approved_amount / adjudicated submitted, 2)` | — |

**Pre-authorisation** (`fact_preauth_line`):
- Month: `request_date_key`.
- Every column filters `line_source != 'Payer advance'`.

| Column | Expression | SSAS |
|---|---|---|
| `total_orders` | count | Pre-auth Services |
| `approved_orders` | `is_approved = 1 AND has_final_response = 1` | Pre-auth Approval Rate % numerator |
| `approved_not_done`, `approved_not_done_pct` | `is_approved_not_delivered = 1`; `round(100 × approved_not_done / total_orders, 2)` | Unutilised Approvals, Unutilised Approval Rate % |
| `avg_tat_minutes` | `round(avg(sent_to_response_minutes), 1)` | Sent to Response Avg (min) |

Known data gaps show as they are:
- Branches 6 and 8 have NPHIES pull gaps (O-P2B-9). In August 2026, branch 6 had 13.3M SAR pending out of 16.0M submitted.
- Branches 7 and 8 have NPHIES pulls only from 2026-10-04.

### 7.5 `bsc.vw_work_force` (month × branch)

**Spine:**
- Branches 1–8 × months from January of last year to the last **closed** month.
- The current month is empty until it closes, as in SSAS.

| Column | Expression |
|---|---|
| `headcount` | From 2026: `fact_headcount_monthly`, Σ `headcount` where `is_contingent = 0`. Before 2026: paid people in `fact_payroll_monthly` (`is_parallel_run = 0`, gross pay > 0). Plus `pt_doctors_headcount`. |
| `pt_doctors_headcount` | Doctors (`dim_staff.category = 'DOCTORS'`) with revenue > 0 in `fact_charge_line` in the month whose staff record is neither in that month's headcount nor in payroll with gross pay > 0 |
| `medical_headcount`, `doctors_headcount` | As headcount, restricted to `dim_staff.classification IN ('NURSE', 'DOC')` or `category = 'DOCTORS'` (Fusion employees through `staff_key`), plus `pt_doctors_headcount` |
| `resignations` | Branches 1–5: `dim_staff` with `termination_reason = 'Resignation'`, by termination month. Branches 6–8: `fact_worker_movement.is_voluntary_leaver = 1`, by action month (F10). |
| `FTE` | Σ `fte` (from 2026; 1 per paid person before) + 0.5 × `pt_doctors_headcount` |

Fusion employees with no staff link (`staff_key = -1`, 0–22 per branch) count in `headcount` but in neither the medical nor the doctors column.

### 7.6 Shared notes

- Joins use `join_use_nulls = 0`, so a branch-month with no activity gives 0, as in the old views.
- Every view sets the old column types explicitly. The enforced contract (section 4.2) fails the build on any difference.

---

## 8. Error handling and freshness

- **Freshness:** the views read gold tables, so they are as fresh as the last `dbt build --select tag:hnh`. The scorecard reads them live, like the old views.
- **Window:** `yesterday()` and `today()` are evaluated at query time.
- **A branch added later:**
  - It gets rows once it has data.
  - It is excluded until the `BETWEEN 1 AND 8` filter is widened. That is a deliberate edit, so Head Office never appears by accident.
- **A cutover date changed by finance:** reload `map_gl_cutover` and rebuild `fact_gl_fs_monthly`. No code change.
- **A failed gold build:** the views keep reading the previous tables (`etl_run_log` gate, as for SSAS).

---

## 9. Testing and acceptance

1. **Unit tests** (dbt `unit_tests`):
   - `fact_gl_fs_monthly` source selection:
     - a branch with no cutover row;
     - the month before cutover;
     - the cutover month;
     - Fusion data before cutover is dropped.
   - The Oasis opening roll:
     - a balance-sheet account carries forward across a year end;
     - an income-statement account resets.
   - `vw_financial`:
     - the operating-expense exclusion list on both vocabularies;
     - the consumables caption list.
   - `vw_work_force`:
     - the part-time doctor rule (in payroll or headcount means not part-time);
     - the resignation source split.
2. **Data tests:**
   - Balance-sheet continuity of Oasis lines (December closing = January opening + brought forward) per branch and account, from 2022.
   - `fact_gl_fs_monthly` has one source per branch-month.
   - `bsc` views have no duplicate branch-month keys.
   - The enforced contracts.
3. **Side-by-side comparison:**
   - `scripts/compare_bsc.py` is read-only. It reads both servers (DSNs `chDWH` and `HNH_Gold`) for August 2026 and the whole of 2025, for every view and numeric column.
   - It writes `docs/reconciliation_bsc.md`. Every difference above 0.5% is either attributed to a numbered correction (B3, F6–F10, section 7) or listed as unexplained.
   - **Acceptance:**
     - no unexplained difference;
     - Oasis-only months of `vw_gl_transactions` (2025) equal the old view, except accounts affected by the G13 double count;
     - `vw_hospital`, `vw_date_dim`, `targets` and `patient_satisfaction` are identical.
4. **Offline checks:**
   - `python -m pytest ssas/tools` still passes; the SSAS model is unchanged.
   - `dbt parse` succeeds in this repository.

---

## 10. Deployment

Every step that changes a server waits for the user's go-ahead (CLAUDE.md).

1. Bring the Oasis GL model code into `hnh_dwh/`, or confirm it stays in the receiving project and set `hnh_oasis_gl_as_ref: true` there (O-B1).
2. Load `map_gl_cutover`, `map_budget_line_item`, `bsc_targets` and `bsc_patient_satisfaction` on `.214`.
3. Copy the models into the receiving project (`docs/receiving_project_config.md` gains a `bsc:` block and the new var), then run `dbt build --select tag:hnh`. dbt creates database `bsc`.
4. Grant the scorecard's ClickHouse login `SELECT` on `bsc.*`. The definer views need nothing else. The login's name and creation are the user's decision (O-B2).
5. Run `scripts/compare_bsc.py` and review `docs/reconciliation_bsc.md`.
6. The report owner repoints the scorecard data source from `.165` to `.214` in Power BI Report Server and compares the pages.
7. The old `bsc` on `.165` is left as it is until the old server is retired.

---

## 11. Open items

| # | Item | Owner |
|---|---|---|
| O-B1 | Where is the code of `stg_oasis__gl_*`, `fact_oasis_gl_line` and `dim_oasis_gl_account`? Bring it into `hnh_dwh/` or keep it in the receiving project. The plan's first task also checks that `fact_oasis_gl_line` applies the old filters (`C_ID = 36`, `STATUS = 'P'`, latest `VERSION`). | User |
| O-B2 | Name of the scorecard's ClickHouse login on `.214`, and who creates it (a ClickHouse write). On the old server the report connects as `default` and `pwc`. | User |
| O-B3 | `agg_clinic_capacity_daily.slots_total` is inflated by 24-hour templates, which also affects SSAS `Clinic Utilisation %`. The fix belongs to Phase 1; until then `bsc` uses `legacy_capacity_slots`. | BI manager |
| O-B4 | `icu_discharge` for Jazan shows 378 discharges from a critical last bed in August 2026 (Alrabwah 64, Abha 102). Check Jazan's bed classification before acceptance. | Plan task |
| O-B5 | Finance to confirm `map_gl_cutover`, especially Jazan (July) and Unaizah (August), where costs are split across both systems. | Finance |
| O-B6 | **Closed 2026-10-13:** cost of goods sold is not consumables. `consumables_actual` is medical consumables only, and `consumables_budget` the Consumables line only. | User |
| O-B7 | Who reloads `bsc_targets` and `bsc_patient_satisfaction` on the new server, and when. | User |
| O-B8 | Referral policies are not mapped for Ghirnata and Muhayil, so `referrals_*` is 0 there until `map_referral_policies` has rows for them. | BI manager |
| O-B9 | Fusion income-statement data is about 0 for September 2026 for every branch (last Fusion load 2026-09-30). This is a freshness issue, not a design issue; check it before the comparison. | Ingestion |
| O-B10 | Khamis (2) has two unposted Fusion opening-balance batches for Aug-26 with almost the same trial balance: 248206 "OB_TB_Khamis Aug-26 Adjustment" (category Adjustment) and 254343 "OB_Khamis TB Aug-26 Open Balances" (MRC Open Balances). Both are opening journals, so from September 2026 (Khamis's first Fusion GL month) its balance sheet is about doubled in `vw_financial` (assets 1,741M against 899M in August, AR 317M against 186M) and in gold (`fact_gl_balance_monthly`, SSAS). Madinah's AR also jumps 100M to 146M at its cutover. Finance to say which batch is real; the other is then excluded in gold. The reconciliation shows each branch's balance sheet across its cutover month (found in the branch review, 2026-10-12). | Finance |
