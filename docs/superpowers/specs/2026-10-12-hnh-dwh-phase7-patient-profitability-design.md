# HNH Data Warehouse — Phase 7 Patient Profitability: Encounter Costing and Margin

- **Date:** 2026-10-12
- **Status:** Draft for review. Design only, for later implementation.
- **Parent specs:**
  - `2026-10-01-hnh-dwh-gold-layer-design.md`: architecture, keys, conventions, security. Everything in it applies unless this document says otherwise.
  - Phase 2 (revenue: `fact_charge_line`, `fact_revenue_adjustment`).
  - Phase 3 (finance: `hnh_fact_gl_journal_line`, `dim_gl_account`, `dim_budget_line`).
  - Phase 4 (workforce: `fact_payroll_monthly`, `bridge_employee_staff`).
  - Phase 5 (supply: `fact_stock_movement`, `fact_patient_consumption`, `dim_store`).
  - `2026-10-07-hnh-ssas-tabular-model-design.md`: SSAS conventions and measure rules.
- **Source profile:** not yet measured for this phase. The findings in section 2 come from the parent specs and the current models. The implementation plan's first task measures the gaps listed in section 2.2.

---

## 1. Purpose and decisions

The aim is a cost per encounter that adds up to the GL, so margin can be reported at every level the model already slices revenue by:
- patient;
- payer and care type (contract margin);
- department and specialty (service-line margin);
- treating doctor (doctor performance).

Decisions made in review (2026-10-12):

| # | Decision |
|---|---|
| C1 | **One costing layer serves all three purposes:** payer and contract margin, service line and department, and doctor performance. Cost lands on the encounter, so it rolls up to any dimension of the encounter. |
| C2 | **Two cost levels.** **Direct cost** comes from operational sources (payroll and stock) for every branch from 2022. **Full cost** adds GL overheads, depreciation and Head Office, from each branch's first full Fusion GL month. The two are separate measures and are never mixed. |
| C3 | **Method A: department cost pools with activity drivers.** Monthly pools per branch × department × care setting; one step-down of support pools; patient-facing pools spread over encounters by an activity driver per care setting; doctor pay assigned to the doctor's own activity. Cost-to-charge ratios were rejected because they make cost proportional to price, which defeats payer and doctor margin. Standard cost per service was rejected because the cost catalogue does not exist. The driver step can take per-service weights later. |
| C4 | **Operational sources decide where cost lands; the GL decides how much.** In full-cost months, the gap between GL employee cost and payroll, and between GL medicines and consumables and stock consumption, is a visible **true-up** component, spread like the cost it corrects. Full cost per branch and month equals that branch's GL operating cost plus its Head Office share. |
| C5 | **Head Office is spread as its own component.** Head Office (branch 100) GL operating cost is split across branches by net revenue each month, then follows the support step-down. It stays in its own `head_office` component, so reports can show margin before and after it. |
| C6 | **Out of scope for cost:** finance cost, zakat, OCI, other income and revenue accounts. Margin is operating margin. |
| C7 | **Revenue for margin** is `Net Revenue After Adjustments` (charge lines plus post-invoice discount). Claim rejections and write-offs are not deducted (O-P7-3). |
| C8 | **Cost of a doctor's pay is salary data.** The cost fact is gated by `Can See Pay`, like `Staff Productivity`. |

---

## 2. Findings that shape the design

### 2.1 From the parent specs and models

