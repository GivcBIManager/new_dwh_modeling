# HNH Data Warehouse — Phase 4 Workforce: Headcount, Movements, Payroll, Absence and Clinical Productivity

- **Date:** 2026-10-06
- **Status:** Draft for review
- **Parent specs:** `2026-10-01-hnh-dwh-gold-layer-design.md` (architecture, keys, conventions, security, portability) and `2026-10-05-hnh-dwh-phase3-finance-design.md` (Fusion access, Head Office branch 100, GL payroll journals, `map_fusion_specialty_unified`). Everything there applies unless this document says otherwise. Section 13 of the parent outlined this phase.

---

## 1. Purpose and decisions

Give the group one workforce model: who is employed where (headcount, FTE, Saudisation), who joins and leaves (movements, turnover), what they cost (payroll by pay category, tied to the GL), when they are absent (absence and leave balances), and what clinical staff produce for that cost (visits and revenue per payroll SAR and per FTE).

Decisions made in review (2026-10-06):

| # | Decision |
|---|---|
| W1 | **Staff link by worker number.** The Fusion worker number (`fact_period_of_service.worker_number`) equals the Oasis `staff_id` within the same branch (stated by the user, measured in W-findings H4). Fusion holds no national id, so the parent spec's national-id link is replaced. |
| W2 | **Payroll from both systems.** Oasis payroll transactions before each branch's Fusion payroll cutover, Fusion payroll from it, on common pay categories. |
| W3 | **Scope:** headcount and movements, payroll cost, absence and leave, and the clinical-productivity link. Recruiting, talent, learning and performance are out (their Fusion tables are empty or near empty). |
| W4 | **Architecture A:** a current-state employee dimension; a monthly headcount snapshot built from Fusion's assignment history; an event fact for movements; a monthly payroll fact; absence entries with a daily split; monthly leave balances; a staff bridge; one productivity aggregate. |

---

## 2. Findings that shape the design

Measured 2026-10-06 on `fusion` and `oasis` (all Fusion reads with `final`).

