# HNH DWH: order fulfilment (Phase 1 extension) design

- **Date:** 2026-10-05
- **Status:** approved 2026-10-05
- **Parents:** `2026-10-01-hnh-dwh-gold-layer-design.md` (architecture, keys, conventions), `2026-10-04-hnh-dwh-phase2-revenue-cycle-design.md` (charges, live-charge rule, product categories)
- **Replaces:** the *Order Fulfillment* Power BI report's dataset `default.mv_orders_fulfillment` (old warehouse). Its model is saved, git-ignored, in `powerbi_tmdl/Order Fulfillment/`.

## 1. Purpose and decisions

Clinical orders (`oasis.orders_master`, `oasis.order_lines`) were not covered by Phase 1 or 2. This extension adds one order-line fact that serves three uses:

1. **Leakage.** Lines ordered but never charged, which is what the *Order Fulfillment* report measures, with its rules corrected.
2. **Turnaround.** Time from order to first delivery.
3. **Ordering patterns.** Volume, cancellations and alternatives by doctor, ordering department, service and category.

Decisions the user made on 2026-10-05:

| # | Decision |
|---|---|
| D1 | **Delivered means charged and not cancelled.** A line is delivered when at least one live charge (`delivery_charge.cancel_flag` null, Phase 2 rule R1) exists on one of its delivery lines. The Oasis line status is kept as its own column. |
| D2 | **All care types are in the fact, with inpatient flagged.** Leak KPIs default to non-inpatient, as the old report did. |
| D3 | **Same-generic substitution counts only when the substitute was charged.** A pharmacy line counts as delivered by substitution only if another line in the same episode, with the same generic, has a live charge. |
| D4 | **Package exclusion is reference data.** Package lines stay in the fact with a flag. The list of included packages is maintained as reference data, loaded once. |
| D5 | **Lines and units are both measured.** The line-based leak rate stays comparable to the old report. Units ordered and delivered give a unit fulfilment rate and a partially-delivered count. |
| D6 | **One turnaround measure:** order time to the first live delivery, the same for every category. |

## 2. Findings that shape the design

### 2.1 The old report's rules

`mv_orders_fulfillment` (old warehouse; definition in `old_dwh_views_definition.csv`) and the report model apply these rules:

- **Grain:** one row per order line. Orders run from the start of last year to yesterday.
- **Scope filters in the report:**
  - `LINE_STATUS NOT IN ('P','Q','X','Cancelled')`;
  - `Is_Excluded_pk = 0`;
  - `CARETYPE != 'I'`.
- **Delivered:** the order line has a delivery-charge row with `CANCEL_FLAG = 'X'` (the old null-replacement for live) and `DOC_ID != 0`, from the start of last year. Otherwise the line is `Undelivered`.
- **Alternatives count as delivered:**
  - A line with `ORIGINAL_ORDER_LINE != 0` is `Alternative`.
  - So is an original line that has any alternative.
  - The report's M query then replaces `Alternative` with `Delivered`.
- **Excluded packages:** product category `PK`, except 46 packages listed by description in `vw_excluded_pakages_order_fulfillment`.
- **Generic rule (DAX `Final_Status`):** a pharmacy line is `Delivered` whenever the same episode has more than one line with the same generic name.
- **Episode attributes:**
  - An inner join to `mv_eligibility` supplies care type and payer. Orders whose episode has no eligibility row are dropped.
  - Payer creditor and company come from `vw_purchasers_new`.
- **Measures:**
  - No. Orders = `COUNT(IOS)`.
  - Lost Orders = lines with `Final_Status = "Undelivered"`.
  - Leak Rate = Lost ÷ Orders.
  - Census = distinct `branch-patient-episode`.
  - Contribution = the share of episodes that contain a category.
  - Leak Rate of Total Lost = the share of lost lines by speciality.
- **Category** (IOS table): `PK` → Package, `LAB` → Lab, `RAD` → Rad, `CON` → Consultation, `MD/MED/PH/CSM/RTL/MLK` → Pharmacy, otherwise Others.
- **Speciality:** the ordering doctor's department from `map_staff_department`, else the doctor's work-entity clinic department.

### 2.2 Defects corrected

Each defect keeps a `legacy_*` field so the old numbers can be reconciled.

