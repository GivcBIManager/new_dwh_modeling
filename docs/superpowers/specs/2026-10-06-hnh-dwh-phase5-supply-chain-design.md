# HNH Data Warehouse — Phase 5 Supply Chain: Stock Movements, Patient Consumption, Stock Balances and Purchasing

- **Date:** 2026-10-06
- **Status:** Draft for review
- **Parent specs:** `2026-10-01-hnh-dwh-gold-layer-design.md` (architecture, keys, conventions, security, portability), `2026-10-05-hnh-dwh-phase3-finance-design.md` (Fusion access through `hnh_fusion_source`, business unit → ledger → branch, Head Office = branch 100, `hnh_dim_supplier`, AP, GL balances) and `2026-10-06-hnh-dwh-phase4-workforce-design.md` (per-branch cutover pattern, `source` column). Everything in those specs applies unless this document says otherwise. Section 13 of the parent outlined this phase.
- **Source profile:** measured 2026-10-06 (read-only). The findings are summarised in section 2.

---

## 1. Purpose and decisions

The aim is one supply-chain model for the group. It answers five questions:
- what each store and department consumes, and what it costs;
- what drugs and supplies each patient encounter, doctor and payer uses against the revenue charged;
- how much stock each store holds and how fast it turns over;
- how purchasing performs, from requisition to PO to receipt to supplier invoice;
- whether the stock value ties to the GL.

Decisions made in review (2026-10-06):

| # | Decision |
|---|---|
| S1 | **Fusion after go-live.** Stock movements come from Oasis before each branch's Fusion inventory go-live date and from Fusion from that date on. Purchasing comes from Oasis before each branch's first Fusion purchasing month and from Fusion from that month on. Alrabwah (1) and Head Office (100) are not live on Fusion inventory and stay on Oasis. Alrabwah also stays on Oasis for purchasing. |
| S2 | **The Fusion interface gap is filled from Oasis.** After go-live, an Oasis stock line that has no Fusion transaction yet is taken from Oasis and flagged. As the interface catches up, the line moves to Fusion on the next build. |
| S3 | **A source flag on every row.** Every movement, stock and purchase row carries `source_system` (`oasis`/`fusion`), plus `is_in_oasis` and `is_in_fusion`, which say which systems hold the line. |
| S4 | **Scope:** consumption and cost (patient and department), stock and movements (stock balances, expiry), purchasing (requisitions, POs, receipts, AP match) and the GL inventory tie-out. |
| S5 | **Stock history from the old warehouse snapshots.** The user loads the old server's daily `bal_product_base` (12–24 months) into `default`. Month-end stock comes from those snapshots, then from Oasis daily batch snapshots and Fusion valuation. Months between the last old snapshot and 2026-08-20 are rebuilt from movements and flagged `derived`. Nothing is rebuilt before the first snapshot. |
| S6 | **Costs as recorded.** Unit costs are not corrected or flagged in the facts. One example is CEFODOX at 6,241,137 SAR per bottle in Abha on 2026-06-20. A warning monitor lists outliers for finance. |
| S7 | **Architecture A:** one stock-line fact with a per-branch cutover; a patient-consumption fact built from the sale lines; a month-end stock fact; a purchase-line fact; a goods-receipt fact; reconciliation models. |

---

## 2. Findings that shape the design

Measured 2026-10-06 on `fusion` and `oasis`. All reads used `final`: Oasis `docl` over-counts by about 10% in 2026 without it.