| # | Fact | Consequence |
|---|---|---|
| H1 | `dim_employee`: 4,856 people (4,952 rows; `is_current` is the string 'Y'/'N'): 4,403 EMP, 235 EX_EMP, 126 CWK, 25 CON, 69 CANCELED_HIRE. `national_identifier_number` is filled for 1 person. Nationality SA 1,554, EG 1,315, IN 893, PH 382 …; gender F 2,717, M 2,113, null 28. | No identity link; Saudi flag from nationality; cancelled hires excluded. |
| H2 | `dim_assignment`: 11,218 rows for 4,900 assignments (history `valid_from`/`valid_to`, 1–8 rows each); `branch_code` and `cost_center_code` are always null; `default_code_combination_id` is null for 2,028 primary assignments. Every assignment's `legal_employer_id` is an organisation named "HNH <name>" (9 values: Head Office and the eight hospitals). | Branch from the legal employer (section 4.1). |
| H3 | Fusion core HR went live in January 2026 for all branches: the first resignations, end-of-contract and transfer actions are dated 2026; earlier hire dates (from 2000) belong to people still employed at migration (only 235 ex-employees). | Headcount snapshot from 2026-01; earlier months use paid headcount from payroll (6.2). Turnover from 2026. |
| H4 | `fact_period_of_service.worker_number` (4,910 periods, 4,603 distinct numbers, 185 null) matches an Oasis `staff_master_data.staff_id` for 4,447 numbers; names agree within the employee's branch (e.g. Unaizah worker 10878 = branch 4 staff "Nasser ALQARZAEE"). Oasis staff ids repeat across branches (1,667 ids in two branches … 72 in all eight). Head Office matches 25 of 166 (it has no Oasis branch). | Bridge on (branch, worker number). |
| H5 | `fact_worker_movement`: 11,863 actions — HIRE 4,642, MANAGER_CHANGE 3,802, CONTRACT_EXTENSION 2,213, SUSP_ASSIGN 233, GLB_TRANSFER 231, ASG_CHANGE 230, ADD_CWK 126, RESIGNATION 85, END_OF_CONTRACT 81, POSITION_CHANGE 42, TERMINATION_ARTICLE_80 34, TERMINATION_ARTICLE_74 21, END_CONTRACT_IN_PROB_PERIOD 12 …; it carries the `previous_*` organisation, job, position, grade, location and changed flags. | Movements read directly; a movement-group macro. |
| H6 | Department names carry a branch prefix (RBW, JAZ, MHL, ABH, GHI, UNI, KHM, MAD ≈ 250 each; HQ 75) followed by the same specialty vocabulary as the GL specialty segment (e.g. "ABH Neurology", "ABH Female Ward"). | Unified department through `map_fusion_specialty_unified` by name. |
| H7 | `fact_assignment_work_measure`: units HEAD (1,658) and FTE (1,674, average value 0.03). | FTE from the work measure only when it lies in (0, 1.5]; otherwise 1. |
| H8 | Fusion payroll run results (654,635) from 2026-03-30 to 2026-09-30. Money results are the input value *Pay Value* (108 elements). Not pay: *GOSI Reference Earnings/Salary* elements (≈160M SAR, the GOSI base), *Information* elements (EOS provision, net amount), absence elements (hours/days). Payroll action status C = completed. `fact_payroll_cost` (costing, 286.8M SAR debits) has null cost dates. | Pay-value results through a pay-category map; costing not used. |
| H9 | Oasis `account_transactions` (≈1.57M rows with `final`): branches 1–5 from 2022, branch 6 from 2024-10, branches 7–8 from 2025-11; 88 `trx_type` codes within 62 `transaction_type`s; payable type P (pay) and K (GOSI); status C (closed) and P (in progress). | Oasis payroll staged; status C only; pay-category map. |
| H10 | Parallel runs: per branch and month, Oasis and Fusion paid-staff counts show Fusion taking over — Ghirnata and Head Office from 2026-03, Abha from 2026-05 (both systems May–August), Jazan from 2026-07 (both July–August), Unaizah and Muhayil from 2026-08. Al-Rabwa has stray Fusion results (one person a month), Khamis and Madinah none; their payroll is still Oasis. | `map_payroll_cutover`; parallel-run months take Fusion. |
| H11 | Branch 8's Oasis payroll for January–April 2026 has exactly branch 7's paid-staff counts (139, 186, 234, 247). | Source duplication, monitored (as Phase 2B claims). |
| H12 | Absence: 3,658 Fusion entries from 2024-12 (sick 1,274 approved, permission leave in hours, annual leave Saudi / non-Saudi / HQ plans, unpaid, time back); statuses SUBMITTED/SAVED/ORA_WITHDRAWN × approval APPROVED/AWAITING/DENIED; duration unit C (calendar days) or H (hours). Leave balances 68,068 rows (3,402 people) from 2025-04. | Counted = submitted and approved; daily split; balances monthly. |

---

## 3. Architecture

Same layers, tags and folders as earlier phases.

```
models/hnh/staging/fusion/       + stg_fusion__employees, __assignments, __periods_of_service, __worker_movements,
                                   __work_measures, __departments, __organizations, __jobs, __grades, __positions,
                                   __locations, __worker_actions, __payroll_run_results, __payroll_elements,
                                   __payroll_input_values, __absence_entries, __absence_types, __absence_balances
models/hnh/staging/oasis/        + stg_oasis__payroll_transactions
models/hnh/staging/reference/    + stg_ref__pay_category, stg_ref__payroll_cutover
models/hnh/intermediate/workforce/ int_employee_period, int_assignment_month_end
models/hnh/marts/conformed/      hnh_dim_employee, hnh_dim_hr_department, hnh_dim_job, hnh_dim_grade, hnh_dim_position,
                                 hnh_dim_location, hnh_dim_worker_action, hnh_dim_absence_type, dim_pay_category,
                                 bridge_employee_staff
models/hnh/marts/workforce/      fact_headcount_monthly, hnh_fact_worker_movement, fact_payroll_monthly, fact_absence,
                                 fact_absence_daily, fact_leave_balance_monthly, agg_staff_productivity_monthly
models/hnh/marts/reconciliation/ + rec_payroll_monthly, rec_headcount_monthly
macros/hnh/hnh_rules_workforce.sql
```