| # | Old behaviour | Effect | New rule |
|---|---|---|---|
| L1 | The generic rule marks any duplicated generic as delivered | Lines that were never dispensed count as delivered | D3: the substitute must have a live charge; generics match on `generic_id` |
| L2 | An original line with an alternative is delivered, whether or not the alternative was | Leakage hidden behind undelivered alternatives | The original line counts as delivered only when an alternative line was charged |
| L3 | The delivery join is on `(order_line, encounter, delivery_date)` with `DISTINCT` | An order line with several charges or delivery dates is counted several times | One row per order line; deliveries are summarised per line |
| L4 | Line-based only | 1 of 10 units charged counts as fully delivered | D5: units ordered and delivered are added |
| L5 | Inner join to eligibility | Orders without an eligibility row disappear | Every order line is kept; care type and payer come from `int_episode`, with `Unknown` members |
| L6 | Packages are excluded by description text, written into a view | The list can't be maintained; a renamed product slips through | D4: a reference table, resolved to products per branch, with a warn monitor for names that no longer resolve |

### 2.3 Data (branch 1, measured 2026-10-05)

| Finding | Value |
|---|---|
| F1 | Order lines in 2026: 3,383,399. Line status D 2,332,303; R 643,778; C 406,005; P 1,310; A 3. Alternatives (`original_order_line != 0`): 78,224. |
| F2 | Headers in 2026: attendance type I 610,672; O 523,451; E 74,639; D 132. |
| F3 | June 2026, every line with status D has a live charge (OP 69,447 of 69,447; ER 12,313 of 12,313; IP 169,082 of 169,196). No C line has one. 3–6% of R lines have one. |
| F4 | Live OP lines (D or R) in June 2026: 81,473, of which 11,304 have no live charge (13.9%). |
| F5 | IP has 66,240 open (R) lines in June 2026, mostly standing medication orders. This is why leak KPIs default to non-inpatient. |
| F6 | Each charge reaches its order line through `delivery_charge.delivery_line` → `delivery_lines.order_line`. 30.5M of 30.5M branch 1 delivery lines carry an order line. A few order lines have several delivery lines (5,523 of 169K IP D lines in June). |
| F7 | `order_lines.line_order_date` carries a time for 99.5% of rows. Order and delivery times are stored as UTC-typed KSA wall clock, the same convention as other Oasis timestamps. |
| F8 | Corrected 2026-10-05: `order_lines.generic_id` is only about 0.03% populated. The generic of a line is the IOS master's generic (`stg_oasis__ios_master.generic_id`), else the line's own (89% of 2026 pharmacy lines have one). `oasis.generics` holds the generic names. |

## 3. Architecture

```
oasis.orders_master ─► stg_oasis__orders ─┐
oasis.order_lines   ─► stg_oasis__order_lines ─┤
oasis.generics      ─► stg_oasis__generics ────┤
default.map_order_fulfilment_packages ─► stg_ref__order_fulfilment_packages ─┤
stg_oasis__delivery_lines, stg_oasis__charges (Phase 2) ─┤
int_episode (Phase 1), stg_oasis__ios_master ─┤
                                              ▼
                                       int_order_line
                                              ▼
                                   gold.fact_order_line ─► rec_orders_monthly
```

**Folders:**
- `staging/oasis/` and `staging/reference/` for staging;
- `intermediate/patient_flow/int_order_line.sql`;
- `marts/patient_flow/fact_order_line.sql`;
- `marts/reconciliation/rec_orders_monthly.sql`.

**Rules:** macros go in `macros/hnh/hnh_rules_flow.sql`.

**Conventions as before:**
- `hnh_` macros; `hnh_surrogate_key` returns -1 when any part is null;
- `hnh_settings()`;
- `hnh_ksa_wall_clock` for timestamps;
- history window from `var('hnh_history_start_date')`;
- non-Nullable sort keys.

## 4. Staging

| Model | Source | Notes |
|---|---|---|
| `stg_oasis__orders` | `orders_master` | `branch_id`, `master_order_no`, `patient_id`, `episode_no`, `admission_no`, `orderer_staff_id`, `order_at` (KSA wall clock), header `status`, `attendance_type`, `service_dept`. **`patient_name` is never selected.** |
| `stg_oasis__order_lines` | `order_lines` | `order_line`, `master_order_no`, `ios`, `generic_id`, `units_ordered`, `units_given`, `units_scheduled`, `units_completed`, `status`, `status_reason`, `original_order_line` (0 → null), `urgent_flag`, `order_work_entity`, `line_order_at` (KSA wall clock), `std_price`. Ids cast to `Int64` with `hnh_id`. |
| `stg_oasis__generics` | `generics` | `generic_id`, `generic_name`. |
| `stg_ref__order_fulfilment_packages` | `default.map_order_fulfilment_packages` | One row per included package description (the 46 names). Loaded once by `scripts/load_reference_data.py` from `static_mappings/order_fulfilment_packages.csv` (git-ignored, like the other mapping files). |