| # | Fact | Consequence |
|---|---|---|
| K1 | Fusion GL went live per branch during 2026: Ghirnata January, Abha February, Head Office April, Jazan and Muhayil June, Unaizah July, Khamis late August, Madinah September. Alrabwah has no journal lines. The legacy Oasis GL is not ingested (Phase 3 G2, F1). | Full cost exists only from each branch's GL go-live (C2). |
| K2 | Each go-live month has a year-to-date opening-balance journal (`is_opening_balance_journal`; Phase 3 G3, O-P3-12). | Opening journals are excluded. A go-live after the 1st of the month makes that month partial, so full cost starts the next month (6.2). |
| K3 | COA 2001 has no cost-centre segment. Segment 3 (specialty, 324 values) maps to `unified_department` through `map_fusion_specialty_unified` (206 mapped; administrative specialties Unknown). Segment 4 (service location) gives OPD, IPD, ER and others (Phase 3 G1). | Pools are keyed by `unified_department`, not `dim_department`. Unmapped and administrative specialties are support pools. Care setting comes from the service location. |
| K4 | `dim_budget_line` classifies cost: direct cost `DC_*` (employee, doctors' fee, medicines, consumables, government fees, insurance, maintenance, utilities, rental, referral, kitchen, travel, training, other), G&A `GA_*`, `DEPRECIATION`, `FINANCE_COST`, `ZAKAT`. `DC_CONSUMABLES` actual is 0 because Fusion has no consumables account yet (O-P3-8). 70 accounts are unmapped (O-P3-1). | Component map on `budget_line_code` (4.1). The stock true-up compares stock consumption to medicines plus consumables together. |
| K5 | `fact_payroll_monthly` is branch × payee × month × pay category × source. Oasis payroll runs from 2022 for branches 1–5, 2024-10 for branch 6 and 2025-11 for branches 7–8. Fusion payroll started per branch in 2026 (Phase 4 H9, wf:77). `hr_department_key` exists only for Fusion (2026+). `cost_amount` is the cost measure (`is_cost`). | Direct cost from 2022. Department of Oasis-era pay comes from `dim_staff.home_department_key`. |
| K6 | `bridge_employee_staff` links Fusion employees to Oasis `staff_id` within a branch (4,447 matches; Head Office not linked). Oasis payroll carries `staff_key` directly. | Doctor pay can be assigned to the doctor's own encounters. |
| K7 | `fact_patient_consumption` already carries `consumption_cost` per encounter, episode, patient, department and doctor. Department issues are `fact_stock_movement` rows with `is_consumption = 1` and no patient. Stores map to `unified_department` through `map_store_department`. | `drugs_supplies` needs no allocation. Department issues form `department_supplies` pools. |
| K8 | Activity sources: `fact_encounter` (department, treating doctor), `fact_bed_occupancy_daily` (ward, `admission_key`), `fact_surgery` (episode, department, `operating_minutes`, `anaesthesia_minutes`, surgeon), `fact_charge_line` (encounter, department, service, units, gross amount), `fact_episode` (consultant). `dim_department.care_setting` is OP, IP, ER, Theatre, Ancillary or Support. | Drivers per care setting (5.3). |
| K9 | Head Office is its own branch (`branch_key` 100) with no elimination (Phase 3 F6). | Head Office is spread to branches (C5). |
| K10 | Payroll and staff productivity are pay-sensitive. SSAS gates them with `Can See Pay` (Phase 4 section 9; role `HNH Readers`). | C8. |

### 2.2 To measure in the first implementation task

1. The share of GL expense amount (posted, opening journals excluded) by specialty status: mapped, administrative or unmapped. Also the share by service location, including location `00`.
2. The share of payroll cost whose department is known: Fusion `hr_department_key` → `unified_department`, and Oasis `dim_staff.home_department_key`.
3. The share of department-issue cost on stores with `unified_department = 'Not Mapped'`.
4. The share of patient-facing activity (encounters, bed-days, surgery minutes, ancillary charge units) per `unified_department` × care setting, per branch and month. This shows which pools would have no driver.
5. The expected row count of `fact_encounter_cost` (section 6.1).

---

## 3. Architecture

```
seeds / default.* (drafted, reviewed by finance, loaded once)
  map_cost_component           budget_line_code → cost component, or excluded
  map_cost_driver_weight       doctor-activity weights; theatre minutes weighting
  map_gl_location_setting      GL service location → care setting

models/hnh/intermediate/costing/
  int_cost_month               branch × month: is_direct_month, is_full_month, is_closed
  int_cost_pool_direct         branch × month × unified_department × care_setting × component (payroll, stock)
  int_cost_pool_gl             same grain from the GL (full months only)
  int_cost_pool_head_office    Head Office cost split by branch × month (net revenue share)
  int_cost_pool_stepdown       support and Head Office pools → patient-facing pools
  int_cost_activity            encounter × month × pool: activity units
  int_doctor_pay_activity      doctor × month × encounter: weighted activity units

models/hnh/marts/costing/
  dim_cost_component           static
  fact_encounter_cost          encounter × month × pool department × component × cost_basis
  rec_cost_allocation_monthly  branch × month × component × cost_basis: pool, allocated, unallocated, GL control
```

Everything is monthly. A month is costed only once it is closed: all its days are past, and for full cost the GL period is closed.

---

## 4. Reference data and rules

### 4.1 `default.map_cost_component`
One row per `budget_line_code`. The columns are `cost_component` and `is_excluded`.

| Budget lines | Component |
|---|---|
| `DC_EMPLOYEE`, `GA_EMPLOYEE` | payroll control (true-up base; see 5.4) |
| `DC_MEDICINES`, `DC_CONSUMABLES` | stock control (true-up base) |
| other `DC_*` | `department_other` |
| other `GA_*` (except `GA_HO_CHARGES`) | `support_overhead` |
| `GA_HO_CHARGES` | excluded at branches (the Head Office cost is spread from branch 100 instead, so it is not counted twice) |
| `DEPRECIATION` | `depreciation` |
| `FINANCE_COST`, `ZAKAT`, revenue, other income, OCI | excluded |

GL lines whose account has no budget line (O-P3-1) go to `support_overhead` and are listed by a warn test.

### 4.2 `default.map_gl_location_setting`
Service location → care setting:
- OPD, OPD-PH, Telemedicine, HHC → OP
- IPD, IPD-PH, LTC → IP
- ER → ER
- OR/Admission service group on IPD → Theatre if finance agrees (O-P7-2)
- `00`, `99` → none (split as in 5.2)

### 4.3 `default.map_cost_driver_weight`
Driver × weight. All weights are 1 until finance reviews them (O-P7-1):
- doctor: visit treated;
- doctor: inpatient day as consultant;
- doctor: operating hour as surgeon;
- theatre: operating minute;
- theatre: anaesthesia minute.

### 4.4 Macros (`hnh_rules_costing.sql`)
- `hnh_cost_setting(care_setting)`: the patient-facing settings (OP, IP, ER, Theatre, Ancillary) versus Support.
- `hnh_is_full_cost_month(branch_key, month)`: true from the first full GL month after go-live (K2) while the period is closed. Branches with no GL are never true.
- `hnh_service_relative_value`: the median gross unit price of a service per branch over the 12 months to the costed month, across all payers. It falls back to the group median, then to 1.

---

## 5. Allocation

### 5.1 Components and levels

| Component | Direct (`cost_basis = 'direct'`) | Full (`cost_basis = 'full'`) |
|---|---|---|
| `drugs_supplies` | `fact_patient_consumption.consumption_cost` on its encounter | the same rows |
| `drugs_supplies_true_up` | — | stock true-up share (5.4) |
| `doctor_pay` | doctor's payroll `cost_amount` over the doctor's activity (5.5) | the same rows |
| `staff_pay` | other payroll, by department pool | the same rows |
| `pay_true_up` | — | payroll true-up share (5.4) |
| `department_supplies` | department issues, by store department pool | the same rows |
| `department_other` | — | GL, by specialty pool |
| `support_overhead` | — | GL G&A, administrative and unmapped specialties, `care_setting = Support` pools, stepped down (5.3) |
| `depreciation` | — | GL, by specialty pool, or stepped down when the specialty is administrative or unmapped |
| `head_office` | — | Head Office share (5.6) |

**How the two bases relate.**
- Full rows repeat the direct components and add the rest, so `Full Cost` is the sum of the full rows alone.
- Direct rows exist for every closed month of every branch.
- Full rows exist only in full-cost months.

### 5.2 Pools
Pool key: branch × month × `unified_department` × care setting.

| Source | `unified_department` | Care setting |
|---|---|---|
| GL | specialty map | service location (4.2) |
| Fusion payroll | `hnh_dim_hr_department.unified_department` | none |
| Oasis payroll | `dim_staff.home_department_key` → `dim_department` | `dim_department.care_setting` |
| Department issues | `dim_store.unified_department` | none |

**Splitting cost with no care setting.** Cost without a setting is split across the department's settings in the month by their share of **setting-known direct cost**. That is patient consumption cost (setting from the encounter's department) plus Oasis payroll with a specific home department. When the department has no setting-known direct cost that month, the split uses activity at standard weights.