All models are full rebuilds. Eight model names exist in the receiving project's own Fusion models (`dim_employee`, `dim_job`, `dim_grade`, `dim_position`, `dim_location`, `dim_worker_action`, `dim_absence_type`, `fact_worker_movement`); those models carry the `hnh_` prefix and an `alias` to the gold table name, as in Phase 3. Names, phone numbers, e-mail, bank details and national ids are never staged.

---

## 4. Reference data and rules

### 4.1 HR branch rule (macro `hnh_hr_branch_key`, used in `int_employee_period` and the facts)
The legal employer's organisation name (`dim_organization`, e.g. "HNH Abha") minus the prefix "HNH " equals a Fusion business-unit name (`dim_business_unit`, e.g. "Abha"); that business unit's `primary_ledger_id` gives the branch through `hnh_dim_branch.fusion_ledger_id`. Head Office → 100. A legal employer that does not resolve gives branch 0, which a test rejects.

### 4.2 Tables to be drafted, reviewed and loaded once into `default`
| Table | Content |
|---|---|
| `map_pay_category` | `SOURCE` (`oasis`/`fusion`), `SOURCE_CODE` (Oasis `trx_type`; Fusion element name), `PAY_CATEGORY`. Drafted by keyword rules (basic, housing, transport, food, overtime, critical/nursing/supervisor/work-nature allowances, GOSI employee/employer, loan, leave/encashment, end of service, award, absence/lateness deduction, bank charge); GOSI reference earnings and Information elements → `Not pay`. |
| `map_payroll_cutover` | `BRANCH_ID`, `FIRST_FUSION_MONTH` (yyyymm): 7 → 202603, 100 → 202603, 6 → 202605, 3 → 202607, 4 → 202608, 8 → 202608. Branches without a row are paid from Oasis. Maintained by the BI manager when a branch moves. |

### 4.3 dim_pay_category (static model)
Categories: Basic, Housing, Transport, Food, Clinical allowances, Other allowances, Overtime, Leave pay, End of service, Awards and bonus, GOSI employer charge (earnings side, `is_cost`), GOSI employee deduction, Absence and lateness deduction, Loans and advances, Other deductions, Not pay, Unmapped. Columns: `pay_category`, `pay_group` (Earnings, Employer charges, Employee deductions, Not pay), `is_cost` (earnings and employer charges), `is_gross_pay` (earnings), `sort_order`.

### 4.4 Macros (`hnh_rules_workforce.sql`)
`hnh_hr_branch_key` (4.1), `hnh_movement_group(action_code)` (Hire: HIRE, ADD_CWK; Rehire: REHIRE; Transfer: GLB_TRANSFER, TRANSFER; Position change: POSITION_CHANGE, PROMOTION, ASG_CHANGE; Voluntary leaver: RESIGNATION; Involuntary leaver: TERMINATION_ARTICLE_80, TERMINATION_ARTICLE_74, END_OF_CONTRACT, END_CONTRACT_IN_PROB_PERIOD, other TERMINATION%; Contract extension: CONTRACT_EXTENSION; Other), `hnh_absence_status(status_code, approval_code)` (Approved, Awaiting, Denied, Withdrawn, Saved), `hnh_is_counted_absence` (submitted and approved, not withdrawn), `hnh_age_band`, `hnh_tenure_band`, `hnh_fte(value)` (value in (0, 1.5] else 1).

---

## 5. Conformed dimensions

### 5.1 hnh_dim_employee (alias dim_employee)
One row per Fusion person (current row), cancelled hires excluded, plus Unknown (`-1`). Key `employee_key` = hash of `person_id`. Attributes: person number, worker number, worker type (Employee, Ex-employee, Contingent worker, Contractor), gender, nationality, `is_saudi`, date of birth, age band, hire date, original hire date, termination date, `is_terminated`, tenure band, current branch, HR department, job, grade, position, location, assignment status, linked `staff_key` (from the bridge, `-1` if none).

### 5.2 hnh_dim_hr_department
Fusion department (`organization_id`), with branch prefix, name, name without prefix, unified department (`map_fusion_specialty_unified` by `specialty_name` = name without prefix, else Unknown), and branch (from the prefix: RBW 1, KHM 2, JAZ 3, UNI 4, MAD 5, ABH 6, GHI 7, MHL 8, HQ 100). Unknown `-1`.