Unique tests: `(branch_id, master_order_no)` and `(branch_id, order_line)`.

## 5. Rules (macros in `hnh_rules_flow.sql`)

| Macro | Rule |
|---|---|
| `hnh_order_line_status(status)` | `D` → `Delivered`, `R` or `O` → `Ordered`, `C` → `Cancelled`, `P`, `Q` or `X` → `Not applicable`, else `Unknown` |
| `hnh_order_category(product_category_code)` | `PK` → `Package`, `LAB` → `Lab`, `RAD` → `Radiology`, `CON` → `Consultation`, `hnh_is_medication` codes → `Pharmacy`, else `Others` |
| `hnh_order_fulfilment_status(line_status, has_live_charge, alternative_charged, substitute_charged)` | In order:<br>• `Cancelled` when the line status is `Cancelled`;<br>• `Not applicable` when the line status is `Not applicable` or `Unknown`;<br>• `Delivered` when the line has a live charge;<br>• `Delivered by alternative` when an alternative of it was charged;<br>• `Delivered by substitute` when a same-generic substitute was charged;<br>• else `Undelivered`. |

## 6. int_order_line

**Grain:** one row per `(branch_id, order_line)` whose `line_order_at` (else header `order_at`) falls inside the history window.

**Header:** the order line joins `stg_oasis__orders` on `(branch_id, master_order_no)`.

**Delivery summary per order line:**
- Take the delivery lines of the order line (`stg_oasis__delivery_lines`).
- Take their live charges (`stg_oasis__charges`, `cancel_flag` null).
- Compute:
  - `live_charge_count`;
  - `has_live_charge`;
  - `charged_amount` = Σ live charge net amount, across all bill-to rows of the line;
  - `units_delivered` = Σ quantity of the delivery lines that have at least one live charge. It is counted once per delivery line, so a charge split between purchaser and patient is not double counted;
  - `first_delivered_at` = the earliest delivery time of those delivery lines.

**Alternatives:**
- `is_alternative` is true when `original_order_line` is not null.
- `alternative_charged` is true for an original line when any line whose `original_order_line` is this line has a live charge.

**Substitution (pharmacy only):** `substitute_charged` is true when another line of the same `(branch_id, patient_id, episode_no)` has the same `generic_id` and a live charge.

**Attributes:**
- Category from `stg_oasis__ios_master.product_category_code`, through `hnh_order_category`.
- `is_excluded_package` = category `Package`, and the product's description is not among the reference package descriptions.

**Care type:** from `int_episode` on `(branch_id, patient_id, episode_no)`. When missing, from the header attendance type: `I` → IP, `O` → OP, `E` → ER, else `Unknown`. `is_inpatient` is true when care type is IP.

**Columns:**
- `line_status` (from `hnh_order_line_status`) and `fulfilment_status` (from `hnh_order_fulfilment_status`).
- `is_in_leak_scope` = line status `Delivered` or `Ordered`, and not `is_excluded_package`.
- `is_lost` = in leak scope and `fulfilment_status = 'Undelivered'`.
- `is_partially_delivered` = delivered, with `units_delivered < units_ordered`.
- `order_to_delivery_minutes` = `dateDiff('minute', line order time, first_delivered_at)`. It is null when nothing was delivered, and negative values are kept, with a warn monitor.

**Legacy fields:**
- `legacy_status`:
  - `Delivered` when there is a live charge;
  - `Delivered` when the line is an alternative, or has any alternative;
  - `Delivered` when the line is pharmacy and another line in the episode has the same generic, charged or not;
  - else `Undelivered`.
- `legacy_in_scope`: the old filters (status not P, Q, X or C; not an excluded package; care type not IP).
- `legacy_is_lost`.

The legacy fields ignore the old one-year window and the eligibility inner join. `rec_orders_monthly` documents both.

## 7. gold.fact_order_line

**Grain:** as `int_order_line`. **Sort key:** `(branch_key, order_date_key, order_line_key)`.