**Support pools.** Cost with `unified_department` Unknown, Not Mapped or administrative, and cost of `care_setting = Support`, forms the branch's support pools.

### 5.3 Step-down
One step. Each support pool of a branch and month, and the branch's Head Office share, is spread onto that branch's patient-facing pools by their share of direct cost after the setting split. Support pools do not receive cost from each other.

### 5.4 True-up (full months only)
- **Pay true-up** = GL (`DC_EMPLOYEE` + `GA_EMPLOYEE`) − payroll `cost_amount`, per branch and month. It is spread over `doctor_pay` and `staff_pay` rows in proportion to their amounts.
- **Stock true-up** = GL (`DC_MEDICINES` + `DC_CONSUMABLES`) − (patient consumption cost + department issue cost), per branch and month. It is spread over `drugs_supplies` and `department_supplies` rows in proportion to their amounts.
- A true-up can be negative.
- A true-up larger than ±15% of its base raises a warning. The rows are still written.

### 5.5 Drivers

| Pool care setting | Activity unit per encounter and month | Source |
|---|---|---|
| OP, ER | 1 per encounter at a department of the pool | `fact_encounter.department_key` |
| IP | occupied bed-days in wards of the pool | `fact_bed_occupancy_daily` (`is_occupied`, `admission_key` → inpatient encounter) |
| Theatre | operating minutes × weight + anaesthesia minutes × weight | `fact_surgery` (episode → the admission covering the surgery date; no admission → the episode's latest encounter on or before the surgery date) |
| Ancillary | Σ charge units × service relative value | `fact_charge_line` at departments of the pool, live charges |

- **Doctor pay.** For each doctor and month, pay is spread over the doctor's encounters by weighted units:
  - visits as treating doctor;
  - inpatient days as the episode consultant;
  - operating hours as surgeon.
- **Who is a doctor.** A doctor is an employee linked to a `dim_staff` row in the physician category used by `agg_staff_productivity_monthly`. The link is `bridge_employee_staff` for Fusion and `staff_key` for Oasis.
- **Doctor with no activity that month.** Their pay joins their home department's `staff_pay` pool.
- **Charges with no encounter.** Charges with encounter key −1 are costed. They carry their patient and episode keys and `encounter_key = -1`.

### 5.6 Head Office
- Head Office GL operating cost (components as 4.1) per month is split across hospital branches by their share of net revenue: charge lines plus post-invoice discount.
- A branch's share enters that branch's step-down as a `head_office` pool.
- **Branch with no full cost that month:** its share stays unallocated and appears in `rec_cost_allocation_monthly`, so the Head Office total still ties.

### 5.7 Unallocated
- A patient-facing pool with no activity in its month is not spread. It is written to `rec_cost_allocation_monthly` as unallocated, at branch × component level.
- Unallocated cost is not in `fact_encounter_cost`. The branch's full cost on encounters is then below its GL by exactly the unallocated amount, and the reconciliation shows it.

---

## 6. Facts

### 6.1 fact_encounter_cost
- **Grain:** encounter × month × department × component × cost basis. The department is the one on the activity row that carried the cost: the visit's clinic, the bed-day's ward, the surgery's theatre or the charge's department. Doctor pay rows take the encounter's department.
- **Keys:**
  - `month_date_key` (first day of the month);
  - `branch_key`;
  - `encounter_key`, `episode_key`, `patient_key`;
  - `billed_payer_key` (the encounter's payer as on its charges, else the episode payer);
  - `care_type_key`;
  - `department_key` (the department where the cost arose);
  - `treating_staff_key` (the encounter's treating doctor);
  - `cost_component_key`.
- **Columns:** `cost_basis` (`direct` / `full`), `unified_department`, `care_setting`, `activity_units`, `cost_amount` (SAR). Use the same amount type as the other facts' amounts: the ClickHouse ODBC driver reports `Decimal` with scale 0 to SSAS, which truncates fractions.
- **Engine and ordering:** MergeTree, ordered by `(branch_key, month_date_key, encounter_key)`. A rebuild replaces the costed months; a closed month is recomputed only when its inputs change (O-P7-5).

### 6.2 rec_cost_allocation_monthly
- **Grain:** branch × month × component × cost basis.
- **Columns:** `pool_amount`, `allocated_amount`, `unallocated_amount`, `gl_control_amount` (full basis), `difference`, `is_full_month`.

### 6.3 dim_cost_component
Static rows:
- `component`;
- `component_group` (Drugs and supplies, Pay, Department, Overhead, Head Office);
- `is_true_up`;
- `is_direct`;
- `sort_order`.

---

## 7. KPI definitions (for SSAS)

The warehouse supplies the columns; the measures are DAX.

| KPI | Definition |
|---|---|
| Direct Cost | Σ `cost_amount`, `cost_basis = "direct"` |
| Full Cost | Σ `cost_amount`, `cost_basis = "full"`. Blank when the context contains any branch-month without full cost (coverage guard). |
| Contribution Margin | `Net Revenue After Adjustments` − Direct Cost |
| Contribution Margin % | Contribution Margin ÷ `Net Revenue After Adjustments` |
| Net Margin | `Net Revenue After Adjustments` − Full Cost |
| Net Margin % | Net Margin ÷ `Net Revenue After Adjustments` |
| Margin before Head Office | `Net Revenue After Adjustments` − (Full Cost − `head_office` component) |
| Cost per Encounter | Direct (or Full) Cost ÷ distinct encounters with cost |
| Cost per Bed-day | Full Cost of IP pools ÷ occupied bed-days |
| True-up % | true-up components ÷ their base components (full basis) |
| Full Cost Coverage % | branch-months with full cost ÷ branch-months in context |

**Measure rules:**
- Margin measures use revenue and cost under the same filters. Revenue slices through `Charge Lines`, cost through `Encounter Cost`, and both through the shared dimensions.
- **Dimensions that filter only one side.** Service, Product Category and Item slice revenue but not cost. Cost Component slices cost but not revenue. Margin measures return the "can't be analysed by" message (P41 guards) in those cases.

---

## 8. Testing and reconciliation

### 8.1 Error tests (fail the build)
- Per branch × month × component × basis: `allocated + unallocated = pool` within SAR 1.
- Per branch and full month: Σ full `cost_amount` + unallocated = GL operating cost (excluding components per 4.1) + Head Office share, within SAR 1.
- Per month: Σ Head Office shares = Head Office GL operating cost.
- For both bases, `drugs_supplies` equals `fact_patient_consumption` cost for the month.
- Uniqueness of the grain; no null keys (unknown members are −1).

### 8.2 Warn monitors
- unallocated share above 2% of the pool, by branch, month and component;
- unmapped specialties, HR departments and stores, by SAR amount;
- doctors with pay and no activity;
- true-up above ±15% of its base;
- services without a relative value (fallback used).

### 8.3 SSAS measure tests
`ssas/tests/measures/profitability.json` checks the KPIs on two branch-months against SQL over `gold`:
- one full month (for example Abha 2026-08);
- one direct-only month.

---

## 9. Security and SSAS handoff

- **New table `Encounter Cost`**, related to Date (`month_date_key`), Branch, Patient, Payer, Care Type, Department, Staff (`treating_staff_key`) and Cost Component (`dim_cost_component`).
- **Partitions:** follow the SSAS spec's scheme for the large facts.
- **Row-level security:** branch row-level security as on every fact.
- **`tablePermission 'Encounter Cost'`:** the user must have `Can See Pay = 1` (C8). Doctor pay per doctor is salary, and any partial gate would let full cost minus the other components reveal it. Users without pay access see no cost or margin measures. Margin measures return blank for them.
- **New Profitability perspective:** `Encounter Cost`, `Charge Lines`, `Revenue Adjustments`, the shared dimensions and the measures in section 7. The cost and margin measures are also listed in the Finance and Executive perspectives.
- **`docs/receiving_project_config.md`:** add the measure rules of section 7.

---

## 10. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P7-1 | Finance to review `map_cost_component` and `map_cost_driver_weight`. | Reporting margin to users | Map as in 4.1; all weights 1 |
| O-P7-2 | Theatre cost in the GL: does the OR/Admission service group on IPD identify theatre cost, or is theatre inside IP? | `int_cost_pool_gl` | Theatre pools only from payroll and stores that name a theatre department; GL OR cost stays in IP |
| O-P7-3 | Should net margin deduct claim rejections, write-offs and unpaid patient share? | KPI sign-off | No: charged revenue less post-invoice discount |
| O-P7-4 | Doctors' fees (`DC_DOCTORS_FEE`) for fee-for-service doctors: can they be tied to the doctor? | Doctor margin sign-off | Treated as `department_other` by specialty |
| O-P7-5 | Late GL postings to a closed month: recompute that month or roll the change into the next month? | Scheduling | Recompute the month on rebuild |
| O-P7-6 | Alrabwah has no GL. | — | Direct cost only; full cost blank |
| O-P7-7 | Payroll of branch 8 is identical to branch 7 in Oasis (Phase 4 warn). | Direct cost for branches 7–8 | Costed as loaded; monitor stays |