### 5.3 hnh_dim_job, hnh_dim_grade, hnh_dim_position, hnh_dim_location, hnh_dim_worker_action, hnh_dim_absence_type
Current rows of the Fusion dimensions plus Unknown. Job carries full/part-time and regular/temporary; worker action carries action, reason and `movement_group`; absence type carries plan, plan type and `absence_category` (Sick, Annual, Unpaid, Permission, Time back, Other).

### 5.4 bridge_employee_staff
One row per Fusion employee whose worker number matches an Oasis staff id in the employee's branch: `employee_key`, `staff_key`, `branch_key`, `worker_number`, `match_method` = 'worker_number'. When a worker number matches more than one staff record in the branch, none is linked and the case is monitored. Employees of Head Office are not linked.

---

## 6. Facts

### 6.0 Intermediate models
`int_employee_period`: one row per person with the latest period of service (worker number, hire, original hire, termination dates) and the branch of the legal employer (4.1). `int_assignment_month_end`: one row per person × month-end with the primary assignment valid at that date (rule in 6.1) and the FTE work measure valid then.

### 6.1 fact_headcount_monthly
**Grain:** person × month-end, months 2026-01 to the current month, for the primary assignment valid at the month-end (`int_assignment_month_end`: the assignment row whose `valid_from` ≤ month-end < `valid_to`, choosing the latest `valid_from` when rows overlap) with status ACTIVE or SUSPENDED.
**Keys:** `branch_key` (legal employer at month-end), `employee_key`, `staff_key`, `hr_department_key`, `job_key`, `grade_key`, `position_key`, `location_key`, `month_date_key` (month-end).
**Attributes:** worker type, `is_contingent`, assignment status, full/part-time, regular/temporary, `is_saudi`, gender, age band and tenure band at month-end.
**Measures:** `headcount` (1), `fte` (`hnh_fte` of the FTE work measure valid at month-end), `is_new_hire_in_month`, `is_leaver_in_month` (a leaver movement in the month).

### 6.2 Paid headcount
`fact_payroll_monthly` gives `paid_headcount` = distinct people with a gross-pay row in the month (Oasis before cutover, Fusion after), for 2022 onward. It is a separate measure from `headcount` and is the only headcount before 2026.

### 6.3 hnh_fact_worker_movement (alias fact_worker_movement)
**Grain:** one Fusion assignment action (`assignment_id`, `effective_start_date`, `effective_sequence`), action dates from 2022-01-01.
**Keys:** `branch_key` (after the action), `previous_branch_key`, `employee_key`, `worker_action_key`, `action_date_key`, department, job, grade, position and location before and after.
**Attributes and flags:** `movement_group`, changed flags from Fusion, `is_hire`, `is_leaver`, `is_voluntary_leaver`, `is_branch_transfer` (legal employer changed).