| Group | Columns |
|---|---|
| Keys | `order_line_key` (branch, order_line), `order_key` (branch, master_order_no), `branch_key`, `order_date_key`, `order_time_key`, `first_delivery_date_key` (`hnh_date_key_in_range`), `patient_key`, `episode_key` (same hash as the other facts), `payer_key` (episode payer, as `fact_charge_line.episode_payer_key`), `ordering_staff_key` (`dim_staff`), `ordering_department_key` (`order_work_entity` → `hnh_dim_department`), `service_key` (`dim_service`), `product_category_key` (`dim_product_category`), `care_type_key` |
| Attributes | `order_category`, `line_status`, `fulfilment_status`, `status_reason`, `generic_name`, `is_alternative`, `urgency_code` (raw Oasis `urgent_flag`: R, S, H, A; meaning unconfirmed), `is_excluded_package`, `is_inpatient`, `is_in_leak_scope`, `is_lost`, `is_partially_delivered` |
| Measures | `units_ordered`, `units_delivered`, `unit_fulfilment_ratio`, `is_unit_outlier`, `ordered_value` (`units_ordered × std_price`), `charged_amount`, `live_charge_count`, `order_to_delivery_minutes` |
| Legacy | `legacy_status`, `legacy_in_scope`, `legacy_is_lost` |
| Audit | `_loaded_at` |

The unknown member `-1` applies to every key. No patient PII is held.

## 8. KPI definitions (for SSAS)

Every KPI defaults to `is_inpatient = 0`; the leak KPIs also need `is_in_leak_scope = 1`.

| KPI | Definition |
|---|---|
| Order lines | count of lines with `is_in_leak_scope = 1` |
| Lost lines | count of lines with `is_lost = 1` |
| Leak rate | Lost lines ÷ Order lines |
| Lost value | Σ `ordered_value` of lines with `is_lost = 1` and `is_unit_outlier = 0` |
| Unit fulfilment rate | average of `unit_fulfilment_ratio` over lines with `is_in_leak_scope = 1`; outlier lines are deliberately kept (the ratio is capped at 1 per line, so they cannot distort the average) |
| Partially delivered lines | count of lines with `is_partially_delivered = 1`, `is_in_leak_scope = 1` and `is_unit_outlier = 0` |
| Census | distinct `episode_key` among lines with `is_in_leak_scope = 1` |
| Contribution | episodes with at least one `is_in_leak_scope = 1` line of the category ÷ all episodes with `is_in_leak_scope = 1` lines |
| Share of total lost | lost lines in context ÷ lost lines over all selected filters except speciality |
| Order-to-delivery time | median `order_to_delivery_minutes` of delivered lines, per category; Consultation and Package are excluded (their charge is posted at order time) |
| Orders | distinct `order_key` over all lines (not only in-scope) |
| Cancellation rate | lines with `line_status = 'Cancelled'` ÷ all lines (cancelled lines are out of leak scope, so no scope filter) |

## 9. Testing, reconciliation and monitors

**dbt tests:**
- Unique and not-null on `order_line_key`.
- Relationships for every key.
- `accepted_values` on `line_status`, `fulfilment_status` and `order_category`.
- A conservation test: fact rows equal staged order lines in the window.

**Unit tests:** one case per fulfilment rule:
- own live charge;
- cancelled charge only;
- an alternative charged;
- an alternative not charged (L2);
- a substitute with the same generic, charged;
- the same generic but not charged (L1);
- an excluded package and an included package;
- partial units;
- a line with two delivery lines and a charge split across bill-to rows (no double count, L3);
- a missing episode (L5).

**`rec_orders_monthly`:** grain `(branch_key, month_start)`.
- **Legacy columns:** `legacy_lines` and `legacy_lost`, in legacy scope.
- **New columns:** `lines`, `lost`, `delivered_by_alternative`, `delivered_by_substitute`, `excluded_package_lines`, `units_ordered`, `units_delivered`, in new scope, non-inpatient.
- **Acceptance:** the legacy columns are within 1% of the old report for a closed month, after allowing for the eligibility inner join.

**Warn monitors:**
- `warn_delivered_status_without_charge`: line status D with no live charge, by branch and month.
- `warn_charges_without_order_line`: live charges whose delivery line has no order line, or an unknown one.
- `warn_unresolved_order_packages`: reference package descriptions that match no `PK` product in a branch.
- `warn_negative_order_turnaround`: lines delivered before they were ordered.

## 10. SSAS handoff additions

- `fact_order_line` relates to the conformed dimensions as listed in section 7.
- Leak measures filter `is_inpatient = 0` by default.
- The speciality slicer uses `dim_staff` through `ordering_staff_key`. `dim_staff` already derives the doctor's home department; it replaces the old report's `map_staff_department`, falling back to the work-entity clinic.