| # | Fact | Consequence |
|---|---|---|
| F1 | 90% of the 1.03M Fusion inventory transactions (2026-02-28 → 10-06) are Oasis integration types: *Oasis Sales Issue* (772k), *Sales Return* (70k), *Transfer Order Issue/Receipt* (41k/45k). Their `transaction_reference` is `<prefix>-<Oasis docl.line_id>`, and 98–99.9% of them match an Oasis line. The prefix is wrong in places: GN on Khamis rows, AB on Unaizah rows, and MU changed to MA in Muhayil. | The Oasis line id is the shared key. The branch comes from the posting organisation. |
| F2 | Fusion holds only 13–54% of the costed Oasis patient-sale lines of 10–25 Sep 2026 (Jazan: about 78% mid-July, 15–20% late September). | Gap fill from Oasis (S2). A daily interface reconciliation. |
| F3 | Inventory organisations resolve to branches through business unit → primary ledger → `hnh_dim_branch.fusion_ledger_id`, for all 106 of 106. Each branch has 12 organisations by suffix: 01 Medical supplies WH, 02 Medications WH, 03 General WH, 04 Pharmacy, 05 Operating rooms, 06 Wards, 07 Clinics, 08 Laboratory, 09 Radiology, 10 Administration, 11 Support services, 12 Assets. Alrabwah also has N01–N04. There are 926 subinventories (IPH, OPH, ORS, ward codes, expiry, damaged and recall stores). | `int_inventory_org_branch`; department from the organisation type and subinventory. |
| F4 | Inventory go-live (first Oasis sales issue in Fusion): Ghirnata 2026-04-26, Abha 2026-05-01, Muhayil 2026-05-03, Jazan 2026-07-12, Unaizah 2026-08-01, Khamis 2026-09-05, Madinah 2026-09-05. Alrabwah and Head Office loaded opening balances on 2026-02-28 and reversed them in March. They have had no activity since 2026-04-11. | `map_scm_cutover` (section 4.2). |
| F5 | Fusion purchasing: Head Office and Alrabwah 2026-03 (Alrabwah's Oasis POs continue to 2026-10), Ghirnata 2026-04, Abha 2026-05, Jazan 2026-07, Unaizah and Muhayil 2026-08, Khamis and Madinah 2026-09. Muhayil never used Oasis POs. Overlap months are small, e.g. Khamis September: 63 Oasis POs against 1,593 Fusion PO distributions. | First Fusion purchasing month per branch in `map_scm_cutover`. Alrabwah has no purchasing month. |
| F6 | `transaction_cost` is null on 99.8% of Fusion transactions. `fact_inventory_valuation` holds cost layers (`quantity`, `unit_cost`, `cost_transaction_type`, `base_txn_type_id`) under a cost transaction id that is not the inventory id. Joining on item + organisation + day + transaction type matches 97.9% (September). | Fusion cost from valuation on that natural key. Fall back to the Oasis line's cost. |
| F7 | `dim_item` is item × organisation (1.87M rows, 22,689 items). The master organisation MST (300000005019401) holds every item; 8,069 are `Deleted-…`. There is one category set, "HNH Catalog", with 283 codes and no medical flag. The Fusion `item_number` never equals the Oasis `product_code`. The integration pairs them almost 1:1 per branch (e.g. Jazan 2,378 Fusion items ↔ 2,375 Oasis products). | Master-org item dimension; derived item crosswalk; drafted item-group map. |
| F8 | Oasis `doc`/`docl` hold every stock document with cost from 2022-01 for branches 1–5, 2024-07 for Abha, 2026-01 for Ghirnata and 2026-06 for Muhayil. Types: INVOICEAR (patient invoice lines, `total_cost`), CREDITAR (credits), STOCKISS/G (ENTT with `pod` = transfer out, without = department issue; BATCH), STOCKRCPT/G (transfer in; CRD = patient return), STOCKRCPT/Y (GRN), CNT (count), PORDER/Y (PO), INVOICEAP. The old views drop PKHEADER lines and `gl_stk = 'R'`. | `int_oasis_stock_line` classifies them (section 4.4). |
| F9 | 100% of costed INVOICEAR lines join `delivery_charge` on (`invoice_no` = `docl.doc_no`, `product_code` through `delivery_lines`) within the branch. Tests: Jazan September 2026, 38,520 lines; Alrabwah March 2025, 36,359 lines. | Patient consumption joins `fact_charge_line`. |
| F10 | Stock balances: `product_base` is current state only, `docl_by_serial` holds daily batch snapshots from 2026-08-20, and Fusion on-hand has two snapshots (2026-09-21 and 09-30) with no value. Fusion valuation accumulates to a period-end quantity and value per item and organisation. Today (M SAR): branch 2 9.98, 3 12.24, 4 9.51, 5 6.13, 6 10.57, 7 17.38, 8 7.78. | Month-end stock sources (section 6.4). |
| F11 | Cost distributions: 22% are accounted (F). Since July 2026 almost all are N or X, and the latest Cost Management SLA date is 2026-09-06. GL inventory (115*) at the latest month: branch 3 21.7M, 4 7.3M, 6 147.5M (CEFODOX), 7 20.6M, none for 2 and 5. | The GL tie-out shows the gap; it is not expected to tie (section 8). |
| F12 | The purchasing chain links: requisition distribution → PO distribution (17,383 of 35,546 come from a requisition) → schedule (100%) → receipt (35% of distributions received) → inventory delivery (`rcv_transaction_id`, 100%) → AP accrual lines (`po_distribution_id`, 9,345 lines, 24.8M SAR). Non-PO AP ITEM lines total 202.7M SAR. Median PO-to-receipt lead time is 11 days (p90 31). 77% of receipts are after the need-by date, which is probably defaulted. There are 192 promised dates. | `fact_purchase_line`, `fact_goods_receipt`; no on-time KPI. |
| F13 | 54% of Fusion transactions use a unit other than the item's primary unit, and item-level conversions are not staged. Oasis lines carry `conv_factor`. | Fusion `primary_quantity`; Oasis quantity ÷ conversion factor. |
| F14 | Data quality: CEFODOX unit cost (S6). Valuation `posted_flag` E on 39,612 layers. Lot expiry dates run from 1930 to 2299 (928 on-hand rows at 2026-09-30 are in expired lots). Muhayil's opening balance (07-30) is after its first sales (05-03). There are 14 negative Fusion on-hand rows. Some `bintran.tran_date` values fall in 2027–2299. | Monitors (section 8). |
| F15 | No Power BI model covers inventory. The old warehouse has 23 supply-chain views: consumption, ABC class (A ≤ 80%, B ≤ 95% of cumulative consumption), outage, pharmacy consumption, transfers, GRN, last PO price. They hard-code pharmacy and expiry store lists per branch. | KPI definitions (section 7); store types from `map_store_department`. |

---

## 3. Architecture

The same layers, tags and folders as earlier phases.

```
models/hnh/staging/fusion/        + stg_fusion__inventory_orgs, __subinventories, __items, __item_categories,
                                    __inventory_transactions, __inventory_valuation, __inventory_onhand,
                                    __inv_transaction_types, __lots, __cost_distributions,
                                    __po_distributions, __po_schedules, __receipt_transactions,
                                    __requisition_distributions
models/hnh/staging/oasis/         + stg_oasis__stock_documents (doc), __stock_document_lines (docl),
                                    __stock_batch_snapshots (docl_by_serial), __stores (control_contexts_data),
                                    __products (product_base, current), __store_requisitions (bintran)
models/hnh/staging/reference/     + stg_ref__scm_cutover, stg_ref__store_department, stg_ref__item_group,
                                    stg_ref__stock_snapshot (bal_product_base)
models/hnh/intermediate/supply/   int_inventory_org_branch, int_item_crosswalk, int_oasis_stock_line,
                                  int_fusion_stock_line, int_stock_month_end
models/hnh/marts/conformed/       hnh_dim_item (alias dim_item), dim_store, dim_movement_type
models/hnh/marts/supply/          fact_stock_movement, fact_patient_consumption, fact_stock_monthly,
                                  fact_purchase_line, fact_goods_receipt
models/hnh/marts/reconciliation/  + rec_stock_interface_daily, rec_inventory_gl_monthly,
                                    rec_consumption_charge_monthly, rec_purchase_ap_monthly
macros/hnh/hnh_rules_supply.sql
```

**Rebuilds and reads.**
- All models are full rebuilds.
- `int_oasis_stock_line` reads about 150M Oasis document lines. It filters to stock lines before any join: `total_cost` ≠ 0, or a stock document type.
- Every Fusion read goes through `hnh_fusion_source(...) final` and every Oasis read through `hnh_oasis_source(...) final`.
- Reference tables are read only through `source('reference', …)`.

**Name collisions.** The receiving project has Fusion models named `dim_item`, `dim_supplier`, `dim_lot`, `dim_subinventory`, `dim_inventory_org`, `dim_uom` and every `fact_inventory_*`, `fact_po_*`, `fact_receipt_transaction` and `fact_requisition_distribution`.
- The item dimension is therefore `hnh_dim_item` with `alias='dim_item'`, as in Phases 3–4.
- Suppliers reuse Phase 3's `hnh_dim_supplier`.
- No other gold name collides.

---

## 4. Reference data and rules

### 4.1 Branch rules
- **Fusion.** An inventory organisation's `business_unit_id` → `stg_fusion__business_units.primary_ledger_id` → `hnh_dim_branch.fusion_ledger_id` gives the branch (`int_inventory_org_branch`). Head Office organisations (RF01–RF03, HQ01, IT_HQ, MST) → 100. An organisation that does not resolve gives branch 0, which a test rejects.
- **Oasis.** The Oasis `branch_id` is the branch.

### 4.2 Tables to be drafted, reviewed and loaded once into `default`
Each draft script lives in `scripts/` and writes a CSV under `static_mappings/`. Both are git-ignored, and the loader never overwrites a table that already has rows.

| Table | Content |
|---|---|
| `map_scm_cutover` | `BRANCH_ID`, `INVENTORY_GO_LIVE_DATE` (yyyy-mm-dd), `FIRST_FUSION_PURCHASING_MONTH` (yyyymm; may be empty). <br>Rows: <br>• 2 → 2026-09-05 / 202609 <br>• 3 → 2026-07-12 / 202607 <br>• 4 → 2026-08-01 / 202608 <br>• 5 → 2026-09-05 / 202609 <br>• 6 → 2026-05-01 / 202605 <br>• 7 → 2026-04-26 / 202604 <br>• 8 → 2026-05-03 / 202608 <br>• 100 → (none) / 202603 <br>Branch 1 has no row. A branch without a go-live date uses Oasis stock throughout; a branch without a purchasing month uses Oasis purchasing. Maintained by the BI manager. |
| `map_store_department` | `SOURCE` (`oasis`/`fusion`), `BRANCH_ID`, `STORE_CODE` (Oasis `c_id`, or Fusion `<org_code>/<subinventory>`), `STORE_NAME`, `STORE_TYPE` (Warehouse, Pharmacy, Operating room, Ward, Clinic, Laboratory, Radiology, Administration, Support, Asset, Expiry/damaged/recall), `UNIFIED_DEPARTMENT`. Drafted by rule from organisation suffixes, subinventory codes and store names. Oasis stores take the type of the Fusion store they map to through the integration. Expiry, damaged and recall stores are recognised by code (EXMED, EXMS, DMED, DAMS, RMED, RMS) and by the name keywords EXPIR/DAMAG/RECALL. |
| `map_item_group` | `CATEGORY_CODE` (one of the 283 HNH Catalog codes), `ITEM_GROUP` (Medication, Medical consumable, Implant, Laboratory, General, Asset, Other). Drafted by keyword rule for review. |
| `bal_product_base` | Loaded by the user from the old warehouse: daily rows per branch, store (`c_id`), product and snapshot date, with `qty_on_hand` and `average_cost`. The column names are confirmed at load; `stg_ref__stock_snapshot` adapts to them. |

### 4.3 Item crosswalk (`int_item_crosswalk`)
- **Derivation.** For each branch, pair the Fusion `inventory_item_id` with the Oasis `product_code` of the Oasis lines referenced by Fusion integration transactions. Where a pair is ambiguous, keep the pair with the most transactions.
- **`dim_item` link.** `dim_item` carries the Oasis product code per branch through this crosswalk.
- **Gap-fill lines.** An Oasis gap-fill line takes its Fusion item from the crosswalk. Where none exists, it gets the Unknown item (-1) and is monitored.

### 4.4 Movement types (`dim_movement_type`, static) and classification
Each line takes one movement type, a direction and two flags:

| Movement type | Oasis | Fusion | Counts as consumption |
|---|---|---|---|
| Patient sale | INVOICEAR line with a stock product; not PKHEADER; `gl_stk` ≠ R | Oasis Sales Issue | yes |
| Patient return | STOCKRCPT/G CRD; CREDITAR stock lines | Oasis Sales Return | yes (negative) |
| Department issue | STOCKISS/G ENTT without `pod`; STOCKISS BATCH for use | Miscellaneous issue to a department organisation; Account Issue | yes |
| Transfer out / Transfer in | STOCKISS/G ENTT with `pod` / its paired STOCKRCPT/G | Oasis Transfer Order Issue / Receipt; Intransit Shipment / Receipt; Transfer Order types | no |
| Goods receipt | STOCKRCPT/Y GRN | Purchase Order Receipt | no |
| Return to supplier | GRN reversal lines | Return to Supplier | no |
| Count adjustment | CNT | Physical Inventory Adjustment | no |
| Write-off / misc | other STOCKISS/STOCKRCPT, BAT- batch postings | Miscellaneous issue/receipt not otherwise classed; Loan in/out | no |
| Opening balance | — | Miscellaneous Receipt with an `OB-` or opening reference, or on a branch's opening date, and its reversals | no |

- **Signs.** Quantity is signed: positive into the store, negative out. Cost follows the quantity's sign.
- **`is_opening_balance`.** Flags opening loads and their reversals. They never count as receipts or consumption.
- **Branch-specific codes.** The exact Oasis `doc_type`/`doc_ind`/`source_code` and Fusion `transaction_type_id` lists are fixed in macro `hnh_movement_type` and unit-tested.

### 4.5 Macros (`hnh_rules_supply.sql`)
- `hnh_movement_type(...)` (4.4).
- `hnh_is_consumption(movement_type)`.
- `hnh_movement_direction(movement_type)`.
- `hnh_oasis_line_ref(reference)`: parses `<prefix>-<line_id>` to the Oasis line id, or null.
- `hnh_primary_qty(qty, conv_factor)`: the quantity divided by the conversion factor when the factor is greater than 0.
- `hnh_abc_class(cum_share)`: A when the cumulative share is ≤ 0.80, B when ≤ 0.95, otherwise C.

---

## 5. Conformed dimensions

### 5.1 hnh_dim_item (alias dim_item)
- **Grain:** one row per Fusion master item (MST organisation).
- **Columns:**
  - item number and description;
  - primary unit;
  - item type and status;
  - lot control;
  - category code and item group;
  - `is_deleted` (`Deleted-…`);
  - Oasis product code and product category per branch through the crosswalk.
- **Oasis-only products** (branches 1 and 100, and products that never moved through the interface) also get rows. Their key is a hash of (branch, product code), with the Oasis product category and `dim_product_category`'s product group.
- **Unknown member:** -1.

### 5.2 dim_store
- **Grain:** one row per Oasis store (branch + `c_id`) and per Fusion store (organisation + subinventory).
- **Columns:** branch, source, name, store type, unified department, `is_expiry_store`.
- **Mapped pairs:** an Oasis store and a Fusion store mapped to each other through the integration share a `store_group_key`, so a store can be followed across the cutover.

### 5.3 dim_movement_type
Static (section 4.4), with `movement_type`, `direction`, `is_consumption` and `sort_order`.

### 5.4 Suppliers and dates
- Fusion suppliers use Phase 3's `hnh_dim_supplier`.
- Oasis suppliers (the account code on PO/GRN documents) are added to `hnh_dim_supplier` as extra rows.
  - Their key is a hash of ('oasis', branch, account code), and the name comes from the Oasis external account.
  - A new `source_system` column marks them.
  - The existing Fusion rows and keys are unchanged.
  - Supplier analysis therefore spans the purchasing cutover in one dimension.
- Dates use `dim_date`.

---

## 6. Facts

### 6.1 fact_stock_movement
**Grain.** One row per stock line.

**Line identity.** The line is identified by the Oasis `line_id` where one exists; Fusion-only transactions (PO receipts, counts, misc, opening balances) are identified by the Fusion transaction id.

**Choosing the source.**
- If the line date is before the branch's inventory go-live date, or the branch has no go-live date, the Oasis line is used (`source_system = oasis`).
- From the go-live date, the Fusion transaction is used when one references the line (`source_system = fusion`). Otherwise the Oasis line is used with `is_fusion_gap = 1`.
- Fusion transactions with no Oasis line are used from the go-live date.
- Fusion rows before the go-live date are left out: pilots, and the Alrabwah and Head Office opening balances and their reversals. They stay visible in `rec_stock_interface_daily`.

**Columns.**
- **Keys:** `movement_key`, `branch_key`, `date_key`, `store_key` (and the counterparty `transfer_store_key`), `item_key`, `movement_type_key`.
- **Source flags:** `source_system`, `is_in_oasis`, `is_in_fusion`, `is_fusion_gap`, `is_opening_balance`, `is_consumption`.
- **References:** Oasis line and document references; Fusion transaction id.
- **Quantity:** `primary_quantity` (signed).
- **Cost:** `unit_cost`, `cost_amount` (signed), and `cost_source` (`fusion_valuation`, `oasis_line` or `none`).
- **Other:** `lot_number`, `expiry_date`.

**Branch.** The Fusion branch comes from the posting organisation.

**Fusion cost.** The unit cost is the quantity-weighted unit cost of the valuation layers with the same item, organisation, day and `base_txn_type_id`. Where there is none, it is the referenced Oasis line's unit cost, converted to the primary unit. Where there is neither, `cost_source = none`.

### 6.2 fact_patient_consumption
**Grain.** One row per patient-sale or patient-return line of `fact_stock_movement`.

**Link to the charge.** Each line is linked through its Oasis invoice line to the charge: `docl.doc_no` = invoice number and `product_code` → `delivery_lines` → `delivery_charge` → `fact_charge_line` (F9). Fusion rows link through their Oasis line.

**Columns.**
- **Carried from the charge:** `encounter_key`, `episode_key`, `patient_key`, `treating_staff_key`, `billed_payer_key`, `care_type_key`, `service_key`, `department_key`.
- **Values:** `primary_quantity`, `cost_amount`, and the charge line's `revenue_amount` for the same line. Revenue is taken once per charge line, never repeated across cost rows.
- **Flags:** `is_linked_to_charge`, plus the source flags from 6.1.

**Answers.** Cost of drugs and supplies, and margin, per encounter, doctor, clinic, payer and care type, from 2022.

### 6.3 Department consumption
There is no separate fact. Department consumption is `fact_stock_movement` with `is_consumption = 1`, sliced by `dim_store` (store type, unified department) and `dim_item` (item group). Transfers are excluded by definition, so group consumption is never double counted.

### 6.4 fact_stock_monthly
**Grain.** One row per branch, store, item and month-end.

**Sources by period** (`stock_source`):

| Period and branch | Source | Quantity and value |
|---|---|---|
| Month-ends covered by `bal_product_base` | the snapshot on the month-end, or the last snapshot day of the month | `qty_on_hand` × `average_cost` |
| After the last old snapshot and before 2026-08-20 | `derived`: the next known balance rolled back by the month's movements (`int_stock_month_end`) | quantity, × the movement's unit cost or the product's average cost |
| From 2026-08-20, branches 1 and 100, and live branches before their go-live | Oasis `docl_by_serial` on the month-end, summed over batches | × Oasis average cost (`product_base`) |
| Live branches from the go-live month | Fusion valuation layers summed to the month-end per item × organisation; the subinventory share comes from Fusion on-hand where available, otherwise the organisation level | Fusion quantity and value |

**Columns.**
- `quantity`, `stock_value`;
- `stock_source` and `source_system`;
- `is_expiry_store`;
- `is_closed_month` (month-end < today);
- `has_expired_lot` (Oasis batch and Fusion lot expiry before the month-end);
- the month's consumption quantity and cost, from `fact_stock_movement`, for turnover and days of stock.

**Summing.** This is a snapshot, so values are never summed across months.

### 6.5 fact_purchase_line
**Grain.** One row per PO line schedule (Fusion `line_location_id`), or per Oasis PORDER line.

**Source.** Oasis before the branch's first Fusion purchasing month (or always, for a branch without one). Fusion from that month on, with `source_system`. Small overlap months keep both systems' POs, because they are different documents. Each carries its source.

**Columns.**
- **Keys:** `purchase_line_key`, `branch_key`, `po_date_key`, `supplier_key`, `item_key`, `ship_to_store_key`.
- **Requisition:** `requisition_number`, `requisition_approved_date_key`.
- **Quantities:** `quantity_ordered`, `quantity_received`, `quantity_cancelled`, `quantity_billed`.
- **Prices and values:** `unit_price`, `ordered_value`, `received_value`.
- **Dates and timing:** `first_receipt_date_key`, `lead_time_days` (PO date to first receipt).
- **Status:** `po_status`, `line_type` (Goods, Services).
- **AP match:** `is_ap_matched` and `ap_matched_amount` (Fusion AP accrual lines by `po_distribution_id`).

**Phase 3 change.** `fact_ap_invoice_line` gains `po_distribution_id` and `rcv_transaction_id`.

### 6.6 fact_goods_receipt
**Grain.** One row per receipt line: Fusion RECEIVE / RETURN TO VENDOR transactions, or Oasis STOCKRCPT/Y GRN lines and their reversals.

**Columns.**
- **Keys:** `branch_key`, `date_key`, `supplier_key`, `item_key`, `store_key`, `purchase_line_key`.
- **Quantities and values:** quantity in the primary unit, `unit_price`, `received_value`, `is_free_of_charge` (Oasis bonus quantity).
- **Lot:** lot and expiry.
- **Source:** `source_system`.

---

## 7. KPI definitions (for SSAS)

| KPI | Definition |
|---|---|
| Consumption (quantity, cost) | Σ `fact_stock_movement` where `is_consumption = 1`, signed (patient sales − patient returns + department issues). Transfers and opening balances are never included. |
| Patient consumption cost | Σ `fact_patient_consumption.cost_amount`. |
| Drug and supply margin | Σ revenue − Σ cost over `fact_patient_consumption` lines linked to a charge. Margin % = margin ÷ Σ revenue (a ratio of sums). |
| Pharmacy consumption | Consumption at stores of type Pharmacy, plus items of group Medication issued from wards. This replaces the hard-coded store lists. |
| Stock value | `fact_stock_monthly.stock_value` at the last month-end of the selection, excluding expiry stores. |
| Days of stock | Stock value at the month-end ÷ (the month's consumption cost ÷ days in month). |
| Inventory turnover | Consumption cost of the last 12 months ÷ average month-end stock value of those months. |
| Slow-moving / dead stock | Items with positive stock and no consumption in the last 90 / 180 days. |
| Near-expiry stock | Stock in lots expiring within 90 days of the month-end. |
| ABC class | Per branch, items ranked by average monthly consumption cost over the last 12 months: A to 80% of the cumulative share, B to 95%, C after that. |
| PO lead time | Median and average `lead_time_days` of received lines. |
| Fill rate | Σ quantity received ÷ Σ (quantity ordered − quantity cancelled). |
| Last PO price | `unit_price` of the latest PO line per item and supplier. |
| Price change | The latest PO unit price ÷ the previous PO unit price for the same item, − 1. |
| PO-matched spend share | AP matched to POs ÷ total AP (with Phase 3's `fact_ap_invoice_line`). |
| Fusion interface gap | Lines with `is_fusion_gap = 1` ÷ lines on or after go-live (`rec_stock_interface_daily`). |

---

## 8. Testing and reconciliation

**Tests.**
- **Keys:** unique and not-null on every key and fact grain.
- **Relationships:** a test on every fact key (branch, date, store, item, movement type, supplier, encounter, staff, payer, service).
- **Branch:** no fact row has branch 0.

**Conservation (error severity).**
- Every in-scope Oasis stock line before go-live, and every Oasis line or Fusion transaction from go-live, appears in `fact_stock_movement` exactly once.
- No Oasis line appears twice: as itself and through a Fusion transaction.
- The patient-consumption row count equals the patient sale and return rows of `fact_stock_movement`.
- `fact_purchase_line` covers every Fusion PO schedule in scope.

**Unit tests.**
- The cutover day: the day before go-live is Oasis, the go-live day is Fusion.
- The gap fill.
- Branch from the posting organisation when the prefix is wrong.
- Transfer pairing and its exclusion from consumption.
- Opening balances and their reversals.
- Fusion cost from valuation, and the fallback to Oasis cost.
- The month-end stock source switch: snapshot → derived → Oasis batch → Fusion valuation.
- Lead time and fill rate.
- Revenue counted once per charge line.

**Reconciliation models.**
- `rec_stock_interface_daily`: per branch and day, Oasis stock lines against Fusion integration transactions (count, quantity, cost), plus the gap share. Pre-go-live Fusion rows are shown here.
- `rec_inventory_gl_monthly`: per branch and month:
  - Fusion valuation stock value at month-end;
  - the GL balance of the inventory accounts (115*) from `fact_gl_balance_monthly`;
  - the accounted share of cost distributions;
  - the difference.

  The difference is not expected to be zero from July 2026 (F11). Abha carries CEFODOX as recorded.
- `rec_consumption_charge_monthly`: per branch and month, patient consumption cost against the revenue of the same charge lines, plus counts of sale lines without a charge and stock charges without a cost.
- `rec_purchase_ap_monthly`: per branch and month, received value against PO-matched AP value, plus non-PO AP spend.

**Warning monitors (warn severity).**
- Fusion interface gap above 20% of lines in a closed day.
- Unit cost above 20 × the item's median unit cost (listed, not changed).
- Movements with item -1 or an unmapped store.
- Negative month-end stock.
- Positive stock in expired lots.
- An opening balance dated after a branch's first sale.
- `Deleted-` items with movements.
- PO lines without a supplier.
- Valuation layers with `posted_flag` E.
- Oasis movement dates after today.

---

## 9. Security and SSAS handoff

**Perspective and role.** Cost, margin and purchase price facts sit in a finance and supply-chain perspective and role: `fact_stock_movement`, `fact_patient_consumption`, `fact_stock_monthly`, `fact_purchase_line` and `fact_goods_receipt`. Every fact joins `dim_branch`, so branch row-level security applies. `fact_patient_consumption` carries keys only, no names.

**Notes for the SSAS model (go in `docs/receiving_project_config.md`):**
- **Month-end stock.** `fact_stock_monthly` is a snapshot: use the last month or an average, and filter `is_expiry_store = 0` for stock KPIs.
- **Consumption.** Use `is_consumption = 1`. Transfers move stock but are not consumption.
- **Source flags.** Every row has `source_system`. `is_fusion_gap` marks Oasis lines that Fusion has not received yet.
- **Margin.** Margin uses revenue once per charge line.
- **Costs.** Costs are as recorded. Check the unit-cost monitor before publishing a month.

---

## 10. Open items

| # | Item | Owner |
|---|---|---|
| O-P5-1 | The Fusion interface gap (F2): is it an integration backlog or a staging-extract gap? Could `CST_INV_TRANSACTIONS` (cost ↔ inventory transaction id) be ingested, for exact Fusion costing? | Ingestion owner |
| O-P5-2 | The CEFODOX unit cost (6,241,137 SAR per bottle, Abha, 2026-06-20) distorts Abha stock and GL inventory. The data is kept as recorded until finance corrects it. | Finance |
| O-P5-3 | Fusion cost accounting has been mostly unaccounted since July 2026, so the GL tie-out will not tie. | Finance |
| O-P5-4 | Review the drafted `map_store_department` and `map_item_group`. | BI manager |
| O-P5-5 | Load `bal_product_base` into `default` (daily, 12–24 months) and confirm its column names. | User |
| O-P5-6 | Alrabwah's and Head Office's reversed Fusion opening balances: confirm they are not live on Fusion inventory, and set their go-live dates in `map_scm_cutover` when they move. | BI manager |
| O-P5-7 | Muhayil's opening balance is dated after its first sales, so Fusion month-end stock for May–July 2026 is not reliable. | BI manager |

---

## 11. Changes during implementation (2026-10-06)

Pre-flight rulings:

- `rec_purchase_ap_monthly` and `rec_inventory_gl_monthly` take their month from `assumeNotNull(...)` of the AP accounting date and the GL date, because the server has `allow_nullable_key = 0` and a Nullable sort key would fail the build (E1, E2).
- `stg_ref__stock_snapshot` wraps every column in `assumeNotNull` / `ifNull` to its declared type, so a Nullable-loaded `bal_product_base` keeps the declared types (E3).
- `rec_consumption_charge_monthly` links charges exactly as `fact_patient_consumption` does (invoice and product to the delivery lines, then the live charge lines), through one shared intermediate model, the new `int_consumption_charge_link`, with a unit-test row for the two-dispense case (E4).
- The derived month-end rollback reverses every movement that changed Oasis on-hand, so it reads `int_oasis_stock_line` (all in-scope Oasis lines, including post-go-live batch lines and lines represented by Fusion rows) instead of the Oasis rows of `fact_stock_movement` (E5).
- `fact_goods_receipt` includes Oasis returns to supplier (STOCKISS RFN) as `RETURN TO VENDOR` with negative quantity, symmetric with Fusion (E6).
- `is_in_oasis` and `is_in_fusion` exist only where a line can be in both systems (`fact_stock_movement`, `fact_patient_consumption`); the other supply facts carry `source_system` (E7, refines S3).
- The draft scripts for `map_store_department` and `map_item_group` are committed, as in Phase 4; only their CSV outputs are git-ignored (E8, corrects spec 4.2).
- `fact_stock_monthly` groups and hashes on the resolved keys (`ifNull(store_key, -1)`, `ifNull(item_key, -1)`) and has a `hnh_unique_combination` test on branch, month end, store and item (E9); `int_stock_month_end` ends with the trailing settings clause (E13).
- Oasis received quantity on PO lines uses the same GRN filters as `fact_goods_receipt` (E10).
- The `units_per_primary` not-null test became a singular test (`units_per_primary <= 0`), and the `snapshot_date` not-null test on an `assumeNotNull` column was dropped, because neither could fail (E11).
- Two macros, `hnh_stock_item_key` and `hnh_fusion_store_key`, are the single recipe for item and store keys (E12).

Task rulings:

- The Task 1 line-reference test fails on a null parse, and `hnh_fusion_store_key` folds an empty subinventory to `*` like a null one.
- `stg_oasis__products` keeps one row per branch, store and trimmed product code, preferring the untrimmed raw code and then the larger on-hand quantity.
- Oasis batch expiry dates before 2000-01-01 mean "no expiry": `int_oasis_stock_line` and `int_fusion_stock_line` set `expiry_date` to null, so expired-lot flags, near-expiry and `warn_stock_in_expired_lots` inherit the rule (the expiry-before-2000 rule; Fusion lot and expiry are taken from the same lot with expiry from 2000 on).
- The `units_per_primary` ratio uses pack-size buckets, `if(r >= 1, round(r), 1 / round(1 / r))`, instead of `round(r, 4)`, because Fusion primary quantities carry five decimals and one pack factor split across buckets.
- `hnh_dim_item` is one row per Fusion master item and lists all its Oasis product codes in `oasis_product_codes` (branch:product, ...), so an item with two Oasis products cannot fan out.
- `int_fusion_stock_line` has a fifth reference status, `oasis_out_of_scope`, with `oasis_scope_reason` (reversed invoice, CREDITAR, PKHEADER, zero-cost non-stock, other); `fact_stock_movement` drops such a Fusion row only when an explicit Oasis rule excluded its Oasis line and keeps the rest as Fusion-only lines.
- `valuation_unit_cost` is null when the weighted layer cost is 0, so those rows fall back to the Oasis line cost.
- A new column `oasis_cost_amount` (the referenced Oasis line's cost) and a flag `is_cost_mismatch` (Fusion and Oasis cost differ by more than 2x on the same line) were added to `fact_stock_movement`, and carried to `fact_patient_consumption`, because Fusion pack-item costs in five branches equal one base unit's Oasis cost; the new monitor `warn_cost_mismatch` reports it by branch and month.
- The near-zero quantity guard: in `int_oasis_stock_line` a primary quantity with absolute value below 1e-6 is 0 and its unit cost is null (1,926 lines), so no derived unit cost multiplies a Fusion quantity into an absurd cost.
- `fact_patient_consumption` gains `revenue_basis` (`charge`, `package_component`, `cancelled`, `none`); `is_linked_to_charge` counts live charges only; `rec_consumption_charge_monthly` margin and `linked_consumption_cost` cover `revenue_basis = 'charge'`, with `package_component_cost` and `cancelled_only_cost` as separate columns and a new `linked_consumption_cost_oasis` column.
- `int_store_crosswalk` (new model) maps Oasis stores to Fusion stores from the integration references, giving the `store_group_key` of spec 5.2.
- `warn_unit_cost_outliers` keeps the 20x item-median rule but lists only rows with an absolute cost of at least 10,000 SAR and excludes transfers (371 rows instead of 56,864).
- `rec_stock_interface_daily` closes exactly: `oasis_lines_in_fusion` excludes post-go-live batch lines, and the new columns `fusion_out_of_scope_reversals` and `fusion_out_of_scope_kept` show the out-of-scope Fusion rows; `warn_opening_balance_after_first_sale` compares the earliest opening date with the first sale.
- `fact_patient_consumption` takes its charge keys (encounter, payer and the rest) from the lowest live charge, falling back to a cancelled one when the line has no live charge.
- `int_store_crosswalk` folds an empty subinventory to `*`, like `hnh_fusion_store_key`.
- Fusion month-end source precedence picks Fusion only where its valuation has layers for the branch by that month-end, otherwise the next available source.
- `lead_time_days` is null when negative; `fact_goods_receipt` gains `is_po_receipt` (Fusion RECEIVE rows with no PO line are internal receipts), which supplier KPIs filter; `is_ap_matched` rests on spend lines (not tax-only) and stays 1 for schedules whose AP lines net to 0; the YAML documents `quantity_received` as net of returns for Fusion and gross GRN for Oasis.
- Fusion HR staging (positions, jobs, grades, locations, HR departments, organizations, absence types and plans) keeps the latest row per id rather than current rows only, with is_current exposed, so end-dated members referenced by facts stay in the dimensions.