### 6.4 fact_payroll_monthly
**Grain:** branch × person × payroll month × pay category × source (`oasis`, `fusion`).
**Oasis rows:** `stg_oasis__payroll_transactions` with status C (and, since 2026-10-07, status P reduced by the latest-run rule of §12.2 through `int_oasis_payroll_line`), payroll month = year × 100 + period, months before the branch's `FIRST_FUSION_MONTH` (all months when the branch has no cutover row), from 2022-01.
**Fusion rows:** pay-value run results of completed payroll actions, payroll month = effective date's month, months from the branch's `FIRST_FUSION_MONTH`.
**Parallel-run rows:** Oasis rows in or after the cutover month are kept with `is_parallel_run = 1` and contribute nothing to `amount`-based measures (`cost_amount`, `gross_pay`, `paid_headcount`); they exist for `rec_payroll_monthly`.
**Keys:** `branch_key` (Oasis rows: the transaction's `branch_id`; Fusion rows: the legal employer, 4.1), `employee_key` (Fusion person; for Oasis rows via the bridge, `-1` if none), `staff_key` (Oasis staff; for Fusion rows via the bridge), `pay_category_key`, `month_date_key` (month start), `hr_department_key` (from the headcount snapshot when the person has one that month, else `-1`).
**Measures:** `amount` (signed: earnings and employer charges positive, employee deductions negative), `cost_amount` (amount where `is_cost`), `gross_pay` (amount where `is_gross_pay`). Oasis status P (payroll in progress) is not loaded.

### 6.5 fact_absence and fact_absence_daily
`fact_absence`: one Fusion absence entry; keys branch, employee, staff, absence type, start and end date; `absence_status`, `is_counted`, `absence_days` (unit C), `absence_hours` (unit H). `fact_absence_daily`: one row per counted entry per calendar day (unit C entries only), with branch, employee, staff, absence type and date keys, `absence_days` = 1.

### 6.6 fact_leave_balance_monthly
One row per Fusion balance entry (person × absence plan × accrual period): branch, employee, absence plan, accrual period date; `begin_balance`, `accrued`, `used`, `end_balance` (days); `monthly_salary`, `daily_rate` and `leave_liability_amount` for annual-leave plans.

**Leave liability (decided 2026-10-06):** `daily_rate` = `monthly_salary` ÷ 30; `leave_liability_amount` = `end_balance` × `daily_rate`. `monthly_salary` is the person's recurring monthly pay in the latest payroll month on or before the accrual period: Σ `amount` of pay categories Basic, Housing, Transport, Food, Clinical allowances and Other allowances in `fact_payroll_monthly` (overtime, leave pay, end of service and awards excluded). Null when the person has no payroll month yet (the liability is then null and monitored). Sick, unpaid and other non-annual plans carry no liability.

### 6.7 agg_staff_productivity_monthly
**Grain:** Oasis staff (linked through the bridge) × month, months from 2026-01. **Measures:** encounters seen as treating doctor (`fact_encounter`, arrived and not cancelled), recognised revenue (`fact_charge_line.revenue_amount` by its staff key), `cost_amount` and `gross_pay` (`fact_payroll_monthly`), month-end FTE (`fact_headcount_monthly`), counted absence days (`fact_absence_daily`). Ratios are left to SSAS as sums over this table.

---

## 7. KPI definitions (for SSAS)

| KPI | Definition | Fact |
|---|---|---|
| Headcount, FTE | Σ `headcount`, Σ `fte` at the selected month-end, `is_contingent = 0` | `fact_headcount_monthly` |
| Saudisation rate | Saudi headcount ÷ headcount | `fact_headcount_monthly` |
| Paid headcount | distinct people with gross pay in the month | `fact_payroll_monthly` |
| Hires, leavers | movements with `is_hire`, `is_leaver` in the period | `fact_worker_movement` |
| Turnover rate, voluntary turnover | leavers (voluntary leavers) ÷ average month-end headcount of the period; from 2026 | movement and headcount facts |
| Payroll cost, gross pay | Σ `cost_amount`, Σ `gross_pay`, `is_parallel_run = 0` | `fact_payroll_monthly` |
| Overtime share | overtime ÷ gross pay | `fact_payroll_monthly` |
| Cost per FTE | payroll cost ÷ average FTE | payroll and headcount facts |
| Sick-leave rate | counted sick days ÷ (FTE × calendar days) | `fact_absence_daily`, `fact_headcount_monthly` |
| Leave balance | Σ `end_balance` of the latest accrual period | `fact_leave_balance_monthly` |
| Leave liability | Σ `leave_liability_amount` of the latest accrual period per person | `fact_leave_balance_monthly` |
| Revenue per payroll SAR, visits per FTE, cost per visit | sums over `agg_staff_productivity_monthly` | `agg_staff_productivity_monthly` |

---

## 8. Testing and reconciliation

- Unique and not-null grain keys; relationships from every fact key to its dimension; no HR fact row with `branch_key = 0`.
- Conservation: headcount rows = staged primary assignments active at each month-end; movement rows = staged actions in window; payroll Fusion rows = staged pay-value results of completed actions in cutover months; payroll Oasis rows = staged status-C transactions in window.
- No branch-month carries `cost_amount` from both sources.
- Macro tests with literal inputs for every macro in 4.4.
- Unit tests: month-end assignment pick with overlapping rows and an INACTIVE gap; a transfer between branches (branch before/after); the payroll cutover including a parallel-run month; an absence spanning a month-end (daily split); a staff id present in two branches (bridge picks the employee's branch).
- `rec_payroll_monthly` (branch × month): payroll cost and gross pay from the fact; GL payroll cost (Phase 3 `fact_gl_journal_line` with `je_source_label = 'Payroll'`, and the employee-cost FS captions from `fact_income_statement_monthly`); Oasis and Fusion side by side in parallel-run months.
- `rec_headcount_monthly` (branch × month, 2026): Fusion headcount beside Oasis paid headcount while Oasis payroll still ran.
- Warn monitors: annual-leave balances with no monthly salary (liability null); unmapped pay codes; hospital employees without a bridge match; worker numbers matching several staff records; branch 8 Oasis payroll identical to branch 7; FTE values outside (0, 1.5]; absence entries of unit C with zero days.

---

## 9. Security and SSAS handoff

- Every HR fact relates to `dim_branch`; Head Office is branch 100 in the branch role.
- Pay is sensitive: `fact_payroll_monthly`, `agg_staff_productivity_monthly` and `fact_leave_balance_monthly` (it carries salary and liability) go in a separate perspective with an HR/finance role; headcount, movements and absence counts can be in the general perspective.
- Headcount KPIs use the month-end snapshot; never sum `headcount` across months (use the last month or an average).
- Payroll measures filter `is_parallel_run = 0`.
- Turnover and headcount history start in 2026; earlier months show paid headcount only.
- Payroll reporting (employee detail, open and closed payroll, latest Oasis run, measure definitions) follows §12.

---

## 10. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P4-1 | Review of `map_pay_category` (88 Oasis codes, 108 Fusion elements) | Payroll sign-off | Draft used; unmapped codes monitored |
| O-P4-2 | Payroll cutover of Al-Rabwa, Khamis and Madinah | Their payroll after the move | Oasis until a cutover row is added. 2026-10-07: none has moved (Fusion holds no payroll for Khamis or Madinah, one person for Alrabwah); left as is by the user, without a monitor |
| O-P4-3 | Branch 8 Oasis payroll January–April 2026 duplicates branch 7 | Branch 8 early-2026 payroll | Counted as delivered; monitored. **Closed 2026-10-07:** known source behaviour, monitored |
| O-P4-4 | Leave liability in SAR | — | Closed 2026-10-06: monthly salary ÷ 30 per day (6.6); "monthly salary" = recurring monthly pay, to be confirmed by HR |
| O-P4-5 | Fusion FTE values are mostly empty or 0 | FTE KPIs | **Closed 2026-10-07:** FTE 1 unless a value in (0, 1.5] exists; accurate once HR fills FTE in Fusion |
| O-P4-6 | Whether contingent workers count in any headcount KPI | — | Closed 2026-10-06: excluded by default, flagged (`is_contingent`) |
| O-P4-7 | Head Office employees have no Oasis staff record | Productivity of HO staff | **Closed 2026-10-07 (by design):** Head Office staff are non-clinical; productivity covers branch staff |
| O-P4-8 | `fact_payroll_monthly` loads only closed Oasis payroll (status C); §12 needs open payroll with the latest-run rule and a closed flag | SSAS payroll model showing the current month | **Closed 2026-10-07:** built as specified in §12 (see §12.6) |

---

## 11. Changes during implementation (2026-10-06)

- Age and tenure (and the bands built from them) are exact whole years (`dateDiff('year')` less one before the anniversary), not days ÷ 365.25.
- `map_pay_category` marks a base deduction element as *Not pay* only when, in completed payroll, at least half of its person-months also carry its "<name> Results" twin; otherwise the name rules apply (the blanket twin rule would have dropped about 430k SAR).
- `hnh_fact_worker_movement.branch_key` is the branch of the legal employer on the assignment row valid on the action date, `previous_branch_key` the one valid the day before (falling back to the department prefix, then the employee's current branch); `is_branch_transfer` is a change of that branch. This supersedes the department-prefix refinement of the plan, which missed GLB_TRANSFER.
- `fact_headcount_monthly` gains `is_closed_month` (month-end before today), so latest-month KPIs can exclude the projected current month-end.
- Fusion payroll keeps, per person, element, legal employer and month, only the results of the latest regular payroll action (action type R), plus all QuickPay actions, because September 2026 holds repeated full regular runs.
- A Fusion run result with no legal employer (GOSI and reference results) takes the employer of the same person and payroll action; unresolved results go to branch 0 and fail `assert_workforce_facts_have_branch`.
- `fact_leave_balance_monthly` adds `is_closed_period`, `is_latest_in_month` and `is_current_balance` (balances are weekly running balances; ties resolved by the highest accrual entry id); monthly KPIs filter `is_latest_in_month`, latest-position KPIs `is_current_balance`.
- The salary behind the leave liability (ASOF join) uses only payroll months with positive Basic pay, so adjustment-only months give no negative salary; negative liabilities of overdrawn balances are kept.
- Future-dated absence days stay in `fact_absence_daily` (planned leave) with no flag; consumers filter by date.
- `agg_staff_productivity_monthly` FTE is the maximum FTE per staff and month over non-contingent employees, and only months up to the current month are kept; the linked-staff set is one row per `staff_key` (the bridge stays one row per employee).
- `rec_payroll_monthly.gl_employee_cost` uses `actual_excl_opening`, and a new column `gl_payroll_journal_credit` (Payroll-source credits on income-statement accounts) sits beside the debit column; the month spine stops at the current month.
- `hnh_dim_employee` leaves the 21 CON contractors without period of service, assignment or legal employer on branch 0 (dimension only; never in a fact).
- Paid headcount in `rec_headcount_monthly` counts people with Basic pay above zero (not any gross pay); the two differ by 0 to 6 people per branch-month.
- Two extra warn monitors were added in Task 8: `assert_leave_balance_single_entry_per_period` and `assert_absence_daily_no_overlap`.
- `warn_leave_without_salary` counts only current balances (`is_current_balance = 1`), one per employee and plan, not every weekly entry.
- Oasis payroll resolves staff to employee through `bridge_employee_staff` deduplicated to `min(employee_key)` per `staff_key` (3 staff records are shared by two employees), so no Oasis pay row is duplicated.
- `fact_payroll_monthly` adds `paid_person_key` (`employee_key` when resolved, else `payee_key`), so paid headcount across months counts a person paid by Oasis and then Fusion once; `payee_key` stays per source.
- `fact_headcount_monthly.is_leaver_in_month` is dropped (a leaver normally has no month-end row, so it caught about 11% of leavers); turnover leavers come from `fact_worker_movement.is_leaver`.
- Relationship tests were added for every dimension key of the workforce facts (spec §8), with two error-severity conservation tests: `assert_headcount_matches_assignments` and `assert_movements_match_staged_actions`.
- Fusion HR staging (positions, jobs, grades, locations, HR departments, organizations, absence types and plans) keeps the latest row per id rather than current rows only, with `is_current` exposed, so end-dated members referenced by facts stay in the dimensions (a Fusion position end-dated on 2026-10-04 broke the three position-key relationship tests; fixed in commit 271be60).

---

## 12. Payroll reporting rules for SSAS (decided 2026-10-06)

Decided by the user while building the September 2026 payroll report (all branches, employee level): **payroll that is not yet closed is included, each employee carries a closed flag, and Oasis payroll counts only the latest payroll run.** Built into `fact_payroll_monthly` on 2026-10-07 (O-P4-8, §12.6).

### 12.1 Source per branch and month
- A branch-month is paid by Fusion from its `FIRST_FUSION_MONTH` in `map_payroll_cutover`, by Oasis before (unchanged from 6.4). Oasis lines of a branch already on Fusion (parallel run) are excluded.
- Fusion: completed payroll actions only, the latest regular run per person, element and legal employer plus QuickPay (§11). Every Fusion employee is *Closed*.
- Oasis: `account_transactions` lines with status C (closed) **and** P (in progress), reduced by the latest-run rule in 12.2.

### 12.2 Oasis latest-run rule
**Finding.** The ClickHouse copy of `account_transactions` keeps every payroll calculation as status P lines, also after the month is closed; closing writes the final run again as new status C lines dated on the close date. September 2026 evidence: Alrabwah has P runs on 21, 22, 26 and 29 Sep and the C close of 5 Oct equals the 26 Sep run (SAR 8,204,567); Madinah's close of 1 Oct equals its 24 Sep run (SAR 4,472,462); Khamis, still open, has three full P runs (21, 23, 24 Sep), so its open lines total SAR 15.9M against about 5.3M per run.

**Rule** (per branch × staff × payroll month):
1. *Calculation date* = a date carrying a positive BASIC line with status P for the staff.
2. *Branch full run* = a date on which at least 20% of the branch's staff with positive BASIC that month were calculated (P) or closed (C); the latest such date is the branch's last full run.
3. *Staff closed* = the staff has no calculation date, or has a positive closed BASIC line dated on or after the staff's latest calculation date.
4. Closed lines (C) are always kept.
5. Open lines (P) are kept only when the staff is not closed **and** the staff's latest calculation date is on or after the branch's last full run (a staff calculated in a trial run but left out of a later run or of the close is a leftover: September 2026, 28 Alrabwah and Madinah staff from the 21 Sep run). Of those, keep the lines of the latest calculation date plus lines on dates that are not calculation dates (one-off entries: loans, bank charges, adjustments). Lines of superseded calculations are dropped.

### 12.3 Payroll status (per employee and month)
`Closed` = all kept lines are closed (Oasis status C, or Fusion); `Open` = all kept lines are status P (figures can change until the branch closes the month); `Partly closed` = both. Reports show the status and split gross pay into closed and open.

### 12.4 Measures
Signed amounts: earnings and employer charges positive, employee deductions negative. Pay category *Not pay* (GOSI reference earnings and salary, Fusion Information elements) is excluded from every measure.

| Measure | Definition |
|---|---|
| Basic, Housing, Transport, Food, Clinical allowances, Other allowances, Overtime, Leave pay, End of service, Awards and bonus, Absence and lateness deduction | Σ amount of that pay category |
| Gross pay | Σ amount where `is_gross_pay` (all earnings including the absence and lateness deduction) |
| Employee deductions | Σ amount of GOSI employee deduction, Loans and advances, Other deductions |
| Net pay | Gross pay + employee deductions (derived; can differ from the bank transfer when off-payroll deductions exist) |
| GOSI employer charge | Σ amount of that category |
| Total cost | Σ amount where `is_cost` = gross pay + GOSI employer charge |
| Paid employees | distinct employees with gross pay ≠ 0 in the month (closed and open counted separately as well) |
| Gross pay closed / open | gross pay of closed / open lines |
| Unmapped pay codes | Σ amount of category *Unmapped* (expected 0; monitored) |

### 12.5 Employee attributes in the payroll detail
Fusion employees (and Oasis staff linked through `bridge_employee_staff`): name from Fusion `dim_employee.full_name` (latest version), person number, job, grade, nationality, Saudi flag, gender, hire date and assignment status from `dim_employee`; department from the HR department of the month-end headcount row. Fallback for Oasis staff without a Fusion link: `dim_staff` name, position, grade, nationality and service start date, department from the staff's home department. Head Office staff have no Oasis staff id.

### 12.6 Implementation notes
- O-P4-8 (closed 2026-10-07): `int_oasis_payroll_line` applies the 12.2 rule to every branch and payroll month (`stg_oasis__payroll_transactions` now carries `transaction_date`); `fact_payroll_monthly` reads it and carries `is_closed_payroll` (row grain: Fusion rows are 1), `payroll_status` (12.3, per payee and month) and `open_run_date`. Payroll measures cover open and closed lines; the status is a slicer. The build reproduces the September 2026 reference figures below exactly. Outside the current month the rule keeps open lines only for lone calculations that were never closed: one payee in branches 7 and 8 in 202511 (7,300 SAR each), one in branch 8 in 202605 (7,000 SAR) and early October 2026 lines in branch 1.
- Build timing: Oasis is copied to ClickHouse around 09:10 each day. A gold build before that misses payroll closed that morning (6 Oct 2026: the 08:26 build missed the Alrabwah and Madinah September close, showing 69 and 39 paid staff instead of 953 and 482). Schedule the workforce build after the Oasis copy.
- September 2026 reference figures (for testing the implementation): group paid employees 4,304 (3,717 closed, 587 open, all open in Khamis), gross pay SAR 42,852,632, net pay 41,706,707, total cost 44,304,326; Khamis 622 employees, gross 5,684,074 (closed 436,997, open 5,247,077).