## 11. Open items

| # | Item | Affects | Until resolved |
|---|---|---|---|
| O-OF-1 | **Status A.** Its meaning is unknown (3 lines in branch 1, 2026). | Line status | Closed 2026-10-05: the user confirmed it stays out of leak scope (`Unknown`) |
| O-OF-2 | **Eligibility join.** The old report also dropped orders whose episode had no `mv_eligibility` row; that view is not in this warehouse. | Legacy reconciliation | Closed 2026-10-05: the user accepted the gap; it is explained in the reconciliation notes |
| O-OF-3 | **Inpatient standing orders.** Open R lines may be scheduled doses, not leakage. | IP leak rate | Closed 2026-10-05: the user confirmed inpatient is excluded from leak calculations, and all inpatient lines stay in the fact for later analysis |
| O-OF-4 | **Branch 8 data gaps.** `dim_patient` holds only 2,554 branch 8 patients, registered from mid-2025, so 61,758 branch 8 order lines from January to May 2026 have `patient_key` -1. 40,400 branch 8 delivered-status lines in 2026 have no live charge. Branch 8 charge and patient data look incomplete. | Branch 8 patient attributes, leak rate | Open |
| O-OF-5 | **Branches 3 and 6 clock skew.** Delivery time precedes order time on 21% (branch 3) and 27% (branch 6) of 2026 lines, by minutes. | Order-to-delivery time | Open; `warn_negative_order_turnaround` flags only gaps above 60 minutes. **Closed 2026-10-07:** known source behaviour, monitored |

## 12. Changes during implementation (2026-10-05)

1. The old view lists 46 included packages, not 45.
2. `fact_order_line` carries the raw `urgency_code` instead of `is_urgent`; the code meanings are unconfirmed.
3. The intermediate layer is two tables: `int_order_line_base` (line, header, episode, category, live-charge summary) and `int_order_line` (alternatives, substitutes, packages, statuses, legacy fields), so the charge join runs once.
4. `rec_orders_monthly` names its unit columns `scope_units_ordered` and `scope_units_delivered`.
5. `warn_unresolved_order_packages` lists package names that match a PK product in no branch.
6. Units delivered per delivery line = sum of live insurer rows (`bill_to` 1) when any exist, else the largest live row (insurers split one delivery into tier rows; a patient co-pay row is a share of the same unit).
7. Leak scope also requires `units_ordered > 0` (non-positive lines are reversals).
8. Partial delivery uses a tolerance of 0.0001 unit.
9. Finding F8 was wrong: `order_lines.generic_id` is about 0.03% populated. The generic of a line is the IOS master's generic (`stg_oasis__ios_master.generic_id`), else the line's own (89% of 2026 pharmacy lines have one). Section 2.3 is corrected.
10. `legacy_status`'s duplicate-generic rule groups the pharmacy lines of an episode by generic name and matches blank with blank, as the old DAX did; the new substitution rule matches by generic id only.
11. `int_order_line` and `fact_order_line` add `unit_fulfilment_ratio` (`least(units_delivered / units_ordered, 1)`) and `is_unit_outlier` (`units_ordered > 1,000`; pharmacy lines ordered in ml or mg while delivered in packs).
12. KPI changes (section 8): Unit fulfilment rate is the average of `unit_fulfilment_ratio` over in-scope lines; Lost value excludes `is_unit_outlier` lines; order-to-delivery time excludes Consultation and Package (charge posted at order time).
13. `rec_orders_monthly`'s unit sums exclude unit outliers, and it adds `avg_unit_fulfilment_ratio` and `unit_outlier_lines`.
14. Monitors: `warn_delivered_status_without_charge` counts lines with `units_ordered > 0` only; `warn_negative_order_turnaround` flags lines delivered more than 60 minutes before the order; a fifth monitor, `warn_order_unit_outliers`, lists outlier lines.
15. `int_order_line.legacy_names` counts only the lines the old report had left after its import filters (line status not P, Q, X or Cancelled, care type not inpatient): the old DAX `Is_Same_Generic` ran over that already-filtered import, so cancelled and inpatient siblings must not turn a line into legacy Delivered. This restores `legacy_lost` to within the 1% band (the unfiltered count understated it by 1.3 to 2.3% a month).
16. The average Unit fulfilment rate keeps unit-outlier lines, a deliberate choice: the per-line ratio is capped at 1, so outliers cannot distort it (the rate moves by about 0.0003 when they are removed). Lost value, Partially delivered lines and the reconciliation unit sums do exclude them.
