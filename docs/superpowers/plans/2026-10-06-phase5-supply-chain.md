# Phase 5 — Supply Chain: Stock Movements, Patient Consumption, Stock Balances and Purchasing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the supply-chain gold layer: Fusion SCM and Oasis stock staging, an inventory-organisation and item crosswalk, one stock-line fact with a per-branch Oasis-to-Fusion cutover and gap fill, patient consumption linked to the charge, month-end stock from four sources, purchase lines and goods receipts with AP match, reconciliation models and monitors.

**Architecture:** Fusion inventory, valuation and procurement tables are staged through `hnh_fusion_source()` with `final`; Oasis `doc`/`docl`/`docl_by_serial`/`product_base`/`bintran` through `hnh_oasis_source()` with `final`. Two intermediates classify every Oasis stock line and every Fusion transaction; the stock-line fact picks one source per line (Oasis before the branch's inventory go-live, Fusion from it, Oasis gap fill where Fusion has no transaction yet). Patient consumption, month-end stock and purchasing facts build on those. Rules are `hnh_` macros tested with literals; multi-row rules are dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 with `clickhouse_connect`.

**Spec:** `docs/superpowers/specs/2026-10-06-hnh-dwh-phase5-supply-chain-design.md` (parents: `2026-10-06-hnh-dwh-phase4-workforce-design.md`, `2026-10-05-hnh-dwh-phase3-finance-design.md`, `2026-10-01-hnh-dwh-gold-layer-design.md`)

**Prerequisite:** Phases 1–4 are on `main` and `python scripts/run_dbt.py build --select tag:hnh` passes. Work happens on branch `phase5-supply-chain` (created; the spec is committed there).

## Global Constraints

- All earlier-phase constraints apply: databases `stg` / `int` / `gold`; never write to `oasis`, `fusion`, `press_ganey`; models, macros and tests only under `hnh/` folders; macros prefixed `hnh_`; no packages, no seeds; `branch_id` / `branch_key` are `UInt8`; keys through `hnh_surrogate_key`; YAML uses the `tests:` key.
- **A ClickHouse SETTINGS clause after `union all` binds only to the last branch.** Every CTE (or union branch) that contains a left join whose NULLs matter ends with its own `{{ hnh_settings() }}` and a one-line comment; every model with a left join keeps its trailing `{{ hnh_settings() }}`. The SQL below already does this; keep it.
- **Sort-key columns are non-Nullable.** Use `assumeNotNull` or `ifNull` where a column is filtered non-null. Fact dimension keys are never null (missing → `-1`).
- **Alias shadowing.** In ClickHouse a select alias equal to a source column used inside an aggregate of the same select fails with ILLEGAL_AGGREGATION (error 184); an alias equal to a column also replaces that column in later expressions of the same select. The SQL below uses distinct aliases (`fl_*`, `part_*`, `k_*`); keep them.
- Fusion tables are read only as `{{ hnh_fusion_source('<table>') }} final`. Fusion SCM tables have no SCD columns; their `*_date_key` columns are Int64 yyyymmdd. Oasis tables are read only as `{{ hnh_oasis_source('<table>') }} final` (docl over-counts by about 10% without `final`). Reference tables only through `source('reference', ...)`.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root; add `--no-partial-parse` after YAML or unit-test edits. Ad hoc reads through `scripts/ch_env.py` (`from ch_env import client`); never the machine-wide `CLICKHOUSE_PASSWORD`.
- **Memory.** The ClickHouse server has no `max_memory_usage` (216 GiB RAM). While this plan was written, one ad hoc query that inlined `int_oasis_stock_line` three times (through ephemeral models) used 166 GiB and the server restarted. Build the Phase 5 models as tables, in task order, and never run an ad hoc query that re-computes `int_oasis_stock_line` or `fact_stock_movement` from staging; query the built tables. Each heavy task records the peak memory of its build (query in the task) and reports BLOCKED if a single model exceeds 100 GiB.
- Names that exist in the receiving project's models carry the `hnh_` prefix and an alias: `hnh_dim_item` → `dim_item` (new), `hnh_dim_supplier` → `dim_supplier` (Phase 3). Checked against `dbt/models`: no other Phase 5 name (staging, intermediate, mart or reconciliation) collides; `dim_store`, `dim_movement_type`, `fact_stock_movement`, `fact_patient_consumption`, `fact_stock_monthly`, `fact_purchase_line`, `fact_goods_receipt` and the `rec_*` names are free.
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, and an `order_by` starting with `branch_key`.
- Reference CSVs under `static_mappings/` are git-ignored (`*.csv`) and never committed; the draft scripts are committed; `scripts/load_reference_data.py` never overwrites a table that has rows. The `bi_users` password column is never loaded.
- **Unit tests** live in `*_unit_tests.yml`, use `format: sql`, mock every `ref()` of the model with only the columns it reads, and may set `overrides: vars:`. **Fixtures cannot call `hnh_` macros.** Where a fixture needs a surrogate key it uses the inline form of `hnh_surrogate_key` (no nulls in fixtures):
  - one column: `toInt64(bitShiftRight(cityHash64(concat(toString(A), '|')), 1))`
  - two columns: `toInt64(bitShiftRight(cityHash64(concat(toString(A), '|', toString(B), '|')), 1))`
  - three columns: `toInt64(bitShiftRight(cityHash64(concat(toString(A), '|', toString(B), '|', toString(C), '|')), 1))`
  Every unit test below was run against the model SQL with these exact fixtures during planning (read-only) and returned the expected rows.
- Commit messages end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (the commit commands below pass it as a second `-m`).
- Counts quoted as "measured" were read on 2026-10-06 and grow daily; a build within about 2% of them, or above them by the days since, is correct. Report every measured count you are asked to record.

### Spec refinements made while planning

| Spec says | Plan does | Why (measured 2026-10-06) |
|---|---|---|
| One macro `hnh_movement_type(...)` (4.4, 4.5) | `hnh_oasis_movement_type(doc_type, source_code, has_pod)` and `hnh_fusion_movement_type(type_id, quantity, org_type_code, is_opening_balance)`, plus `hnh_oasis_direction`, `hnh_is_opening_balance`, `hnh_org_type_code`, `hnh_oasis_po_status`, `hnh_fusion_integration_type_ids` | The two systems classify on different inputs. |
| Patient return includes "CREDITAR stock lines" | CREDITAR is not a stock line; patient returns are STOCKRCPT CRD (and the 173 STOCKRCPT SALES return lines) | 2022+ CREDITAR carries −655M SAR on 18.3M costed lines and credits the reversed invoices (INVOICEAR with `gl_stk` R: 643M SAR, 18.1M lines), which are already left out; counting it would subtract the same sales twice. The legacy views do the same. |
| "STOCKISS BATCH for use" is a department issue; BAT- postings are misc | BATCH lines are Write-off / misc before the branch's go-live and are **left out** from the go-live (both the Oasis line and any Fusion transaction that references it) | After each go-live the Oasis GRNs stop and Oasis BATCH receipts appear at the rate of Fusion PO receipts (Jazan August 1,596 BATCH lines vs 1,568 Fusion PO receipts; September 1,584 vs 1,636): they echo Fusion transactions that are already lines of their own. 22,503 lines. |
| Return to supplier = "GRN reversal lines" | Return to supplier = STOCKISS source RFN | No GRN line has a negative quantity (0 of 392k); RFN documents are refunds to suppliers (narratives "REFUND TO SUPPLIER", "EXPIRED RETURN TO SUPPLIER", "RECALLED"). 6,862 lines. |
| The Fusion type gives the movement type | A Fusion transaction that references an Oasis line takes **the Oasis line's** movement type; the Fusion type is used only for Fusion-only transactions | "Oasis Sales Issue" also references department issues (11,899 lines after go-live), count lines (8,736) and batch lines. |
| One row per Fusion transaction | The Fusion transactions that reference one Oasis line are summed into that line's row (quantity, valuation cost; lowest transaction id kept, `fusion_transaction_count`) | 3,483 lines are referenced two or three times, nearly all "issue, issue, return" in Ghirnata (a double posting and its correction), which nets to one line. |
| Every Fusion transaction from go-live is used | Integration transactions without a parseable reference are left out (their Oasis line is gap-filled); a reference to a line Oasis does not hold makes a Fusion-only line | 38,406 rows have no reference (Apr–Jul, Abha and Ghirnata, whose Oasis lines exist); 8,282 reference no Oasis line (mainly Muhayil before its Oasis history starts on 2026-06-16). |
| — | A line with an Oasis line id keeps the Oasis date also when it is taken from Fusion; the Fusion date is kept as `fusion_transaction_date_key` | 30% of matched Fusion transactions post on a later day; a line moving to Fusion (S2) must not change day or month. |
| `hnh_primary_qty(qty, conv_factor)` = qty ÷ conversion factor | `hnh_primary_qty(qty, units_per_primary)`, where `int_item_crosswalk.units_per_primary` is the modal ratio of the Oasis base-unit quantity to the Fusion primary quantity over the product's integration lines | Oasis `qty_change` is always in base units (tablets); `conv_factor` is the size of each line's own unit, which differs by line. The Fusion primary quantity equals Oasis qty ÷ conv_factor on 156 of 282k matched September sales issues; the modal ratio holds on 751,690 of 855,806 matched lines, and 5,338 of 14,893 crosswalk pairs have a factor above 1 (packs). |
| Oasis cost from the line | `total_cost`, or quantity × `unit_cost` where `total_cost` is 0 | Patient returns (CRD: 2 of 181,888 lines costed) and counts (CNT: none costed) carry only a unit cost; the legacy views value CRD the same way. |
| Valuation layers with `posted_flag` Y | Layers Y and E are used for unit costs and stock value; E layers are monitored | E layers (39,612, nearly all in October) carry real cost; without them October's natural-key match falls from 99.8% to 43%. |
| Valuation joined on item + organisation + day + type | The day is `cost_date` | September match 97.9% with `cost_date`, 30.2% with `layer_eff_date`. |
| Charge link: `docl.doc_no` = `invoice_no` and product → `delivery_lines` → `delivery_charge` → `fact_charge_line` | invoice + product → the delivery lines named by **any** charge row of that invoice (also superseded rows) → the live `fact_charge_line` rows of those delivery lines | On Jazan 1–7 Sep 2026, 4,779 of 19,604 invoice-product keys reach only superseded (cancel flag R) charge rows, which `fact_charge_line` drops; through the delivery line 20,663 of 20,790 lines (99.4%) reach a live charge. `fact_charge_line` already holds `invoice_doc_no` and `delivery_line`; `stg_oasis__delivery_lines` gains `product_code`. |
| Revenue once per charge line | Each charge line's revenue goes to the linked patient-sale line with the lowest Oasis line id; patient returns carry the keys but no revenue | Two dispenses of one drug on one invoice link to the same delivery lines. |
| Oasis purchasing before the first Fusion purchasing month | Oasis PO lines are kept up to and including that month (the overlap month); Fusion schedules from it | The spec keeps both systems' POs in overlap months; 1,439 Oasis PO lines fall in them (Khamis 321, Jazan 449, Madinah 37, Abha 232, Ghirnata 400). No Oasis PO is dated after its overlap month. |
| Requisition fields on every PO line | Null on Oasis lines; `bintran` is staged but not linked | No Oasis PO references a purchase requisition (0 of 46,475 POs since 2025 match a `bintran` PR number; PO lines have no `rec_line_id`). |
| `bal_product_base` columns branch_id, c_id, product_code, snapshot date, qty_on_hand, average_cost | `stg_ref__stock_snapshot` expects the old warehouse's names `BRANCH_ID`, `C_ID`, `PRODUCT_CODE`, `Snapshot_timestamp`, `QTY_ON_HAND`, `AVERAGE_COST` (from the legacy `vw_inventory_analysis`), set once in a `cols` dict | One place to adapt; the model returns no rows until the table exists (checked: it compiles and returns 0 rows today). |
| Oasis batch snapshot quantity | `docl_by_serial.qty_outstanding`; a version date loaded twice keeps its latest `version` | `cnt` is a row count: Jazan 2026-10-05 Σ`cnt` 10,065 against Σ`qty_outstanding` 3,072,936 and `product_base` on hand 3,045,358; valued at average cost 9.88M against 9.84M. Three dates (08-20, 09-02, 09-30) hold two versions. |
| Fusion month-end split by on-hand "otherwise the organisation level" | The organisation level is a `dim_store` member per organisation with subinventory `*` (`<org code>/*`) | A store key is needed for stock valued without a split. |
| — | Extra models: `stg_fusion__inventory_transaction_lots`, `stg_fusion__po_line_types`, `int_store_crosswalk` | Lot numbers, Goods/Services line types and the `store_group_key` of spec 5.2. |
| `hnh_dim_supplier` gains `source_system` | Also `supplier_code` (String) and `oasis_branch_key` | `supplier_number` is Int64 and cannot hold Oasis account codes such as `210103-901`. |
| Consumption = Σ signed quantity of consumption rows | `fact_stock_movement` and `fact_stock_monthly` carry `consumption_quantity` / `consumption_cost` (= −quantity / −cost on consumption rows, 0 otherwise) | KPIs sum a positive measure; store-side signs stay on `primary_quantity` / `cost_amount`. |
| Purchase quantities | In each system's ordering unit (`uom_code`: Oasis base unit, Fusion PO unit) | Item-level unit conversions are not staged in Fusion (spec F13); values (SAR), lead time and fill rate are unit-free. |
| Goods receipts by source | Oasis GRN lines from the history start (also after the cutover: receipts of overlap-month Oasis POs); Fusion RECEIVE / RETURN TO VENDOR from the first Fusion purchasing month | Khamis received 398 Oasis GRN lines in September after its Fusion purchasing month began. |
| — | Vars `hnh_fusion_inventory_start` ("2026-02-01"), `hnh_fusion_item_master_org_id` (300000005019401), `hnh_stock_month_end_last` ("") | Integration window, item master organisation, and a fixed last month-end for unit tests. |

## Review Focus

1. **An Oasis line posted twice in Fusion and corrected by a reversal** (3,483 lines, mostly Ghirnata): exactly one row, the net quantity −4 and cost −40, `fusion_transaction_count` 3. Pinned in Task 8 (`fact_stock_movement_switches_at_go_live`, line 106).
2. **A Fusion reference with the wrong branch prefix** (GN- on Khamis rows): the branch and the Oasis line come from the posting organisation (Khamis line 555, not Ghirnata's). Pinned in Task 6 (`int_fusion_stock_line_resolves_lines_and_costs`, transaction 1).
3. **A product sold in tablets but stocked in Fusion in packs of 30**: quantities convert by the modal ratio (30), and a minority ratio does not win (P2: 1, not 10). Pinned in Task 5 (`int_item_crosswalk_picks_the_dominant_pair`).
4. **An invoice that dispenses the same drug twice, with a co-pay row and a superseded charge row**: revenue 70 + 50 counted once (line 11 and line 15), never on line 12 or the return. Pinned in Task 9 (`fact_patient_consumption_counts_revenue_once`).
5. **An Oasis batch posting after go-live** (echo of a Fusion PO receipt): left out, not gap-filled. Pinned in Task 8 (`fact_stock_movement_switches_at_go_live`, line 105).

## File Structure

```
scripts/load_reference_data.py                   + map_scm_cutover, map_store_department, map_item_group (+ d_null converter)
scripts/draft_store_department_map.py             draft store type and unified department (organisation suffix, integration pairing, keywords)
scripts/draft_item_group_map.py                   draft item group per HNH Catalog category (keywords)
static_mappings/ (git-ignored)                    scm_cutover.csv, store_department_mapping.csv, item_group_mapping.csv
hnh_dwh/dbt_project.yml                           + vars hnh_fusion_inventory_start, hnh_fusion_item_master_org_id, hnh_stock_month_end_last
hnh_dwh/macros/hnh/hnh_rules_supply.sql           movement types, direction, consumption, opening balance, line reference, primary qty, ABC, org type
hnh_dwh/tests/hnh/assert_hnh_supply_macros.sql and the supply assert_/warn_ tests (Tasks 8, 9, 11, 12)
hnh_dwh/models/hnh/staging/fusion/                + 16 stg_fusion__ SCM views (Task 3); stg_fusion__ap_invoice_distributions + rcv_transaction_id (Task 11)
hnh_dwh/models/hnh/staging/oasis/                 + stg_oasis__stock_documents, __stock_document_lines, __stock_batch_snapshots, __stores,
                                                    __products, __store_requisitions; stg_oasis__delivery_lines + product_code
hnh_dwh/models/hnh/staging/reference/             + stg_ref__scm_cutover, stg_ref__store_department, stg_ref__item_group, stg_ref__stock_snapshot
hnh_dwh/models/hnh/intermediate/supply/           int_inventory_org_branch, int_item_crosswalk, int_oasis_stock_line, int_fusion_stock_line,
                                                    int_store_crosswalk, int_stock_month_end, _supply__models.yml, _supply_unit_tests.yml
hnh_dwh/models/hnh/marts/conformed/               + hnh_dim_item (alias dim_item), dim_store, dim_movement_type; hnh_dim_supplier + Oasis suppliers
hnh_dwh/models/hnh/marts/supply/                  fact_stock_movement, fact_patient_consumption, fact_stock_monthly, fact_purchase_line,
                                                    fact_goods_receipt, _supply_marts__models.yml, _supply_marts_unit_tests.yml
hnh_dwh/models/hnh/marts/finance/                 fact_ap_invoice_line + po_distribution_id, rcv_transaction_id
hnh_dwh/models/hnh/marts/reconciliation/          + rec_stock_interface_daily, rec_inventory_gl_monthly, rec_consumption_charge_monthly,
                                                    rec_purchase_ap_monthly
docs/reconciliation_phase5.md, docs/receiving_project_config.md
```

---

### Task 1: Supply macros and vars

**Files:**
- Modify: `hnh_dwh/dbt_project.yml` (vars)
- Create: `hnh_dwh/macros/hnh/hnh_rules_supply.sql`, `hnh_dwh/tests/hnh/assert_hnh_supply_macros.sql`

**Interfaces:**
- Produces: `hnh_fusion_integration_type_ids()` (SQL tuple), `hnh_oasis_movement_type(doc_type, source_code, has_pod)`, `hnh_oasis_direction(doc_type)` (Int8), `hnh_is_opening_balance(transaction_type_id, reference)` (UInt8), `hnh_fusion_movement_type(transaction_type_id, primary_quantity, org_type_code, is_opening_balance)`, `hnh_is_consumption(movement_type)` (UInt8), `hnh_movement_direction(movement_type)` (Int8), `hnh_oasis_line_ref(reference)` (Nullable Int64), `hnh_primary_qty(qty, units_per_primary)` (Float64), `hnh_abc_class(cum_share)`, `hnh_org_type_code(organization_code)`, `hnh_oasis_po_status(doc_status, line_status)`, `hnh_stock_last_month_end()`; vars `hnh_fusion_inventory_start` ("2026-02-01"), `hnh_fusion_item_master_org_id` (300000005019401), `hnh_stock_month_end_last` ("" = current month).
- Movement types (exact strings used everywhere): `Patient sale`, `Patient return`, `Department issue`, `Transfer out`, `Transfer in`, `Goods receipt`, `Return to supplier`, `Count adjustment`, `Write-off / misc`, `Opening balance`.

- [ ] **Step 1: Write the failing macro test**

`hnh_dwh/tests/hnh/assert_hnh_supply_macros.sql` (the literals are the measured codes: Oasis document types and sources from `doc`/`docl`, Fusion type ids from `dim_inv_transaction_type`, opening-balance references from `fact_inventory_transaction`):

```sql
{% set null_s = "cast(null as Nullable(String))" %}
{% set null_i = "cast(null as Nullable(Int64))" %}
{% set null_f = "cast(null as Nullable(Float64))" %}

select 'oasis movement type wrong' as failure
where not ({{ hnh_oasis_movement_type("'INVOICEAR'", "'OASIS'", 'toUInt8(1)') }} = 'Patient sale'
       and {{ hnh_oasis_movement_type("'INVOICEAR'", "'SALES'", 'toUInt8(0)') }} = 'Patient sale'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'CRD'", 'toUInt8(0)') }} = 'Patient return'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'SALES'", 'toUInt8(1)') }} = 'Patient return'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'ENTT'", 'toUInt8(0)') }} = 'Department issue'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'ENTT'", 'toUInt8(1)') }} = 'Transfer out'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'ENTT'", 'toUInt8(1)') }} = 'Transfer in'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'GRN'", 'toUInt8(1)') }} = 'Goods receipt'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'RFN'", 'toUInt8(0)') }} = 'Return to supplier'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'CNT'", 'toUInt8(0)') }} = 'Count adjustment'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'CNT'", 'toUInt8(0)') }} = 'Count adjustment'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'BATCH'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'BATCH'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_oasis_movement_type(null_s, null_s, 'toUInt8(0)') }} = 'Write-off / misc')

union all
select 'oasis direction wrong'
where not ({{ hnh_oasis_direction("'STOCKRCPT'") }} = 1 and {{ hnh_oasis_direction("'STOCKISS'") }} = -1
       and {{ hnh_oasis_direction("'INVOICEAR'") }} = -1 and {{ hnh_oasis_direction(null_s) }} = -1)

union all
select 'opening balance wrong'
where not ({{ hnh_is_opening_balance('toInt64(42)', "'OB-JA-139'") }} = 1 and {{ hnh_is_opening_balance('toInt64(42)', "'OB'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(42)', "'Abha-651'") }} = 1 and {{ hnh_is_opening_balance('toInt64(42)', "'M-JA-407'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(42)', "'RF-40'") }} = 1 and {{ hnh_is_opening_balance('toInt64(32)', "'cp'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(32)', "'CP-2956'") }} = 1 and {{ hnh_is_opening_balance('toInt64(32)', "'ppc-588'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(32)', "'ccp-6'") }} = 1 and {{ hnh_is_opening_balance('toInt64(32)', "'pc-218'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(42)', "'INV-ADJ-166'") }} = 0 and {{ hnh_is_opening_balance('toInt64(42)', "'BAT0000000349'") }} = 0
       and {{ hnh_is_opening_balance('toInt64(32)', "'OB-JA-1'") }} = 0 and {{ hnh_is_opening_balance('toInt64(42)', "'CP-1'") }} = 0
       and {{ hnh_is_opening_balance('toInt64(42)', null_s) }} = 0 and {{ hnh_is_opening_balance(null_i, "'OB'") }} = 0)

union all
select 'fusion movement type wrong'
where not ({{ hnh_fusion_movement_type('toInt64(42)', 'toFloat64(5)', "'01'", 'toUInt8(1)') }} = 'Opening balance'
       and {{ hnh_fusion_movement_type('toInt64(300000012981827)', 'toFloat64(-1)', "'04'", 'toUInt8(0)') }} = 'Patient sale'
       and {{ hnh_fusion_movement_type('toInt64(300000012981826)', 'toFloat64(1)', "'04'", 'toUInt8(0)') }} = 'Patient return'
       and {{ hnh_fusion_movement_type('toInt64(300000012981824)', 'toFloat64(-1)', "'02'", 'toUInt8(0)') }} = 'Transfer out'
       and {{ hnh_fusion_movement_type('toInt64(300000012981825)', 'toFloat64(1)', "'04'", 'toUInt8(0)') }} = 'Transfer in'
       and {{ hnh_fusion_movement_type('toInt64(18)', 'toFloat64(10)', "'02'", 'toUInt8(0)') }} = 'Goods receipt'
       and {{ hnh_fusion_movement_type('toInt64(71)', 'toFloat64(-1)', "'02'", 'toUInt8(0)') }} = 'Goods receipt'
       and {{ hnh_fusion_movement_type('toInt64(36)', 'toFloat64(-2)', "'02'", 'toUInt8(0)') }} = 'Return to supplier'
       and {{ hnh_fusion_movement_type('toInt64(8)', 'toFloat64(-3)', "'06'", 'toUInt8(0)') }} = 'Count adjustment'
       and {{ hnh_fusion_movement_type('toInt64(21)', 'toFloat64(-4)', "'01'", 'toUInt8(0)') }} = 'Transfer out'
       and {{ hnh_fusion_movement_type('toInt64(12)', 'toFloat64(4)', "'04'", 'toUInt8(0)') }} = 'Transfer in'
       and {{ hnh_fusion_movement_type('toInt64(1)', 'toFloat64(-1)', "'01'", 'toUInt8(0)') }} = 'Department issue'
       and {{ hnh_fusion_movement_type('toInt64(32)', 'toFloat64(-1)', "'06'", 'toUInt8(0)') }} = 'Department issue'
       and {{ hnh_fusion_movement_type('toInt64(32)', 'toFloat64(-1)', "'02'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_fusion_movement_type('toInt64(42)', 'toFloat64(1)', "'02'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_fusion_movement_type('toInt64(300000009320013)', 'toFloat64(1)', "'02'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_fusion_movement_type(null_i, null_f, null_s, 'toUInt8(0)') }} = 'Write-off / misc')

union all
select 'consumption flag wrong'
where not ({{ hnh_is_consumption("'Patient sale'") }} = 1 and {{ hnh_is_consumption("'Patient return'") }} = 1
       and {{ hnh_is_consumption("'Department issue'") }} = 1 and {{ hnh_is_consumption("'Transfer out'") }} = 0
       and {{ hnh_is_consumption("'Transfer in'") }} = 0 and {{ hnh_is_consumption("'Opening balance'") }} = 0
       and {{ hnh_is_consumption("'Goods receipt'") }} = 0 and {{ hnh_is_consumption(null_s) }} = 0)

union all
select 'movement direction wrong'
where not ({{ hnh_movement_direction("'Patient sale'") }} = -1 and {{ hnh_movement_direction("'Patient return'") }} = 1
       and {{ hnh_movement_direction("'Department issue'") }} = -1 and {{ hnh_movement_direction("'Transfer out'") }} = -1
       and {{ hnh_movement_direction("'Transfer in'") }} = 1 and {{ hnh_movement_direction("'Goods receipt'") }} = 1
       and {{ hnh_movement_direction("'Return to supplier'") }} = -1 and {{ hnh_movement_direction("'Count adjustment'") }} = 0
       and {{ hnh_movement_direction("'Write-off / misc'") }} = 0 and {{ hnh_movement_direction("'Opening balance'") }} = 0)

union all
select 'oasis line reference wrong'
where not ({{ hnh_oasis_line_ref("'GN-7606861'") }} = 7606861 and {{ hnh_oasis_line_ref("'AB-9411507'") }} = 9411507
       and {{ hnh_oasis_line_ref("'GN--7460641'") }} = 7460641 and {{ hnh_oasis_line_ref("'MA-12'") }} = 12
       and {{ hnh_oasis_line_ref("'OB-JA-139'") }} is null and {{ hnh_oasis_line_ref("'cp'") }} is null
       and {{ hnh_oasis_line_ref("'10313'") }} is null and {{ hnh_oasis_line_ref("''") }} is null
       and {{ hnh_oasis_line_ref(null_s) }} is null)

union all
select 'primary quantity wrong'
where not ({{ hnh_primary_qty('toFloat64(30)', 'toFloat64(30)') }} = 1 and {{ hnh_primary_qty('toFloat64(90)', 'toFloat64(30)') }} = 3
       and {{ hnh_primary_qty('toFloat64(5)', 'toFloat64(0)') }} = 5 and {{ hnh_primary_qty('toFloat64(5)', null_f) }} = 5
       and {{ hnh_primary_qty(null_f, 'toFloat64(2)') }} = 0)

union all
select 'abc class wrong'
where not ({{ hnh_abc_class('toFloat64(0.5)') }} = 'A' and {{ hnh_abc_class('toFloat64(0.80)') }} = 'A'
       and {{ hnh_abc_class('toFloat64(0.81)') }} = 'B' and {{ hnh_abc_class('toFloat64(0.95)') }} = 'B'
       and {{ hnh_abc_class('toFloat64(0.96)') }} = 'C' and {{ hnh_abc_class(null_f) }} = 'C')

union all
select 'org type wrong'
where not ({{ hnh_org_type_code("'J04'") }} = '04' and {{ hnh_org_type_code("'MH12'") }} = '12'
       and {{ hnh_org_type_code("'RF01'") }} = '01' and {{ hnh_org_type_code("'N01'") }} = '04'
       and {{ hnh_org_type_code("'N02'") }} = '06' and {{ hnh_org_type_code("'N03'") }} = '07'
       and {{ hnh_org_type_code("'N04'") }} = '09' and {{ hnh_org_type_code("'HQ01'") }} = '10'
       and {{ hnh_org_type_code("'IT_HQ'") }} = '10' and {{ hnh_org_type_code("'MST'") }} = '00'
       and {{ hnh_org_type_code(null_s) }} = '00')

union all
select 'oasis po status wrong'
where not ({{ hnh_oasis_po_status("'R'", "'R'") }} = 'RELEASED' and {{ hnh_oasis_po_status("'C'", "'P'") }} = 'CLOSED'
       and {{ hnh_oasis_po_status("'O'", null_s) }} = 'OPEN' and {{ hnh_oasis_po_status("'R'", "'C'") }} = 'CANCELED'
       and {{ hnh_oasis_po_status(null_s, null_s) }} = 'UNKNOWN')
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_supply_macros`
Expected: compilation error — `'hnh_oasis_movement_type' is undefined`.

- [ ] **Step 3: Add the vars**

In `hnh_dwh/dbt_project.yml` under `vars:`, after `hnh_hr_snapshot_end`, add:

```yaml
  hnh_fusion_inventory_start: "2026-02-01"   # first month of Fusion inventory transactions (integration window)
  hnh_fusion_item_master_org_id: 300000005019401   # Fusion item master organisation (MST)
  hnh_stock_month_end_last: ""          # last month-end of the stock snapshot; empty = current month
```

- [ ] **Step 4: Write the macros**

`hnh_dwh/macros/hnh/hnh_rules_supply.sql`:

```sql
{# Fusion transaction types of the Oasis-to-Fusion integration: Oasis Transfer Order Issue, Oasis Transfer Order
   Receipt, Oasis Sales Return, Oasis Sales Issue (spec F1). #}
{% macro hnh_fusion_integration_type_ids() -%}
(300000012981824, 300000012981825, 300000012981826, 300000012981827)
{%- endmacro %}

{# Movement type of an Oasis stock line (spec 4.4 with the plan refinements). doc_type is the line's document type;
   source_code and has_pod (UInt8) come from the document header. #}
{% macro hnh_oasis_movement_type(doc_type, source_code, has_pod) -%}
multiIf(ifNull({{ doc_type }}, '') = 'INVOICEAR', 'Patient sale',
        ifNull({{ doc_type }}, '') = 'STOCKRCPT' and ifNull({{ source_code }}, '') in ('CRD', 'SALES'), 'Patient return',
        ifNull({{ doc_type }}, '') = 'STOCKISS' and ifNull({{ source_code }}, '') = 'ENTT' and {{ has_pod }} = 0, 'Department issue',
        ifNull({{ doc_type }}, '') = 'STOCKISS' and ifNull({{ source_code }}, '') = 'ENTT', 'Transfer out',
        ifNull({{ doc_type }}, '') = 'STOCKRCPT' and ifNull({{ source_code }}, '') = 'ENTT', 'Transfer in',
        ifNull({{ doc_type }}, '') = 'STOCKRCPT' and ifNull({{ source_code }}, '') = 'GRN', 'Goods receipt',
        ifNull({{ doc_type }}, '') = 'STOCKISS' and ifNull({{ source_code }}, '') = 'RFN', 'Return to supplier',
        ifNull({{ source_code }}, '') = 'CNT', 'Count adjustment',
        'Write-off / misc')
{%- endmacro %}

{# Store-side sign of an Oasis line: receipts add stock, issues and patient invoices remove it. Oasis quantities are
   never negative. #}
{% macro hnh_oasis_direction(doc_type) -%}
toInt8(if(ifNull({{ doc_type }}, '') = 'STOCKRCPT', 1, -1))
{%- endmacro %}

{# Opening-balance loads (Miscellaneous Receipt, type 42) and their reversals (Miscellaneous issue, type 32), by the
   reference prefixes measured on 2026-10-06: OB-, ABHA-, M-JA-, RF- loads and CP-, PPC-, CCP-, PC- reversals. #}
{% macro hnh_is_opening_balance(transaction_type_id, reference) -%}
toUInt8((ifNull({{ transaction_type_id }}, 0) = 42 and match(upper(ifNull({{ reference }}, '')), '^(OB|ABHA|M-[A-Z][A-Z]|RF)(-|$)'))
     or (ifNull({{ transaction_type_id }}, 0) = 32 and match(upper(ifNull({{ reference }}, '')), '^(CP|PPC|CCP|PC)(-|$)')))
{%- endmacro %}

{# Movement type of a Fusion transaction that has no Oasis line (spec 4.4). org_type_code is the two-digit
   inventory-organisation type ('04'-'12' are department organisations). #}
{% macro hnh_fusion_movement_type(transaction_type_id, primary_quantity, org_type_code, is_opening_balance) -%}
multiIf({{ is_opening_balance }} = 1, 'Opening balance',
        ifNull({{ transaction_type_id }}, 0) = 300000012981827, 'Patient sale',
        ifNull({{ transaction_type_id }}, 0) = 300000012981826, 'Patient return',
        ifNull({{ transaction_type_id }}, 0) = 300000012981824, 'Transfer out',
        ifNull({{ transaction_type_id }}, 0) = 300000012981825, 'Transfer in',
        ifNull({{ transaction_type_id }}, 0) in (18, 71), 'Goods receipt',
        ifNull({{ transaction_type_id }}, 0) = 36, 'Return to supplier',
        ifNull({{ transaction_type_id }}, 0) in (4, 8), 'Count adjustment',
        ifNull({{ transaction_type_id }}, 0) in (2, 3, 12, 21, 34, 53, 54, 61, 62),
            if(ifNull({{ primary_quantity }}, 0) >= 0, 'Transfer in', 'Transfer out'),
        ifNull({{ transaction_type_id }}, 0) = 1, 'Department issue',
        ifNull({{ transaction_type_id }}, 0) = 32 and ifNull({{ org_type_code }}, '') between '04' and '12', 'Department issue',
        'Write-off / misc')
{%- endmacro %}

{# Consumption = patient sales, patient returns and department issues (spec 6.3); transfers never count. #}
{% macro hnh_is_consumption(movement_type) -%}
toUInt8(ifNull({{ movement_type }}, '') in ('Patient sale', 'Patient return', 'Department issue'))
{%- endmacro %}

{# Normal direction of a movement type: 1 into the store, -1 out of it, 0 either way. #}
{% macro hnh_movement_direction(movement_type) -%}
toInt8(multiIf(ifNull({{ movement_type }}, '') in ('Patient return', 'Transfer in', 'Goods receipt'), 1,
               ifNull({{ movement_type }}, '') in ('Patient sale', 'Department issue', 'Transfer out', 'Return to supplier'), -1,
               0))
{%- endmacro %}

{# The Oasis line id in a Fusion integration reference "<prefix>-<line_id>" (one or two dashes); null otherwise.
   The prefix is not trusted: the branch comes from the posting organisation (spec F1). #}
{% macro hnh_oasis_line_ref(reference) -%}
toInt64OrNull(extract(ifNull({{ reference }}, ''), '^[A-Za-z]+-+([0-9]+)$'))
{%- endmacro %}

{# Oasis base-unit quantity in the item's primary unit: divided by the crosswalk's Oasis units per Fusion primary unit
   when that factor is greater than 0, unchanged otherwise (plan refinement of spec 4.5). #}
{% macro hnh_primary_qty(qty, units_per_primary) -%}
toFloat64(if(ifNull({{ units_per_primary }}, 0) > 0, ifNull({{ qty }}, 0) / ifNull({{ units_per_primary }}, 0), ifNull({{ qty }}, 0)))
{%- endmacro %}

{# ABC class from an item's cumulative share of consumption cost (spec 7). #}
{% macro hnh_abc_class(cum_share) -%}
multiIf(ifNull({{ cum_share }}, 1) <= 0.80, 'A', ifNull({{ cum_share }}, 1) <= 0.95, 'B', 'C')
{%- endmacro %}

{# Two-digit organisation type of a Fusion inventory organisation code (spec F3): the code's last two digits for
   <letters><nn> codes; Alrabwah's N01-N04 are Pharmacy, Ward, Clinics and Radiology; the master and Head Office
   administration organisations are 00 and 10. #}
{% macro hnh_org_type_code(organization_code) -%}
multiIf(ifNull({{ organization_code }}, '') = 'N01', '04', ifNull({{ organization_code }}, '') = 'N02', '06',
        ifNull({{ organization_code }}, '') = 'N03', '07', ifNull({{ organization_code }}, '') = 'N04', '09',
        ifNull({{ organization_code }}, '') in ('HQ01', 'IT_HQ'), '10',
        match(ifNull({{ organization_code }}, ''), '^[A-Z]+[0-9][0-9]$'), right(ifNull({{ organization_code }}, ''), 2),
        '00')
{%- endmacro %}

{# Oasis purchase-order status label from the document status. #}
{% macro hnh_oasis_po_status(doc_status, line_status) -%}
multiIf(ifNull({{ line_status }}, '') = 'C', 'CANCELED', ifNull({{ doc_status }}, '') = 'R', 'RELEASED',
        ifNull({{ doc_status }}, '') = 'C', 'CLOSED', ifNull({{ doc_status }}, '') = 'O', 'OPEN', 'UNKNOWN')
{%- endmacro %}

{# Last month-end of the monthly stock snapshot: var hnh_stock_month_end_last, empty = the current month's end. #}
{% macro hnh_stock_last_month_end() -%}
{%- set last_var = var('hnh_stock_month_end_last', '') -%}
{%- if last_var -%}toDate('{{ last_var }}'){%- else -%}toLastDayOfMonth(today()){%- endif -%}
{%- endmacro %}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_supply_macros`
Expected: `PASS=1`.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_supply.sql hnh_dwh/dbt_project.yml hnh_dwh/tests/hnh/assert_hnh_supply_macros.sql
git commit -m "Add supply-chain rule macros and vars" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Cutover, store and item-group reference data, and the stock-snapshot staging

**Files:**
- Create: `scripts/draft_store_department_map.py`, `scripts/draft_item_group_map.py`; git-ignored data `static_mappings/scm_cutover.csv`, `static_mappings/store_department_mapping.csv` (generated), `static_mappings/item_group_mapping.csv` (generated)
- Modify: `scripts/load_reference_data.py`, `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`, `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__scm_cutover.sql`, `stg_ref__store_department.sql`, `stg_ref__item_group.sql`, `stg_ref__stock_snapshot.sql`

**Interfaces:**
- Produces: `stg_ref__scm_cutover(branch_id UInt8, inventory_go_live_date Nullable(Date), first_fusion_purchasing_month Nullable(Int32))`; `stg_ref__store_department(source, branch_id UInt8, store_code, store_name, store_type, unified_department)` (Fusion `store_code` = `<organisation code>/<subinventory>` or `<organisation code>/*`; Oasis `store_code` = the `c_id` as text); `stg_ref__item_group(category_code, item_group)`; `stg_ref__stock_snapshot(branch_id UInt8, store_id Int64, product_code String, snapshot_date Date, qty_on_hand Float64, average_cost Float64)` (no rows until `default.bal_product_base` exists).
- Store types: `Warehouse`, `Pharmacy`, `Operating room`, `Ward`, `Clinic`, `Laboratory`, `Radiology`, `Administration`, `Support`, `Asset`, `Expiry/damaged/recall`, `Unmapped` (the last only for review). Item groups: `Medication`, `Medical consumable`, `Implant`, `Laboratory`, `General`, `Asset`, `Other`.

- [ ] **Step 1: Declare the sources and write the failing tests**

Append to the `reference` source `tables:` in `_reference__sources.yml`:

```yaml
      - name: map_scm_cutover
      - name: map_store_department
      - name: map_item_group
      - name: bal_product_base
```

Append to `_reference__models.yml`:

```yaml
  - name: stg_ref__scm_cutover
    columns:
      - name: branch_id
        tests: [unique, not_null]
  - name: stg_ref__store_department
    tests:
      - hnh_unique_combination:
          columns: [source, branch_id, store_code]
    columns:
      - name: source
        tests:
          - accepted_values:
              values: ['oasis', 'fusion']
      - name: store_type
        tests:
          - accepted_values:
              values: ['Warehouse', 'Pharmacy', 'Operating room', 'Ward', 'Clinic', 'Laboratory', 'Radiology',
                       'Administration', 'Support', 'Asset', 'Expiry/damaged/recall', 'Unmapped']
  - name: stg_ref__item_group
    columns:
      - name: category_code
        tests: [unique, not_null]
      - name: item_group
        tests:
          - accepted_values:
              values: ['Medication', 'Medical consumable', 'Implant', 'Laboratory', 'General', 'Asset', 'Other']
  - name: stg_ref__stock_snapshot
    columns:
      - name: snapshot_date
        tests: [not_null]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_ref__scm_cutover stg_ref__store_department stg_ref__item_group stg_ref__stock_snapshot`
Expected: FAIL — the models do not exist.

- [ ] **Step 2: Write the cutover file**

`static_mappings/scm_cutover.csv` (spec 4.2; branch 1 has no row; Head Office has a purchasing month only):

```csv
BRANCH_ID,INVENTORY_GO_LIVE_DATE,FIRST_FUSION_PURCHASING_MONTH
2,2026-09-05,202609
3,2026-07-12,202607
4,2026-08-01,202608
5,2026-09-05,202609
6,2026-05-01,202605
7,2026-04-26,202604
8,2026-05-03,202608
100,,202603
```

- [ ] **Step 3: Write and run the two draft scripts**

`scripts/draft_store_department_map.py`:

```python
"""Draft static_mappings/store_department_mapping.csv: store type and unified department of every Oasis store and Fusion
store (spec 4.2).

Fusion stores (organisation + subinventory, and '<org>/*' for the organisation level) take the organisation type
(suffix 01-03 warehouses, 04 pharmacy, 05 operating rooms, 06 wards, 07 clinics, 08 laboratory, 09 radiology,
10 administration, 11 support, 12 assets; Alrabwah N01-N04 pharmacy, ward, clinics, radiology). Oasis stores take the
type and department of the Fusion store they map to through the integration (the pair with the most transactions);
unpaired Oasis stores are typed by keywords in their name. Expiry, damaged and recall stores are recognised by code
(EXMED, EXMS, DMED, DAMS, RMED, RMS) and by the name keywords EXPIR, DAMAG, RECALL. Unified departments are drafted by
keywords; 'Not Mapped' and STORE_TYPE 'Unmapped' are left for the BI manager (open item O-P5-4).

Usage:  python scripts/draft_store_department_map.py [--out PATH]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "store_department_mapping.csv"
INTEGRATION_TYPES = "(300000012981824, 300000012981825, 300000012981826, 300000012981827)"
EXPIRY_CODES = {"EXMED", "EXMS", "DMED", "DAMS", "RMED", "RMS"}
EXPIRY_WORDS = r"EXPIR|EXIRED|DAMAG|RECALL"
ORG_TYPES = {"01": "Warehouse", "02": "Warehouse", "03": "Warehouse", "04": "Pharmacy", "05": "Operating room",
             "06": "Ward", "07": "Clinic", "08": "Laboratory", "09": "Radiology", "10": "Administration",
             "11": "Support", "12": "Asset", "00": "Warehouse"}
NAME_TYPES = [
    (EXPIRY_WORDS, "Expiry/damaged/recall"),
    (r"PHARM", "Pharmacy"),
    (r"ASSET", "Asset"),
    (r"WAREHOUSE|\bSTORES?\b|SUBSTORE", "Warehouse"),
    (r"OPERATING|THEATRE|\bOT\b|\bOR\b|CATH", "Operating room"),
    (r"\bLAB\b|LABORATORY", "Laboratory"),
    (r"RADIOLOG|X-RAY|XRAY|IMAGING|NUCLEAR|\bMRI\b|\bCT\b", "Radiology"),
    (r"WARD|ICU|NICU|PICU|CCU|EMERGENCY|A&E|\bER\b|LABOUR|DELIVERY|DIALYSIS|ENDOSCOPY|INPATIENT|SHORT STAY|RECOVERY|NURSERY", "Ward"),
    (r"KITCHEN|DIET|CAFETERIA|LAUNDRY|HOUSEKEEPING|MAINTENANCE|SECURITY|TRANSPORT|HOUSING|FACILITY|BIO MEDICAL|CSSD", "Support"),
    (r"FINANCE|PAYROLL|\bHR\b|PERSONEL|PERSONNEL|\bIT\b|PURCHAS|SUPPLY CHAIN|ACCOUNT|BILLING|RECORDS|QUALITY|\bCME\b|RECRUIT|"
     r"GOVERMENT|GOVERNMENT|BUSINESS|CALL CENTER|MARKETING|AUDIT|ADMIN|\bCEO\b|\bCMO\b|CODING|INFECTION CONTROL|RECEPTION|"
     r"PATIENT SERVICE|PATIENT ACCOUNTING|SAFTY|SAFETY", "Administration"),
    (r"CLINIC|CARDIO|DERMA|\bENT\b|DENTAL|OPTHAL|OPHTHAL|ORTHO|UROLOG|NEURO|GASTRO|\bOB\b|GYN|PEDIATRIC|PAEDIATRIC|"
     r"INTERNAL MEDICINE|SURGERY|ONCOLOG|HEMATOLOG|ENDOCR|PULMON|PHYSIO|PSYCH|RHEUMAT|NEPHRO|ALLERGY|PAIN|BARIATRIC|"
     r"VASCULAR|PLASTIC|FAMILY|HOME|DIETITIAN|\bDEPT\b", "Clinic"),
]
DEPARTMENTS = [
    (r"ICU|NICU|PICU|CCU|CRITICAL|INTENSIVE", "ICU"),
    (r"EMERGENCY|A&E|\bER\b", "EMERGENCY ROOM"),
    (r"LABOUR|DELIVERY|L&D", "DELIVERY"),
    (r"PHARM", "PHARMACY"),
    (r"CARDIOTHORAC", "CARDIOTHORACIC"),
    (r"CARDIO|CATH", "CARDIOLOGY"),
    (r"\bLAB\b|LABORATORY", "LABORATORY"),
    (r"RADIOLOG|X-RAY|XRAY|IMAGING|NUCLEAR", "RADIOLOGY"),
    (r"DERMA", "DERMATOLOGY"),
    (r"\bENT\b", "ENT"),
    (r"DENT", "DENTAL"),
    (r"OPTHAL|OPHTHAL", "OPTHALMOLOGY"),
    (r"ORTHO", "ORTHOPEDIC"),
    (r"UROLOG", "UROLOGY"),
    (r"NEUROSURG", "NEUROSURGERY"),
    (r"NEURO", "NEUROLOGY"),
    (r"GASTRO|ENDOSCOPY", "GIT"),
    (r"\bOB\b|GYN|MATERNITY", "OBSTETRICS & GYNA"),
    (r"PEDIATRIC|PAEDIATRIC|NURSERY|\bPED\b", "PAEDIATRIC"),
    (r"INTERNAL MED", "INTERNAL MEDICINE"),
    (r"GENERAL SURG", "GEN. SURGERY"),
    (r"ONCOLOG", "ONCOLOGY"),
    (r"HEMATOLOG", "HEMATOLOGY"),
    (r"ENDOCR", "ENDOCRINOLOGY"),
    (r"PULMON|RESPIRATORY", "PULMONOLGY"),
    (r"PHYSIO", "PHYSIOTHERAPY"),
    (r"PSYCH", "PSYCHIATRY"),
    (r"RHEUMAT", "RHEUMATOLOGY"),
    (r"NEPHRO|DIALYSIS", "NEPHROLOGY"),
    (r"ALLERGY", "ALLERGY & IMMUNOLOGY"),
    (r"PAIN|ANAES|ANESTH", "ANATHESIA / PAIN MANAGEMENT"),
    (r"VASCULAR", "VASCULAR SURGERY"),
    (r"PLASTIC", "PLASTIC SURGERY"),
    (r"FAMILY", "FAMILY MED"),
    (r"HOME", "HOME CARE"),
    (r"DIET", "DIETITIAN"),
    (r"INFECTIOUS", "INFECTIOUS DISEASES"),
]
TYPE_DEPARTMENTS = {"Pharmacy": "PHARMACY", "Laboratory": "LABORATORY", "Radiology": "RADIOLOGY"}

ORG_BRANCH_SQL = """
select o.organization_id as organization_id, o.organization_code as organization_code,
       ifNull(o.organization_name, '') as organization_name, ifNull(b.branch_key, 0) as branch_key
from fusion.dim_inventory_org o final
left join (select business_unit_id, primary_ledger_id from fusion.dim_business_unit final) bu on bu.business_unit_id = o.business_unit_id
left join (select branch_key, fusion_ledger_id from gold.dim_branch where fusion_ledger_id is not null) b
    on b.fusion_ledger_id = bu.primary_ledger_id
settings join_use_nulls = 1
"""
SUBINVENTORY_SQL = """
select organization_id, upper(trimBoth(secondary_inventory_name)), ifNull(trimBoth(description), '')
from fusion.dim_subinventory final where ifNull(secondary_inventory_name, '') != ''
"""
OASIS_STORE_SQL = """
select toUInt8(branch_id), toInt64(c_id),
       coalesce(nullIf(nullIf(trimBoth(ifNull(description, '')), ''), '0'), nullIf(nullIf(trimBoth(ifNull(control_context, '')), ''), '0'),
                concat('Store ', toString(toInt64(c_id))))
from oasis.control_contexts_data final
"""
PAIR_SQL = f"""
with orgs as ({ORG_BRANCH_SQL.replace('settings join_use_nulls = 1', '')}),
refs as (
    select toUInt8(ob.branch_key) as branch_key, t.organization_id as organization_id, upper(ifNull(t.subinventory_code, '*')) as subinventory,
           toInt64OrNull(extract(ifNull(t.transaction_reference, ''), '^[A-Za-z]+-+([0-9]+)$')) as line_id
    from fusion.fact_inventory_transaction t final
    inner join orgs ob on ob.organization_id = t.organization_id
    where t.transaction_type_id in {INTEGRATION_TYPES}
)
select r.branch_key, toInt64(l.c_id) as store_id, r.organization_id, r.subinventory, count() as n
from refs r
inner join (select branch_id, toInt64(line_id) as line_id, c_id from oasis.docl final
            where doc_date >= '2026-01-01' and c_id is not null) l on l.branch_id = r.branch_key and l.line_id = r.line_id
where r.line_id is not null
group by 1, 2, 3, 4
order by 1, 2, n desc, 3, 4
limit 1 by 1, 2
"""


def first(rules, text, default):
    up = text.upper()
    return next((value for pattern, value in rules if re.search(pattern, up)), default)


def org_type(code):
    code = code or ""
    special = {"N01": "04", "N02": "06", "N03": "07", "N04": "09", "HQ01": "10", "IT_HQ": "10"}
    if code in special:
        return special[code]
    return code[-2:] if re.fullmatch(r"[A-Z]+[0-9]{2}", code) else "00"


def fusion_type(org_code, sub_code, name):
    if sub_code in EXPIRY_CODES or re.search(EXPIRY_WORDS, name.upper()):
        return "Expiry/damaged/recall"
    return ORG_TYPES[org_type(org_code)]


def department(store_type, name):
    found = first(DEPARTMENTS, name, None)
    return found or TYPE_DEPARTMENTS.get(store_type, "Not Mapped")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    c = client()
    orgs = {oid: (code or "", name, int(branch)) for oid, code, name, branch in c.query(ORG_BRANCH_SQL).result_rows}
    rows, fusion_by_key = [], {}
    stores = [(oid, sub, desc) for oid, sub, desc in c.query(SUBINVENTORY_SQL).result_rows]
    # a subinventory code keeps its meaning across organisations: borrow the most common description where one is empty
    seen = {}
    for _, sub, desc in stores:
        if desc:
            seen.setdefault(sub, {}).setdefault(desc, 0)
            seen[sub][desc] += 1
    common = {sub: max(descs, key=descs.get) for sub, descs in seen.items()}
    stores = [(oid, sub, desc or common.get(sub, "")) for oid, sub, desc in stores]
    stores += [(oid, "*", name) for oid, (_, name, _) in orgs.items()]
    for oid, sub, desc in sorted(stores, key=lambda s: (orgs.get(s[0], ("", "", 0))[0], s[1])):
        code, org_name, branch = orgs.get(oid, (str(oid), "", 0))
        name = desc or (org_name if sub == "*" else sub)
        stype = fusion_type(code, sub, name)
        dept = department(stype, name if sub != "*" else org_name)
        fusion_by_key[(oid, sub)] = (stype, dept)
        rows.append(("fusion", branch, f"{code}/{sub}", name, stype, dept))
    pairs = {(int(b), int(s)): (oid, sub) for b, s, oid, sub, _ in c.query(PAIR_SQL).result_rows}
    paired = 0
    for branch, store_id, name in sorted(c.query(OASIS_STORE_SQL).result_rows):
        pair = pairs.get((int(branch), int(store_id)))
        if pair and pair in fusion_by_key and not re.search(EXPIRY_WORDS, name.upper()):
            stype, dept = fusion_by_key[pair]
            paired += 1
        else:
            stype = first(NAME_TYPES, name, "Unmapped")
            dept = department(stype, name)
        rows.append(("oasis", int(branch), str(store_id), name, stype, dept))
    with open(args.out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SOURCE", "BRANCH_ID", "STORE_CODE", "STORE_NAME", "STORE_TYPE", "UNIFIED_DEPARTMENT"])
        w.writerows(rows)
    n_oasis = sum(1 for r in rows if r[0] == "oasis")
    unmapped = sum(1 for r in rows if r[4] == "Unmapped")
    expiry = sum(1 for r in rows if r[4] == "Expiry/damaged/recall")
    print(f"{len(rows)} stores ({len(rows) - n_oasis} Fusion, {n_oasis} Oasis, {paired} Oasis paired through the integration), "
          f"{expiry} expiry/damaged/recall, {unmapped} unmapped -> {args.out}")


if __name__ == "__main__":
    main()
```

`scripts/draft_item_group_map.py`:

```python
"""Draft static_mappings/item_group_mapping.csv: Fusion "HNH Catalog" category codes to item groups (spec 4.2).

Keyword rules on the category code, first match wins; codes that match no rule are written as 'Other' for the BI
manager to review (open item O-P5-4).

Usage:  python scripts/draft_item_group_map.py [--out PATH]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "item_group_mapping.csv"
MASTER_ORG = 300000005019401

RULES = [
    (r"IMPLANT|STENT", "Implant"),
    (r"^LAB_|^XXLAB_", "Laboratory"),
    (r"^IT_|EQUIPMENT|PP&E|FURNITURE|COMPUTERS|LAPTOPS|SERVERS?\b|SERVER_RACKS|PRINTERS|SCANNERS|ROUTERS|SWITCHES|"
     r"FIREWALLS|^MONITORS$|SOFTWARE|SYSTEMS$|INFRASTRUCTURE|ASSETS|AMBULANCES|CABINET|CHAIRS|DESKS|TABLES?$|LOCKERS|"
     r"STORAGE|SIGNBOARDS|COUNTERS|RECEIVERS|^TABLETS$", "Asset"),
    (r"_ORAL$|_PARENTERAL$|_TOPICAL$|_OPHTHALMIC$|_OTIC$|_NASAL$|_RECTAL$|_VAGINAL$|_INHALATION$|_INFUSION$|"
     r"NOT_ATC_DEVICE|^DRUG_FORMULARY|^PHARMACEUTICAL$|^FORMULA_|^VITAMINS|^TPN_", "Medication"),
    (r"CLEANING|HOUSEKEEPING|STATIONERY|STAIONARY|PRINTING|PAPER|FORMS|CATERING|LINENS|UNIFORMS|MAINTENACE|WASTE|"
     r"^GENERAL_CONSUMABLES$", "General"),
    (r"^OTHER$", "Other"),
    (r".", "Medical consumable"),
]


def group_of(code):
    up = code.upper()
    return next(group for pattern, group in RULES if re.search(pattern, up))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    rows = client().query(
        "select distinct trimBoth(category_code) from fusion.dim_item_category final "
        f"where organization_id = {MASTER_ORG} and category_set_name = 'HNH Catalog' and ifNull(category_code, '') != '' "
        "order by 1"
    ).result_rows
    out = [(code, group_of(code)) for (code,) in rows]
    with open(args.out, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["CATEGORY_CODE", "ITEM_GROUP"])
        w.writerows(out)
    counts = {}
    for _, g in out:
        counts[g] = counts.get(g, 0) + 1
    print(f"{len(out)} category codes -> {args.out}: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))


if __name__ == "__main__":
    main()
```

Run: `python scripts/draft_store_department_map.py`
Expected (measured): `2617 stores (1032 Fusion, 1585 Oasis, 316 Oasis paired through the integration), 92 expiry/damaged/recall, 228 unmapped -> ...store_department_mapping.csv`. Open the CSV and confirm: `fusion,3,J06/WER,ER SUBSTORE,Ward,EMERGENCY ROOM`, `fusion,3,J05/CATC,CATH LAB,Operating room,CARDIOLOGY`, `oasis,3,44,INPATIENT PHARMACY,Pharmacy,PHARMACY`, `oasis,3,249,EXPIRED MEDICATION STORE,Expiry/damaged/recall,Not Mapped`.

Run: `python scripts/draft_item_group_map.py`
Expected (measured): `283 category codes -> ...item_group_mapping.csv: Asset 59, General 14, Implant 8, Laboratory 7, Medical consumable 81, Medication 113, Other 1`. Confirm `Drug_Formulary_SFDA,Medication`, `ORTHOPEDIC_IMPLANTS,Implant`, `LAB_REAGENTS_CHEMISTRY,Laboratory`, `Laboratory_Equipment,Asset`, `GENERAL_STATIONERY,General`, `SURGICAL_SUTURES,Medical consumable`, `OTHER,Other`.

- [ ] **Step 4: Add the loader entries and load**

In `scripts/load_reference_data.py` add, after `def dt_null(v):`:

```python
def d_null(v):
    return None if v in NULLS else datetime.strptime(v.strip()[:10], "%Y-%m-%d").date()
```

and add to `SMALL_TABLES`:

```python
    # Per-branch Fusion inventory go-live date and first Fusion purchasing month (yyyymm); empty = not live (spec 4.2).
    "map_scm_cutover": (
        "scm_cutover.csv",
        [("BRANCH_ID", "UInt8", i), ("INVENTORY_GO_LIVE_DATE", "Nullable(Date)", d_null),
         ("FIRST_FUSION_PURCHASING_MONTH", "Nullable(UInt32)", i_null)],
        "BRANCH_ID",
    ),
    # Store type and unified department per Oasis store and Fusion store; drafted by scripts/draft_store_department_map.py,
    # reviewed by the BI manager (open item O-P5-4).
    "map_store_department": (
        "store_department_mapping.csv",
        [("SOURCE", "LowCardinality(String)", s), ("BRANCH_ID", "UInt8", i), ("STORE_CODE", "String", s),
         ("STORE_NAME", "String", s), ("STORE_TYPE", "LowCardinality(String)", s), ("UNIFIED_DEPARTMENT", "String", s)],
        "(SOURCE, BRANCH_ID, STORE_CODE)",
    ),
    # Item group per Fusion "HNH Catalog" category code; drafted by scripts/draft_item_group_map.py (O-P5-4).
    "map_item_group": (
        "item_group_mapping.csv",
        [("CATEGORY_CODE", "String", s), ("ITEM_GROUP", "LowCardinality(String)", s)],
        "CATEGORY_CODE",
    ),
```

`bal_product_base` is **not** a loader entry: the user loads it (O-P5-5).

Run: `python scripts/load_reference_data.py --only map_scm_cutover map_store_department map_item_group`
Expected: `default.map_scm_cutover: loaded 8`, `default.map_store_department: loaded 2,617`, `default.map_item_group: loaded 283`.

- [ ] **Step 5: Write the staging views**

`stg_ref__scm_cutover.sql`:

```sql
-- Per-branch Fusion go-live for inventory (date) and purchasing (first month, yyyymm); null = not live (spec 4.2).
select
    toUInt8(BRANCH_ID)                      as branch_id,
    INVENTORY_GO_LIVE_DATE                  as inventory_go_live_date,
    if(FIRST_FUSION_PURCHASING_MONTH is null, cast(null as Nullable(Int32)), toInt32(FIRST_FUSION_PURCHASING_MONTH)) as first_fusion_purchasing_month
from {{ source('reference', 'map_scm_cutover') }}
```

`stg_ref__store_department.sql`:

```sql
select
    lower(trimBoth(SOURCE))                 as source,
    toUInt8(BRANCH_ID)                      as branch_id,
    trimBoth(STORE_CODE)                    as store_code,
    trimBoth(STORE_NAME)                    as store_name,
    trimBoth(STORE_TYPE)                    as store_type,
    trimBoth(UNIFIED_DEPARTMENT)            as unified_department
from {{ source('reference', 'map_store_department') }}
```

`stg_ref__item_group.sql`:

```sql
select
    trimBoth(CATEGORY_CODE)                 as category_code,
    trimBoth(ITEM_GROUP)                    as item_group
from {{ source('reference', 'map_item_group') }}
```

`stg_ref__stock_snapshot.sql` — empty-safe: `adapter.get_relation` looks the table up at run time (dbt-clickhouse ignores the database part); while `default.bal_product_base` is missing the view is a typed empty select. **To adapt to other column names, change only the right-hand names in `cols`.** A view built while the table was missing stays empty until the next `dbt build` after the load.

```sql
{#- Old-warehouse daily stock snapshots (spec S5, open item O-P5-5), loaded by the user into default.bal_product_base.
    Until that table exists this view returns no rows. The source column names are set once in `cols`: if the loaded
    table names a column differently, change only the right-hand name here. -#}
{%- set cols = {
    'branch_id': 'BRANCH_ID',
    'store_id': 'C_ID',
    'product_code': 'PRODUCT_CODE',
    'snapshot_at': 'Snapshot_timestamp',
    'qty_on_hand': 'QTY_ON_HAND',
    'average_cost': 'AVERAGE_COST'
} -%}
{%- set src = source('reference', 'bal_product_base') -%}
{%- set rel = adapter.get_relation(database=src.database, schema=src.schema, identifier=src.identifier) if execute else none -%}
{%- if rel is not none %}
select
    toUInt8({{ cols['branch_id'] }})                   as branch_id,
    toInt64({{ cols['store_id'] }})                    as store_id,
    trimBoth(toString({{ cols['product_code'] }}))     as product_code,
    toDate({{ cols['snapshot_at'] }})                  as snapshot_date,
    toFloat64(ifNull({{ cols['qty_on_hand'] }}, 0))    as qty_on_hand,
    toFloat64(ifNull({{ cols['average_cost'] }}, 0))   as average_cost
from {{ src }}
where {{ cols['snapshot_at'] }} is not null
{%- else %}
-- {{ src }} does not exist yet: no rows, with the model's columns and types.
select toUInt8(0) as branch_id, toInt64(0) as store_id, '' as product_code, toDate('1970-01-01') as snapshot_date,
       toFloat64(0) as qty_on_hand, toFloat64(0) as average_cost
where 0
{%- endif %}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_ref__scm_cutover stg_ref__store_department stg_ref__item_group stg_ref__stock_snapshot`
Expected: all PASS. Check the absent path: `select count() from stg.stg_ref__stock_snapshot` returns 0 and `show create table stg.stg_ref__stock_snapshot` contains `WHERE 0` (verified during planning: the model compiles and returns 0 rows while the table is absent). If `default.bal_product_base` already exists when you run this, record its row count instead and skip the `WHERE 0` check.

- [ ] **Step 7: Commit**

```bash
git add scripts/load_reference_data.py scripts/draft_store_department_map.py scripts/draft_item_group_map.py hnh_dwh/models/hnh/staging/reference/
git commit -m "Load the supply-chain cutover, store and item-group maps and stage the stock snapshots" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Fusion SCM staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/fusion/_fusion__sources.yml`, `_fusion__models.yml`
- Create (in `staging/fusion/`): `stg_fusion__inventory_orgs.sql`, `stg_fusion__subinventories.sql`, `stg_fusion__items.sql`, `stg_fusion__item_categories.sql`, `stg_fusion__inventory_transactions.sql`, `stg_fusion__inventory_transaction_lots.sql`, `stg_fusion__inventory_valuation.sql`, `stg_fusion__inventory_onhand.sql`, `stg_fusion__inv_transaction_types.sql`, `stg_fusion__lots.sql`, `stg_fusion__cost_distributions.sql`, `stg_fusion__po_distributions.sql`, `stg_fusion__po_schedules.sql`, `stg_fusion__po_line_types.sql`, `stg_fusion__receipt_transactions.sql`, `stg_fusion__requisition_distributions.sql`

**Interfaces:**
- Consumes: `hnh_fusion_source`, `hnh_str`, `hnh_code`.
- Produces (quantities Float64; dates `Date` unless noted):
  - `stg_fusion__inventory_orgs(organization_id, organization_code, organization_name, business_unit_id)`
  - `stg_fusion__subinventories(organization_id, subinventory_code String, subinventory_description, is_disabled)`
  - `stg_fusion__items(inventory_item_id, organization_id, item_number, item_description, primary_uom_code, item_type, item_status, is_lot_controlled)`
  - `stg_fusion__item_categories(inventory_item_id, organization_id, category_set_name, category_code, category_description)`
  - `stg_fusion__inventory_transactions(transaction_id, organization_id, subinventory_code, transfer_organization_id, transfer_subinventory, inventory_item_id, transaction_type_id, transaction_reference, rcv_transaction_id, transaction_date Date, primary_quantity, transaction_quantity, transaction_uom)`
  - `stg_fusion__inventory_transaction_lots(transaction_id, lot_number String, inventory_item_id, organization_id, primary_quantity)`
  - `stg_fusion__inventory_valuation(layer_cost_id, inventory_org_id, inventory_item_id, base_txn_type_id, cost_transaction_type, posted_flag, cost_date Date, quantity, unit_cost)`
  - `stg_fusion__inventory_onhand(onhand_quantities_id, snapshot_date, inventory_item_id, organization_id, subinventory_code, lot_number, primary_quantity)`
  - `stg_fusion__inv_transaction_types(transaction_type_id, transaction_type_name, transaction_action_id, transaction_source_type_name)`
  - `stg_fusion__lots(inventory_item_id, organization_id, lot_number String, expiration_date Nullable(Date32))`
  - `stg_fusion__cost_distributions(distribution_line_id, ledger_id, cost_organization_id, inventory_item_id, accounting_line_type, accounted_flag, gl_date, ledger_amount)`
  - `stg_fusion__po_distributions(po_distribution_id, line_location_id, req_distribution_id, destination_organization_id, quantity_ordered, quantity_delivered, quantity_billed, quantity_cancelled)`
  - `stg_fusion__po_schedules(line_location_id, po_header_id, po_line_id, po_number, line_num, shipment_num, vendor_id, vendor_site_id, ship_to_organization_id, item_id, uom_code, document_status, line_type_id, schedule_status, is_cancelled, po_creation_date, need_by_date, quantity, quantity_received, quantity_billed, quantity_cancelled, unit_price, amount, amount_received)`
  - `stg_fusion__po_line_types(line_type_id, line_type_name)`
  - `stg_fusion__receipt_transactions(transaction_id, parent_transaction_id, transaction_type, destination_type_code, po_line_location_id, po_distribution_id, organization_id, subinventory_code, vendor_id, vendor_site_id, item_id, vendor_lot_number, transaction_date, quantity, primary_quantity, po_unit_price, amount)`
  - `stg_fusion__requisition_distributions(distribution_id, requisition_header_id, requisition_number, approved_date Nullable(Date32))`

- [ ] **Step 1: Declare sources and write the failing tests**

Append to the `fusion` source `tables:` in `_fusion__sources.yml`:

```yaml
      - name: dim_inventory_org
      - name: dim_subinventory
      - name: dim_item
      - name: dim_item_category
      - name: dim_inv_transaction_type
      - name: dim_lot
      - name: fact_inventory_transaction
      - name: fact_inventory_transaction_lot
      - name: fact_inventory_valuation
      - name: fact_inventory_onhand
      - name: fact_cost_distribution
      - name: fact_po_distribution
      - name: fact_po_schedule
      - name: dim_po_line_type
      - name: fact_receipt_transaction
      - name: fact_requisition_distribution
```

Append to `_fusion__models.yml`:

```yaml
  - name: stg_fusion__inventory_orgs
    columns:
      - name: organization_id
        tests: [unique, not_null]
  - name: stg_fusion__subinventories
    tests:
      - hnh_unique_combination:
          columns: [organization_id, subinventory_code]
  - name: stg_fusion__items
    tests:
      - hnh_unique_combination:
          columns: [inventory_item_id, organization_id]
  - name: stg_fusion__item_categories
    tests:
      - hnh_unique_combination:
          columns: [inventory_item_id, organization_id]
  - name: stg_fusion__inventory_transactions
    columns:
      - name: transaction_id
        tests: [unique, not_null]
  - name: stg_fusion__inventory_transaction_lots
    tests:
      - hnh_unique_combination:
          columns: [transaction_id, lot_number]
  - name: stg_fusion__inventory_valuation
    columns:
      - name: layer_cost_id
        tests: [unique, not_null]
  - name: stg_fusion__inventory_onhand
    tests:
      - hnh_unique_combination:
          columns: [snapshot_date, onhand_quantities_id]
  - name: stg_fusion__inv_transaction_types
    columns:
      - name: transaction_type_id
        tests: [unique, not_null]
  - name: stg_fusion__lots
    tests:
      - hnh_unique_combination:
          columns: [inventory_item_id, organization_id, lot_number]
  - name: stg_fusion__cost_distributions
    columns:
      - name: distribution_line_id
        tests: [unique, not_null]
  - name: stg_fusion__po_distributions
    columns:
      - name: po_distribution_id
        tests: [unique, not_null]
  - name: stg_fusion__po_schedules
    columns:
      - name: line_location_id
        tests: [unique, not_null]
  - name: stg_fusion__po_line_types
    columns:
      - name: line_type_id
        tests: [unique, not_null]
  - name: stg_fusion__receipt_transactions
    columns:
      - name: transaction_id
        tests: [unique, not_null]
  - name: stg_fusion__requisition_distributions
    columns:
      - name: distribution_id
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_fusion__inventory_orgs stg_fusion__subinventories stg_fusion__items stg_fusion__item_categories stg_fusion__inventory_transactions stg_fusion__inventory_transaction_lots stg_fusion__inventory_valuation stg_fusion__inventory_onhand stg_fusion__inv_transaction_types stg_fusion__lots stg_fusion__cost_distributions stg_fusion__po_distributions stg_fusion__po_schedules stg_fusion__po_line_types stg_fusion__receipt_transactions stg_fusion__requisition_distributions`
Expected: FAIL — the models do not exist.

- [ ] **Step 2: Write the views**

`stg_fusion__inventory_orgs.sql`:

```sql
select
    organization_id,
    {{ hnh_code('organization_code') }}     as organization_code,
    {{ hnh_str('organization_name') }}      as organization_name,
    business_unit_id
from {{ hnh_fusion_source('dim_inventory_org') }} final
```

`stg_fusion__subinventories.sql`:

```sql
select
    organization_id,
    assumeNotNull({{ hnh_code('secondary_inventory_name') }}) as subinventory_code,
    {{ hnh_str('description') }}            as subinventory_description,
    toUInt8(disable_date is not null and disable_date <= now()) as is_disabled
from {{ hnh_fusion_source('dim_subinventory') }} final
where {{ hnh_code('secondary_inventory_name') }} is not null
```

`stg_fusion__items.sql`:

```sql
select
    inventory_item_id,
    organization_id,
    {{ hnh_str('item_number') }}            as item_number,
    {{ hnh_str('item_description') }}       as item_description,
    {{ hnh_code('primary_uom_code') }}      as primary_uom_code,
    {{ hnh_code('item_type') }}             as item_type,
    {{ hnh_str('item_status_code') }}       as item_status,
    toUInt8(ifNull(lot_control_code, 1) = 2) as is_lot_controlled
from {{ hnh_fusion_source('dim_item') }} final
```

`stg_fusion__item_categories.sql`:

```sql
select
    inventory_item_id,
    organization_id,
    {{ hnh_str('category_set_name') }}      as category_set_name,
    {{ hnh_str('category_code') }}          as category_code,
    {{ hnh_str('category_description') }}   as category_description
from {{ hnh_fusion_source('dim_item_category') }} final
```

`stg_fusion__inventory_transactions.sql`:

```sql
select
    transaction_id,
    organization_id,
    {{ hnh_code('subinventory_code') }}     as subinventory_code,
    transfer_organization_id,
    {{ hnh_code('transfer_subinventory') }} as transfer_subinventory,
    inventory_item_id,
    transaction_type_id,
    {{ hnh_str('transaction_reference') }}  as transaction_reference,
    rcv_transaction_id,
    assumeNotNull(toDate(transaction_date)) as transaction_date,
    toFloat64(ifNull(primary_quantity, 0))  as primary_quantity,
    toFloat64(ifNull(transaction_quantity, 0)) as transaction_quantity,
    {{ hnh_code('transaction_uom') }}       as transaction_uom
from {{ hnh_fusion_source('fact_inventory_transaction') }} final
where transaction_date is not null
```

`stg_fusion__inventory_transaction_lots.sql`:

```sql
select
    transaction_id,
    assumeNotNull({{ hnh_str('lot_number') }}) as lot_number,
    inventory_item_id,
    organization_id,
    toFloat64(ifNull(primary_quantity, 0))  as primary_quantity
from {{ hnh_fusion_source('fact_inventory_transaction_lot') }} final
where {{ hnh_str('lot_number') }} is not null
```

`stg_fusion__inventory_valuation.sql`:

```sql
-- Cost layers (spec F6). unit_cost is text in the source; quantity is signed (issues negative).
select
    layer_cost_id,
    inventory_org_id,
    inventory_item_id,
    base_txn_type_id,
    {{ hnh_code('cost_transaction_type') }} as cost_transaction_type,
    {{ hnh_code('posted_flag') }}           as posted_flag,
    assumeNotNull(toDate(cost_date))        as cost_date,
    toFloat64(ifNull(quantity, 0))          as quantity,
    ifNull(toFloat64OrNull(trimBoth(ifNull(unit_cost, ''))), 0) as unit_cost
from {{ hnh_fusion_source('fact_inventory_valuation') }} final
where cost_date is not null
```

`stg_fusion__inventory_onhand.sql`:

```sql
select
    onhand_quantities_id,
    toDate(snapshot_date)                   as snapshot_date,
    inventory_item_id,
    organization_id,
    {{ hnh_code('subinventory_code') }}     as subinventory_code,
    {{ hnh_str('lot_number') }}             as lot_number,
    toFloat64(ifNull(primary_transaction_quantity, 0)) as primary_quantity
from {{ hnh_fusion_source('fact_inventory_onhand') }} final
```

`stg_fusion__inv_transaction_types.sql`:

```sql
select
    transaction_type_id,
    {{ hnh_str('transaction_type_name') }}  as transaction_type_name,
    transaction_action_id,
    {{ hnh_str('transaction_source_type_name') }} as transaction_source_type_name
from {{ hnh_fusion_source('dim_inv_transaction_type') }} final
```

`stg_fusion__lots.sql`:

```sql
-- Lot expiry dates run from 1930 to 2299 (spec F14), so they are Date32.
select
    inventory_item_id,
    organization_id,
    assumeNotNull({{ hnh_str('lot_number') }}) as lot_number,
    toDate32(expiration_date)               as expiration_date
from {{ hnh_fusion_source('dim_lot') }} final
where {{ hnh_str('lot_number') }} is not null
```

`stg_fusion__cost_distributions.sql`:

```sql
select
    distribution_line_id,
    ledger_id,
    cost_organization_id,
    inventory_item_id,
    {{ hnh_code('accounting_line_type') }}  as accounting_line_type,
    {{ hnh_code('accounted_flag') }}        as accounted_flag,
    toDate(gl_date)                         as gl_date,
    toFloat64(ifNull(ledger_amount, 0))     as ledger_amount
from {{ hnh_fusion_source('fact_cost_distribution') }} final
```

`stg_fusion__po_distributions.sql`:

```sql
select
    po_distribution_id,
    line_location_id,
    req_distribution_id,
    destination_organization_id,
    toFloat64(ifNull(quantity_ordered, 0))  as quantity_ordered,
    toFloat64(ifNull(quantity_delivered, 0)) as quantity_delivered,
    toFloat64(ifNull(quantity_billed, 0))   as quantity_billed,
    toFloat64(ifNull(quantity_cancelled, 0)) as quantity_cancelled
from {{ hnh_fusion_source('fact_po_distribution') }} final
```

`stg_fusion__po_schedules.sql`:

```sql
-- One row per PO shipment (line location). unit_price is the schedule's price override, else the line price.
select
    line_location_id,
    po_header_id,
    po_line_id,
    {{ hnh_str('po_number') }}              as po_number,
    line_num,
    shipment_num,
    vendor_id,
    vendor_site_id,
    ship_to_organization_id,
    item_id,
    {{ hnh_code('uom_code') }}              as uom_code,
    {{ hnh_code('document_status') }}       as document_status,
    line_type_id,
    {{ hnh_code('schedule_status') }}       as schedule_status,
    toUInt8(ifNull(schedule_cancel_flag, 'N') = 'Y' or ifNull(line_cancel_flag, 'N') = 'Y' or ifNull(po_cancel_flag, 'N') = 'Y') as is_cancelled,
    toDate(po_creation_date)                as po_creation_date,
    toDate(need_by_date)                    as need_by_date,
    toFloat64(ifNull(quantity, 0))          as quantity,
    toFloat64(ifNull(quantity_received, 0)) as quantity_received,
    toFloat64(ifNull(quantity_billed, 0))   as quantity_billed,
    toFloat64(ifNull(quantity_cancelled, 0)) as quantity_cancelled,
    toFloat64(ifNull(coalesce(price_override, unit_price), 0)) as unit_price,
    toFloat64(ifNull(amount, 0))            as amount,
    toFloat64(ifNull(amount_received, 0))   as amount_received
from {{ hnh_fusion_source('fact_po_schedule') }} final
```

`stg_fusion__po_line_types.sql`:

```sql
select line_type_id, {{ hnh_str('line_type_name') }} as line_type_name
from {{ hnh_fusion_source('dim_po_line_type') }} final
```

`stg_fusion__receipt_transactions.sql`:

```sql
select
    transaction_id,
    parent_transaction_id,
    {{ hnh_code('transaction_type') }}      as transaction_type,
    {{ hnh_code('destination_type_code') }} as destination_type_code,
    po_line_location_id,
    po_distribution_id,
    organization_id,
    {{ hnh_code('subinventory') }}          as subinventory_code,
    vendor_id,
    vendor_site_id,
    item_id,
    {{ hnh_str('vendor_lot_num') }}         as vendor_lot_number,
    toDate(transaction_date)                as transaction_date,
    toFloat64(ifNull(quantity, 0))          as quantity,
    ifNull(toFloat64(primary_quantity), toFloat64(ifNull(quantity, 0))) as primary_quantity,
    toFloat64(ifNull(po_unit_price, 0))     as po_unit_price,
    toFloat64(ifNull(amount, 0))            as amount
from {{ hnh_fusion_source('fact_receipt_transaction') }} final
```

`stg_fusion__requisition_distributions.sql`:

```sql
select
    distribution_id,
    requisition_header_id,
    {{ hnh_str('requisition_number') }}     as requisition_number,
    toDate32(approved_date)                 as approved_date
from {{ hnh_fusion_source('fact_requisition_distribution') }} final
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_fusion__inventory_orgs stg_fusion__subinventories stg_fusion__items stg_fusion__item_categories stg_fusion__inventory_transactions stg_fusion__inventory_transaction_lots stg_fusion__inventory_valuation stg_fusion__inventory_onhand stg_fusion__inv_transaction_types stg_fusion__lots stg_fusion__cost_distributions stg_fusion__po_distributions stg_fusion__po_schedules stg_fusion__po_line_types stg_fusion__receipt_transactions stg_fusion__requisition_distributions`
Expected: all PASS. Record the row counts; measured (final): inventory_orgs 106, subinventories 926, items 1,871,380, item_categories 1,871,266, inventory_transactions 1,034,150, inventory_transaction_lots 1,018,224, inventory_valuation 1,084,480, inventory_onhand 147,706, inv_transaction_types 90, lots 73,804, cost_distributions 2,098,822, po_distributions 35,546, po_schedules 35,566, po_line_types 4, receipt_transactions 28,116, requisition_distributions 28,386. If a uniqueness test fails, report the duplicated keys; do not add `limit 1 by`.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/staging/fusion/
git commit -m "Stage Fusion inventory, valuation and procurement tables" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Oasis stock staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`, `_oasis__models.yml`, `stg_oasis__delivery_lines.sql` (adds `product_code`)
- Create (in `staging/oasis/`): `stg_oasis__stock_documents.sql`, `stg_oasis__stock_document_lines.sql`, `stg_oasis__stock_batch_snapshots.sql`, `stg_oasis__stores.sql`, `stg_oasis__products.sql`, `stg_oasis__store_requisitions.sql`

**Interfaces:**
- Consumes: `hnh_oasis_source`, `hnh_id`, `hnh_str`, `hnh_code`.
- Produces:
  - `stg_oasis__stock_documents(branch_id UInt8, doc_id Int64, doc_type, doc_ind, source_code, doc_no, doc_status, gl_stk, order_type, store_id Nullable(Int64), pod Nullable(Int64), account_code, doc_date Nullable(Date32))` — types INVOICEAR, STOCKISS, STOCKRCPT, PORDER
  - `stg_oasis__stock_document_lines(branch_id UInt8, line_id Int64, doc_id Int64, doc_type, doc_no, line_date Nullable(Date32), store_id Nullable(Int64), product_code Nullable(String), quantity, qty_ordered, conv_factor, unit_cost, total_cost, list_unit_price, list_discount_pct, discount_pct, vat_value, bonus_quantity, line_status, cross_ref_line_id Nullable(Int64), lot_number, batch_number, expiry_date Nullable(Date32), uom_code)` — types INVOICEAR, CREDITAR, STOCKISS, STOCKRCPT, PORDER; `quantity` in base units
  - `stg_oasis__stock_batch_snapshots(branch_id UInt8, snapshot_date Date32, store_id Int64, product_code String, batch_number, expiry_date Nullable(Date32), quantity Float64)`
  - `stg_oasis__stores(branch_id UInt8, store_id Int64, store_name String)`
  - `stg_oasis__products(branch_id UInt8, product_code String, store_id Int64, product_description, product_category_code, qty_on_hand, average_cost, stocked_uom_code, item_type_code)`
  - `stg_oasis__store_requisitions(branch_id UInt8, bintran_id Int64, doc_no, requisition_type, status, store_id, to_store_id, product_code, quantity, quantity_received, transaction_date Nullable(Date32))`
  - `stg_oasis__delivery_lines(... + product_code Nullable(String))`

- [ ] **Step 1: Declare sources and write the failing tests**

Append to the `oasis` source `tables:` in `_oasis__sources.yml` (`doc`, `control_contexts_data` and `delivery_lines` are already declared):

```yaml
      - name: docl
      - name: docl_by_serial
        freshness: null
      - name: product_base
        freshness: null
      - name: bintran
        freshness: null
```

Append to `_oasis__models.yml`:

```yaml
  - name: stg_oasis__stock_documents
    tests:
      - hnh_unique_combination:
          columns: [branch_id, doc_id]
  - name: stg_oasis__stock_document_lines
    tests:
      - hnh_unique_combination:
          columns: [branch_id, line_id]
  - name: stg_oasis__stock_batch_snapshots
    columns:
      - name: snapshot_date
        tests: [not_null]
  - name: stg_oasis__stores
    tests:
      - hnh_unique_combination:
          columns: [branch_id, store_id]
  - name: stg_oasis__products
    tests:
      - hnh_unique_combination:
          columns: [branch_id, product_code, store_id]
  - name: stg_oasis__store_requisitions
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bintran_id]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_oasis__stock_documents stg_oasis__stock_document_lines stg_oasis__stock_batch_snapshots stg_oasis__stores stg_oasis__products stg_oasis__store_requisitions stg_oasis__delivery_lines`
Expected: FAIL — the new models do not exist.

- [ ] **Step 2: Write the views**

`stg_oasis__stock_documents.sql`:

```sql
-- Oasis document headers of the stock, purchasing and patient-invoice types (spec F8). pod is the counterparty store of a
-- transfer (and the ordering store on a GRN); 0 becomes null.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(doc_id)                         as doc_id,
    {{ hnh_code('doc_type') }}              as doc_type,
    {{ hnh_code('doc_ind') }}               as doc_ind,
    {{ hnh_code('source_code') }}           as source_code,
    {{ hnh_str('doc_no') }}                 as doc_no,
    {{ hnh_code('doc_status') }}            as doc_status,
    {{ hnh_code('gl_stk') }}                as gl_stk,
    {{ hnh_code('order_type') }}            as order_type,
    {{ hnh_id('c_id') }}                    as store_id,
    {{ hnh_id('pod') }}                     as pod,
    {{ hnh_code('account_code') }}          as account_code,
    toDate32(doc_date)                      as doc_date
from {{ hnh_oasis_source('doc') }} final
where doc_type in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT', 'PORDER')
```

`stg_oasis__stock_document_lines.sql`:

```sql
-- Oasis document lines of the stock, purchasing and patient-invoice types, and credit notes so that Fusion references
-- to them resolve (spec F8). quantity is in the product's base unit: qty_change, or qty_shipped on invoice lines that
-- carry no qty_change; unit_cost and list_unit_price are per base unit.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(line_id)                        as line_id,
    toInt64(ifNull(doc_id, 0))              as doc_id,
    {{ hnh_code('doc_type') }}              as doc_type,
    {{ hnh_str('doc_no') }}                 as doc_no,
    toDate32(doc_date)                      as line_date,
    {{ hnh_id('c_id') }}                    as store_id,
    {{ hnh_str('product_code') }}           as product_code,
    toFloat64(if(ifNull(qty_change, 0) != 0, ifNull(qty_change, 0), ifNull(qty_shipped, 0))) as quantity,
    toFloat64(ifNull(qty_ordered, 0))       as qty_ordered,
    toFloat64(ifNull(conv_factor, 0))       as conv_factor,
    toFloat64(ifNull(unit_cost, 0))         as unit_cost,
    toFloat64(ifNull(total_cost, 0))        as total_cost,
    toFloat64(ifNull(exp_fob_cost, 0))      as list_unit_price,
    toFloat64(ifNull(list_discount, 0))     as list_discount_pct,
    toFloat64(ifNull(disc_1, 0))            as discount_pct,
    toFloat64(ifNull(vat_value, 0))         as vat_value,
    toFloat64(ifNull(bonus_order, 0))       as bonus_quantity,
    {{ hnh_code('line_status') }}           as line_status,
    {{ hnh_id('cross_ref_line_id') }}       as cross_ref_line_id,
    {{ hnh_str('lot_no') }}                 as lot_number,
    {{ hnh_str('serial_no_1') }}            as batch_number,
    toDate32(adj_date)                      as expiry_date,
    {{ hnh_code('uom_code') }}              as uom_code
from {{ hnh_oasis_source('docl') }} final
where doc_type in ('INVOICEAR', 'CREDITAR', 'STOCKISS', 'STOCKRCPT', 'PORDER')
```

`stg_oasis__stock_batch_snapshots.sql`:

```sql
-- Daily stock by batch from 2026-08-20 (spec F10). A date loaded twice keeps its latest version. quantity is
-- qty_outstanding, the batch's on-hand quantity in base units (cnt is a row count, not a quantity).
with latest as (
    select branch_id, version_date, max(version) as latest_version
    from {{ hnh_oasis_source('docl_by_serial') }} final
    where version_date is not null and version is not null
    group by branch_id, version_date
)

select
    toUInt8(s.branch_id)                    as branch_id,
    assumeNotNull(s.version_date)           as snapshot_date,
    toInt64(s.c_id)                         as store_id,
    trimBoth(s.product_code)                as product_code,
    {{ hnh_str('s.serial_no_1') }}          as batch_number,
    toDate32(s.adj_date)                    as expiry_date,
    toFloat64(s.qty_outstanding)            as quantity
from {{ hnh_oasis_source('docl_by_serial') }} as s final
inner join latest as l
    on l.branch_id = s.branch_id and l.version_date = s.version_date and l.latest_version = s.version
```

`stg_oasis__stores.sql`:

```sql
-- Oasis store master (control contexts). The name is the description, else the control context, else the heading.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(c_id)                           as store_id,
    coalesce(nullIf({{ hnh_str('description') }}, '0'), nullIf({{ hnh_str('control_context') }}, '0'),
             nullIf({{ hnh_str('heading') }}, '0'), concat('Store ', toString(toInt64(c_id)))) as store_name
from {{ hnh_oasis_source('control_contexts_data') }} final
```

`stg_oasis__products.sql`:

```sql
-- Product per store, current state only (spec F10): average cost per base unit and on-hand quantity.
select
    toUInt8(branch_id)                      as branch_id,
    trimBoth(product_code)                  as product_code,
    toInt64(c_id)                           as store_id,
    {{ hnh_str('product_description') }}    as product_description,
    {{ hnh_code('product_category_code') }} as product_category_code,
    toFloat64(ifNull(qty_on_hand, 0))       as qty_on_hand,
    toFloat64(ifNull(average_cost, 0))      as average_cost,
    {{ hnh_code('stocked_uom_code') }}      as stocked_uom_code,
    {{ hnh_code('write_down_indicator') }}  as item_type_code
from {{ hnh_oasis_source('product_base') }} final
```

`stg_oasis__store_requisitions.sql`:

```sql
-- Bin transactions: store requisitions (REQ), transfers (TRF), purchase requisitions (PR) and others (spec F8).
-- Oasis purchase orders carry no reference to a PR, so these rows are not linked to fact_purchase_line.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(bintran_id)                     as bintran_id,
    {{ hnh_str('doc_no') }}                 as doc_no,
    extract(ifNull(doc_no, ''), '^[A-Za-z]+') as requisition_type,
    {{ hnh_code('status') }}                as status,
    {{ hnh_id('c_id') }}                    as store_id,
    {{ hnh_id('to_c_id') }}                 as to_store_id,
    {{ hnh_str('product_code') }}           as product_code,
    toFloat64(ifNull(qty, 0))               as quantity,
    toFloat64(ifNull(qty_received, 0))      as quantity_received,
    toDate32(tran_date)                     as transaction_date
from {{ hnh_oasis_source('bintran') }} final
```

Replace `stg_oasis__delivery_lines.sql` with (adds `product_code`; the other columns are unchanged):

```sql
select
    toUInt8(branch_id)                  as branch_id,
    toInt64(delivery_line)              as delivery_line,
    {{ hnh_id('master_delivery_no') }}  as master_delivery_no,
    {{ hnh_id('order_line') }}          as order_line,
    {{ hnh_str('product_code') }}       as product_code
from {{ hnh_oasis_source('delivery_lines') }} final
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_oasis__stock_documents stg_oasis__stock_document_lines stg_oasis__stock_batch_snapshots stg_oasis__stores stg_oasis__products stg_oasis__store_requisitions stg_oasis__delivery_lines`
Expected: all PASS (the uniqueness tests on the two large views take about a minute each). Record the counts; measured: stock_documents 73,483,688, stock_document_lines 155,533,861, stock_batch_snapshots 26,482,455, stores 1,585, products 25,927,765, store_requisitions 5,200,636. `stg_oasis__delivery_lines` only gains a column, so its consumers (`fact_charge_line`, `int_order_line_base`) are unaffected.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis/
git commit -m "Stage Oasis stock documents, lines, batch snapshots, stores, products and bin transactions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Inventory organisations and the item crosswalk

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/supply/int_inventory_org_branch.sql`, `int_item_crosswalk.sql`, `_supply__models.yml`, `_supply_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_fusion__inventory_orgs`, `stg_fusion__business_units` (Phase 3: `business_unit_id`, `primary_ledger_id`), `hnh_dim_branch` (`branch_key`, `fusion_ledger_id`), `stg_fusion__inventory_transactions`, `stg_oasis__stock_document_lines`; macros `hnh_org_type_code`, `hnh_oasis_line_ref`, `hnh_fusion_integration_type_ids`.
- Produces:
  - `int_inventory_org_branch(organization_id Int64, organization_code String, organization_name String, branch_key UInt8, org_type_code String)` (branch 0 when unresolved)
  - `int_item_crosswalk(branch_key UInt8, product_code String, inventory_item_id Int64, pair_lines UInt64, units_per_primary Float64)` — one row per branch and Oasis product

- [ ] **Step 1: Write the YAML tests and the failing unit tests**

`_supply__models.yml`:

```yaml
version: 2

models:
  - name: int_inventory_org_branch
    columns:
      - name: organization_id
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
  - name: int_item_crosswalk
    tests:
      - hnh_unique_combination:
          columns: [branch_key, product_code]
    columns:
      - name: units_per_primary
        tests: [not_null]
```

`_supply_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: int_inventory_org_branch_resolves_branch
    description: >
      J04 resolves through its business unit and ledger to Jazan (3), type 04; the master organisation MST to Head
      Office (100), type 00; Alrabwah N02 to branch 1, type 06; an organisation whose business unit has no branch
      ledger gets branch 0.
    model: int_inventory_org_branch
    given:
      - input: ref('stg_fusion__inventory_orgs')
        format: sql
        rows: |
          select toInt64(o) as organization_id, toNullable(c) as organization_code, toNullable(c) as organization_name, toNullable(toInt64(b)) as business_unit_id
          from values('o UInt32, c String, b UInt32', (1, 'J04', 10), (2, 'MST', 11), (3, 'N02', 12), (4, 'X01', 99))
      - input: ref('stg_fusion__business_units')
        format: sql
        rows: |
          select toInt64(b) as business_unit_id, toNullable(toInt64(l)) as primary_ledger_id
          from values('b UInt32, l UInt64', (10, 300000005003387), (11, 300000005003375), (12, 300000005003378), (99, 1))
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(k) as branch_key, toNullable(toInt64(l)) as fusion_ledger_id
          from values('k UInt8, l UInt64', (3, 300000005003387), (100, 300000005003375), (1, 300000005003378))
    expect:
      rows:
        - {organization_id: 1, branch_key: 3, org_type_code: '04'}
        - {organization_id: 2, branch_key: 100, org_type_code: '00'}
        - {organization_id: 3, branch_key: 1, org_type_code: '06'}
        - {organization_id: 4, branch_key: 0, org_type_code: '01'}

  - name: int_item_crosswalk_picks_the_dominant_pair
    description: >
      Jazan product P1 is referenced by Fusion item 500 on three lines and by item 501 on one: item 500 wins; Oasis
      quantities are 30 base units per Fusion primary unit on all three lines. P2 pairs with item 600 on three lines
      with ratios 1, 1 and 10: the modal ratio 1 wins. A Miscellaneous Receipt whose reference looks like a line id
      pairs nothing, and a branch 2 reference to a line that exists only in branch 3 pairs nothing.
    model: int_item_crosswalk
    given:
      - input: ref('stg_fusion__inventory_transactions')
        format: sql
        rows: |
          select toNullable(toInt64(org)) as organization_id, toNullable(toInt64(item)) as inventory_item_id, toNullable(toInt64(tt)) as transaction_type_id,
                 toNullable(ref) as transaction_reference, toFloat64(q) as primary_quantity
          from values('org UInt32, item UInt32, tt UInt64, ref String, q Float64',
              (900, 500, 300000012981827, 'JZ-1', -1), (900, 500, 300000012981827, 'JZ-2', -1), (900, 500, 300000012981827, 'JZ-3', -2),
              (900, 501, 300000012981827, 'JZ-4', -1), (900, 600, 300000012981827, 'JZ-5', -2), (900, 600, 300000012981827, 'JZ-6', -5),
              (900, 600, 300000012981827, 'JZ-7', -1), (900, 700, 42, 'AB-8', 1), (800, 500, 300000012981827, 'GN-1', -1))
      - input: ref('int_inventory_org_branch')
        format: sql
        rows: |
          select toInt64(o) as organization_id, toUInt8(b) as branch_key from values('o UInt32, b UInt8', (900, 3), (800, 2))
      - input: ref('stg_oasis__stock_document_lines')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toInt64(l) as line_id, toNullable(p) as product_code, toFloat64(q) as quantity,
                 toNullable(toDate32('2026-09-01')) as line_date
          from values('l UInt32, p String, q Float64', (1, 'P1', 30), (2, 'P1', 30), (3, 'P1', 60), (4, 'P1', 30), (5, 'P2', 2), (6, 'P2', 5), (7, 'P2', 10), (8, 'P3', 1))
    expect:
      rows:
        - {branch_key: 3, product_code: 'P1', inventory_item_id: 500, pair_lines: 3, units_per_primary: 30}
        - {branch_key: 3, product_code: 'P2', inventory_item_id: 600, pair_lines: 3, units_per_primary: 1}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select int_inventory_org_branch_resolves_branch int_item_crosswalk_picks_the_dominant_pair`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the two models**

`int_inventory_org_branch.sql`:

```sql
{{ config(order_by='organization_id') }}

-- Inventory organisation -> business unit -> primary ledger -> branch (spec 4.1, F3). An organisation that does not
-- resolve gets branch 0, which the facts' tests reject. org_type_code is the two-digit organisation type
-- (01-03 warehouses, 04-12 department organisations, 00 the item master).
select
    o.organization_id                                   as organization_id,
    ifNull(o.organization_code, '')                     as organization_code,
    ifNull(o.organization_name, '')                     as organization_name,
    ifNull(b.branch_key, toUInt8(0))                    as branch_key,
    {{ hnh_org_type_code('o.organization_code') }}      as org_type_code
from {{ ref('stg_fusion__inventory_orgs') }} as o
left join (select business_unit_id, primary_ledger_id from {{ ref('stg_fusion__business_units') }}) as bu
    on bu.business_unit_id = o.business_unit_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = bu.primary_ledger_id
{{ hnh_settings() }}
```

`int_item_crosswalk.sql`:

```sql
{{ config(order_by='(branch_key, product_code)') }}

-- Fusion item per Oasis product and branch, derived from the integration (spec 4.3): a Fusion integration transaction
-- whose reference resolves to an Oasis line of the posting organisation's branch pairs the Fusion item with that line's
-- product. Per product the pair with the most lines wins (ties: the lower item id). units_per_primary is the most
-- frequent ratio of the Oasis base-unit quantity to the Fusion primary quantity over the winning pair's lines
-- (plan refinement: Fusion primary units are packs for about a third of the products).
with refs as (
    select o.branch_key as branch_key, assumeNotNull(t.inventory_item_id) as inventory_item_id,
           {{ hnh_oasis_line_ref('t.transaction_reference') }} as oasis_line_id, abs(t.primary_quantity) as fusion_quantity
    from {{ ref('stg_fusion__inventory_transactions') }} as t
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = t.organization_id
    where t.transaction_type_id in {{ hnh_fusion_integration_type_ids() }}
      and t.inventory_item_id is not null and t.primary_quantity != 0
),

oasis_lines as (
    select branch_id, line_id, assumeNotNull(product_code) as product_code, abs(quantity) as oasis_quantity
    from {{ ref('stg_oasis__stock_document_lines') }}
    where line_date >= toDate32('{{ var("hnh_fusion_inventory_start") }}') and product_code is not null and quantity != 0
),

pairs as (
    select r.branch_key as branch_key, l.product_code as product_code, r.inventory_item_id as inventory_item_id,
           round(l.oasis_quantity / r.fusion_quantity, 4) as ratio
    from refs as r
    inner join oasis_lines as l on l.branch_id = r.branch_key and l.line_id = r.oasis_line_id
    where r.oasis_line_id is not null
),

pair_counts as (
    select branch_key, product_code, inventory_item_id, count() as pair_lines
    from pairs
    group by branch_key, product_code, inventory_item_id
),

best as (
    select branch_key, product_code, inventory_item_id, pair_lines
    from pair_counts
    order by branch_key, product_code, pair_lines desc, inventory_item_id
    limit 1 by branch_key, product_code
),

ratio_counts as (
    select p.branch_key as branch_key, p.product_code as product_code, p.ratio as ratio, count() as ratio_lines
    from pairs as p
    inner join best as b
        on b.branch_key = p.branch_key and b.product_code = p.product_code and b.inventory_item_id = p.inventory_item_id
    group by p.branch_key, p.product_code, p.ratio
),

modal as (
    select branch_key, product_code, ratio as units_per_primary
    from ratio_counts
    order by branch_key, product_code, ratio_lines desc, ratio
    limit 1 by branch_key, product_code
)

select
    b.branch_key                as branch_key,
    b.product_code              as product_code,
    b.inventory_item_id         as inventory_item_id,
    b.pair_lines                as pair_lines,
    m.units_per_primary         as units_per_primary
from best as b
inner join modal as m on m.branch_key = b.branch_key and m.product_code = b.product_code
```

- [ ] **Step 3: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select int_inventory_org_branch int_item_crosswalk`
Expected: both unit tests PASS; models built; YAML tests PASS. Check (measured): `select branch_key, count() from int.int_inventory_org_branch group by 1 order by 1` — 1: 16, 2–8: 12 each, 100: 6, no branch 0 (106 organisations). `select count(), uniqExact(branch_key), countIf(units_per_primary = 1), countIf(units_per_primary > 1), countIf(units_per_primary < 1), sum(pair_lines) from int.int_item_crosswalk` — 14,893 rows over 7 branches, 9,524 at 1, 5,338 above 1, 31 below 1, 879,352 pair lines.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/supply/
git commit -m "Resolve inventory organisations to branches and derive the Fusion-Oasis item crosswalk" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Oasis and Fusion stock lines

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/supply/int_oasis_stock_line.sql`, `int_fusion_stock_line.sql`, `int_store_crosswalk.sql`
- Modify: `_supply__models.yml`, `_supply_unit_tests.yml`

**Interfaces:**
- Consumes: Task 4 Oasis staging, Task 3 Fusion staging, `int_item_crosswalk`, `int_inventory_org_branch`; macros from Task 1.
- Produces:
  - `int_oasis_stock_line(branch_key UInt8, oasis_line_id Int64, oasis_doc_id Int64, oasis_doc_no, doc_type, source_code, line_date Date32, movement_type, is_batch_posting UInt8, store_id Nullable(Int64), transfer_store_id Nullable(Int64), product_code, inventory_item_id Nullable(Int64), item_key Int64, primary_quantity Float64, cost_amount Float64, unit_cost Float64, lot_number, expiry_date, account_code, cross_ref_line_id, bonus_quantity)` — signed + in / − out; `item_key` = `hnh_surrogate_key(['inventory_item_id'])` for crosswalked products, else `hnh_surrogate_key(['branch_key', 'product_code'])`
  - `int_fusion_stock_line(fusion_transaction_id Int64, branch_key UInt8, organization_id, org_type_code, subinventory_code, transfer_organization_id, transfer_subinventory, inventory_item_id, transaction_type_id, transaction_date Date, primary_quantity, rcv_transaction_id, is_integration_type UInt8, reference_status, oasis_line_id Nullable(Int64), is_opening_balance UInt8, fusion_movement_type, valuation_unit_cost Nullable(Float64), lot_number, expiry_date)`; `reference_status` ∈ `oasis_line`, `not_in_oasis`, `no_reference`, `not_integration`
  - `int_store_crosswalk(branch_key UInt8, store_id Int64, organization_id Int64, subinventory_code String, pair_lines UInt64)`

- [ ] **Step 1: Write the YAML tests and the failing unit tests**

Append to `_supply__models.yml`:

```yaml
  - name: int_oasis_stock_line
    tests:
      - hnh_unique_combination:
          columns: [branch_key, oasis_line_id]
    columns:
      - name: movement_type
        tests:
          - accepted_values:
              values: ['Patient sale', 'Patient return', 'Department issue', 'Transfer out', 'Transfer in', 'Goods receipt',
                       'Return to supplier', 'Count adjustment', 'Write-off / misc']
  - name: int_fusion_stock_line
    columns:
      - name: fusion_transaction_id
        tests: [unique, not_null]
      - name: reference_status
        tests:
          - accepted_values:
              values: ['oasis_line', 'not_in_oasis', 'no_reference', 'not_integration']
  - name: int_store_crosswalk
    tests:
      - hnh_unique_combination:
          columns: [branch_key, store_id]
```

Append to `_supply_unit_tests.yml`:

```yaml
  - name: int_oasis_stock_line_classifies_lines
    description: >
      A transfer (STOCKISS ENTT with pod 44 and its STOCKRCPT ENTT, doc TRF1) gives Transfer out of store 45 and
      Transfer in to store 44, each pointing at the other store; P1 maps to Fusion item 500 at 20 base units per
      primary unit. An issue without pod is a Department issue. A patient return (CRD) and a count (CNT) carry no total
      cost, so cost = quantity x unit cost. A costed invoice line is a Patient sale; a zero-cost invoice line, a
      reversed invoice (gl_stk R), a package header, a cancelled GRN line and an unposted document are left out.
    model: int_oasis_stock_line
    given:
      - input: ref('stg_oasis__stock_documents')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toInt64(d) as doc_id, toNullable(dn) as doc_no, toNullable(dt) as doc_type, if(src = '', cast(null as Nullable(String)), toNullable(src)) as source_code, if(pod = 0, cast(null as Nullable(Int64)), toNullable(toInt64(pod))) as pod, toNullable('210103-901') as account_code, toNullable(st) as doc_status, if(gl = '', cast(null as Nullable(String)), toNullable(gl)) as gl_stk, if(ot = '', cast(null as Nullable(String)), toNullable(ot)) as order_type, toNullable(toDate32('2026-09-10')) as doc_date
          from values('d UInt32, dn String, dt String, src String, pod UInt32, st String, gl String, ot String',
              (1, 'TRF1', 'STOCKISS', 'ENTT', 44, 'P', '', ''), (2, 'TRF1', 'STOCKRCPT', 'ENTT', 45, 'P', '', ''),
              (3, 'ISS3', 'STOCKISS', 'ENTT', 0, 'P', '', ''), (4, 'CRD4', 'STOCKRCPT', 'CRD', 0, 'P', '', ''),
              (5, 'CNT5', 'STOCKISS', 'CNT', 0, 'P', '', ''), (6, 'INV6', 'INVOICEAR', 'OASIS', 0, 'P', '123', ''),
              (7, 'INV7', 'INVOICEAR', 'OASIS', 0, 'P', 'R', ''), (8, 'INV8', 'INVOICEAR', 'OASIS', 0, 'P', '', 'PKHEADER'),
              (9, 'GRN9', 'STOCKRCPT', 'GRN', 36, 'P', '', ''), (10, 'ISS10', 'STOCKISS', 'ENTT', 0, 'O', '', ''))
      - input: ref('stg_oasis__stock_document_lines')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toInt64(l) as line_id, toInt64(d) as doc_id, toNullable(dt) as doc_type,
                 toNullable(toDate32('2026-09-10')) as line_date, toNullable(toInt64(s)) as store_id, toNullable(p) as product_code,
                 toFloat64(q) as quantity, toFloat64(uc) as unit_cost, toFloat64(tc) as total_cost,
                 if(ls = '', cast(null as Nullable(String)), toNullable(ls)) as line_status, toNullable(toInt64(77)) as cross_ref_line_id,
                 cast(null as Nullable(String)) as lot_number, toNullable('B1') as batch_number,
                 toNullable(toDate32('2027-01-31')) as expiry_date, toFloat64(0) as bonus_quantity
          from values('l UInt32, d UInt32, dt String, s UInt32, p String, q Float64, uc Float64, tc Float64, ls String',
              (1, 1, 'STOCKISS', 45, 'P1', 20, 0.5, 10, ''), (2, 2, 'STOCKRCPT', 44, 'P1', 20, 0.5, 10, ''),
              (3, 3, 'STOCKISS', 8, 'P2', 4, 2, 8, ''), (4, 4, 'STOCKRCPT', 44, 'P2', 2, 2, 0, ''),
              (5, 5, 'STOCKISS', 81, 'P2', 3, 1.5, 0, ''), (6, 6, 'INVOICEAR', 45, 'P2', 1, 9, 9, ''),
              (7, 6, 'INVOICEAR', 45, 'P3', 1, 0, 0, ''), (8, 7, 'INVOICEAR', 45, 'P2', 1, 5, 5, ''),
              (9, 8, 'INVOICEAR', 45, 'P2', 1, 5, 5, ''), (10, 9, 'STOCKRCPT', 81, 'P2', 5, 10, 50, 'C'),
              (11, 9, 'STOCKRCPT', 81, 'P2', 5, 10, 50, 'P'), (12, 10, 'STOCKISS', 8, 'P2', 1, 3, 3, ''))
      - input: ref('int_item_crosswalk')
        format: sql
        rows: |
          select toUInt8(3) as branch_key, 'P1' as product_code, toInt64(500) as inventory_item_id, toFloat64(20) as units_per_primary
    expect:
      rows:
        - {oasis_line_id: 1, movement_type: 'Transfer out', primary_quantity: -1, cost_amount: -10, unit_cost: 10, transfer_store_id: 44}
        - {oasis_line_id: 2, movement_type: 'Transfer in', primary_quantity: 1, cost_amount: 10, unit_cost: 10, transfer_store_id: 45}
        - {oasis_line_id: 3, movement_type: 'Department issue', primary_quantity: -4, cost_amount: -8, unit_cost: 2, transfer_store_id: null}
        - {oasis_line_id: 4, movement_type: 'Patient return', primary_quantity: 2, cost_amount: 4, unit_cost: 2, transfer_store_id: null}
        - {oasis_line_id: 5, movement_type: 'Count adjustment', primary_quantity: -3, cost_amount: -4.5, unit_cost: 1.5, transfer_store_id: null}
        - {oasis_line_id: 6, movement_type: 'Patient sale', primary_quantity: -1, cost_amount: -9, unit_cost: 9, transfer_store_id: null}
        - {oasis_line_id: 11, movement_type: 'Goods receipt', primary_quantity: 5, cost_amount: 50, unit_cost: 10, transfer_store_id: null}

  - name: int_fusion_stock_line_resolves_lines_and_costs
    description: >
      Transaction 1 is an Oasis Sales Issue posted in Khamis organisation 2004 with the Ghirnata prefix GN-555: the
      branch is Khamis (2) and the line is Khamis line 555 (Ghirnata also has a line 555); its cost is the
      quantity-weighted unit cost of the two valuation layers (1 x 10 + 3 x 14) / 4 = 13. Transaction 2 references a
      line Ghirnata does not hold (not_in_oasis); 3 has no reference. 4 (OB-KH-433) and 5 (CP-12) are an opening load
      and its reversal; 6 is a miscellaneous issue in a ward organisation (Department issue); 7 (INV-ADJ-1) is misc; 8
      is a PO receipt with lot L1.
    model: int_fusion_stock_line
    given:
      - input: ref('stg_fusion__inventory_transactions')
        format: sql
        rows: |
          select toInt64(t) as transaction_id, toNullable(toInt64(org)) as organization_id, toNullable('IPH') as subinventory_code, cast(null as Nullable(Int64)) as transfer_organization_id, cast(null as Nullable(String)) as transfer_subinventory, toNullable(toInt64(500)) as inventory_item_id, toNullable(toInt64(tt)) as transaction_type_id, if(ref = '', cast(null as Nullable(String)), toNullable(ref)) as transaction_reference, cast(null as Nullable(Int64)) as rcv_transaction_id, toDate('2026-09-06') as transaction_date, toFloat64(q) as primary_quantity
          from values('t UInt32, org UInt32, tt UInt64, ref String, q Float64',
              (1, 2004, 300000012981827, 'GN-555', -2), (2, 7004, 300000012981827, 'GN-557', -1), (3, 7004, 300000012981826, '', 1),
              (4, 2002, 42, 'OB-KH-433', 100), (5, 2002, 32, 'CP-12', -100), (6, 2006, 32, '', -1), (7, 2002, 42, 'INV-ADJ-1', 3),
              (8, 2002, 18, '', 10))
      - input: ref('int_inventory_org_branch')
        format: sql
        rows: |
          select toInt64(o) as organization_id, toUInt8(b) as branch_key, t as org_type_code
          from values('o UInt32, b UInt8, t String', (2004, 2, '04'), (7004, 7, '04'), (2006, 2, '06'), (2002, 2, '02'))
      - input: ref('stg_oasis__stock_document_lines')
        format: sql
        rows: |
          select toUInt8(b) as branch_id, toInt64(l) as line_id, toNullable(toDate32('2026-09-06')) as line_date
          from values('b UInt8, l UInt32', (2, 555), (7, 555), (7, 556))
      - input: ref('stg_fusion__inventory_valuation')
        format: sql
        rows: |
          select toNullable(toInt64(500)) as inventory_item_id, toNullable(toInt64(2004)) as inventory_org_id, toDate('2026-09-06') as cost_date,
                 toNullable(toInt64(300000012981827)) as base_txn_type_id, toFloat64(q) as quantity, toFloat64(uc) as unit_cost, toNullable(f) as posted_flag
          from values('q Float64, uc Float64, f String', (-1, 10, 'Y'), (-3, 14, 'E'))
      - input: ref('stg_fusion__inventory_transaction_lots')
        format: sql
        rows: |
          select toInt64(8) as transaction_id, 'L1' as lot_number, toNullable(toInt64(500)) as inventory_item_id, toNullable(toInt64(2002)) as organization_id
      - input: ref('stg_fusion__lots')
        format: sql
        rows: |
          select toInt64(500) as inventory_item_id, toInt64(2002) as organization_id, 'L1' as lot_number, toNullable(toDate32('2027-01-31')) as expiration_date
    expect:
      rows:
        - {fusion_transaction_id: 1, branch_key: 2, reference_status: 'oasis_line', oasis_line_id: 555, is_opening_balance: 0, fusion_movement_type: 'Patient sale', valuation_unit_cost: 13, lot_number: null}
        - {fusion_transaction_id: 2, branch_key: 7, reference_status: 'not_in_oasis', oasis_line_id: null, is_opening_balance: 0, fusion_movement_type: 'Patient sale', valuation_unit_cost: null, lot_number: null}
        - {fusion_transaction_id: 3, branch_key: 7, reference_status: 'no_reference', oasis_line_id: null, is_opening_balance: 0, fusion_movement_type: 'Patient return', valuation_unit_cost: null, lot_number: null}
        - {fusion_transaction_id: 4, branch_key: 2, reference_status: 'not_integration', oasis_line_id: null, is_opening_balance: 1, fusion_movement_type: 'Opening balance', valuation_unit_cost: null, lot_number: null}
        - {fusion_transaction_id: 5, branch_key: 2, reference_status: 'not_integration', oasis_line_id: null, is_opening_balance: 1, fusion_movement_type: 'Opening balance', valuation_unit_cost: null, lot_number: null}
        - {fusion_transaction_id: 6, branch_key: 2, reference_status: 'not_integration', oasis_line_id: null, is_opening_balance: 0, fusion_movement_type: 'Department issue', valuation_unit_cost: null, lot_number: null}
        - {fusion_transaction_id: 7, branch_key: 2, reference_status: 'not_integration', oasis_line_id: null, is_opening_balance: 0, fusion_movement_type: 'Write-off / misc', valuation_unit_cost: null, lot_number: null}
        - {fusion_transaction_id: 8, branch_key: 2, reference_status: 'not_integration', oasis_line_id: null, is_opening_balance: 0, fusion_movement_type: 'Goods receipt', valuation_unit_cost: null, lot_number: 'L1'}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select int_oasis_stock_line_classifies_lines int_fusion_stock_line_resolves_lines_and_costs`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the Oasis stock-line model**

`int_oasis_stock_line.sql` (filters to stock lines before the join: three document types, the history window, costed invoice lines; the right side keeps only posted, non-reversed, non-package-header headers):

```sql
{{ config(order_by='(branch_key, line_date, oasis_line_id)') }}

-- One row per in-scope Oasis stock line from the history start (spec 4.4, 6.1). In scope: posted documents
-- (doc_status P) that are not reversed (gl_stk R) and not package headers; patient invoice lines only with a cost;
-- GRN lines not cancelled or superseded (line status C/S). Credit notes (CREDITAR) are invoice reversals, not stock
-- (plan refinement). Lines are filtered before any join (about 32M of 156M lines).
-- Quantities: Oasis base units converted to the item's primary unit through the crosswalk; signed + in / - out.
-- Cost: total_cost, or quantity x unit cost on lines that carry none (counts, patient returns), with the same sign.
{% set first_day = "toDate32('" ~ var('hnh_history_start_date') ~ "')" %}
{% set last_day = "toDate32(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with lines as (
    select branch_id, line_id, doc_id, doc_type, line_date, store_id, product_code, quantity, unit_cost, total_cost,
           line_status, cross_ref_line_id, lot_number, batch_number, expiry_date, bonus_quantity
    from {{ ref('stg_oasis__stock_document_lines') }}
    where doc_type in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT')
      and line_date >= {{ first_day }} and line_date <= {{ last_day }}
      and (doc_type != 'INVOICEAR' or total_cost != 0)
      and ifNull(line_status, '') not in ('C', 'S')
),

docs as (
    select branch_id, doc_id, doc_no, source_code, pod, account_code
    from {{ ref('stg_oasis__stock_documents') }}
    where doc_type in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT')
      and doc_status = 'P' and ifNull(gl_stk, '') != 'R' and ifNull(order_type, '') != 'PKHEADER'
      and doc_date >= {{ first_day }} - 62
),

classified as (
    select
        l.branch_id                                                     as branch_key,
        l.line_id                                                       as oasis_line_id,
        l.doc_id                                                        as oasis_doc_id,
        d.doc_no                                                        as oasis_doc_no,
        l.doc_type                                                      as doc_type,
        d.source_code                                                   as source_code,
        assumeNotNull(l.line_date)                                      as line_date,
        {{ hnh_oasis_movement_type('l.doc_type', 'd.source_code', 'toUInt8(d.pod is not null)') }} as movement_type,
        toUInt8(ifNull(d.source_code, '') = 'BATCH')                    as is_batch_posting,
        l.store_id                                                      as store_id,
        if(movement_type in ('Transfer out', 'Transfer in'), d.pod, cast(null as Nullable(Int64))) as transfer_store_id,
        l.product_code                                                  as product_code,
        l.quantity                                                      as base_quantity,
        if(l.total_cost != 0, l.total_cost, l.quantity * l.unit_cost)   as base_cost,
        {{ hnh_oasis_direction('l.doc_type') }}                         as direction,
        coalesce(l.lot_number, l.batch_number)                          as lot_number,
        l.expiry_date                                                   as expiry_date,
        d.account_code                                                  as account_code,
        l.cross_ref_line_id                                             as cross_ref_line_id,
        l.bonus_quantity                                                as bonus_quantity
    from lines as l
    inner join docs as d on d.branch_id = l.branch_id and d.doc_id = l.doc_id
)

select
    c.branch_key                                                        as branch_key,
    c.oasis_line_id                                                     as oasis_line_id,
    c.oasis_doc_id                                                      as oasis_doc_id,
    c.oasis_doc_no                                                      as oasis_doc_no,
    c.doc_type                                                          as doc_type,
    c.source_code                                                       as source_code,
    c.line_date                                                         as line_date,
    c.movement_type                                                     as movement_type,
    c.is_batch_posting                                                  as is_batch_posting,
    c.store_id                                                          as store_id,
    c.transfer_store_id                                                 as transfer_store_id,
    c.product_code                                                      as product_code,
    x.inventory_item_id                                                 as inventory_item_id,
    if(x.inventory_item_id is not null, {{ hnh_surrogate_key(['x.inventory_item_id']) }},
       {{ hnh_surrogate_key(['c.branch_key', 'c.product_code']) }})      as item_key,
    c.direction * {{ hnh_primary_qty('c.base_quantity', 'x.units_per_primary') }} as primary_quantity,
    c.direction * c.base_cost                                           as cost_amount,
    if(primary_quantity != 0, cost_amount / primary_quantity, 0)        as unit_cost,
    c.lot_number                                                        as lot_number,
    c.expiry_date                                                       as expiry_date,
    c.account_code                                                      as account_code,
    c.cross_ref_line_id                                                 as cross_ref_line_id,
    {{ hnh_primary_qty('c.bonus_quantity', 'x.units_per_primary') }}    as bonus_quantity
from classified as c
left join {{ ref('int_item_crosswalk') }} as x on x.branch_key = c.branch_key and x.product_code = c.product_code
{{ hnh_settings() }}
```

- [ ] **Step 3: Write the Fusion stock-line model and the store crosswalk**

`int_fusion_stock_line.sql`:

```sql
{{ config(order_by='(branch_key, transaction_date, fusion_transaction_id)') }}

-- One row per Fusion inventory transaction (spec 6.1). Branch from the posting organisation, never from the reference
-- prefix (spec F1). reference_status of the four integration types: oasis_line (the reference resolves to an Oasis line
-- of that branch), not_in_oasis (a reference with no such line), no_reference (none parseable); other types are
-- not_integration. Unit cost: quantity-weighted cost of the valuation layers with the same item, organisation,
-- cost day and transaction type (spec F6).
with tx as (
    select t.transaction_id as transaction_id, t.organization_id as organization_id, t.subinventory_code as subinventory_code,
           t.transfer_organization_id as transfer_organization_id, t.transfer_subinventory as transfer_subinventory,
           t.inventory_item_id as inventory_item_id, t.transaction_type_id as transaction_type_id,
           t.transaction_reference as transaction_reference, t.rcv_transaction_id as rcv_transaction_id,
           t.transaction_date as transaction_date, t.primary_quantity as primary_quantity,
           ifNull(o.branch_key, toUInt8(0)) as branch_key, ifNull(o.org_type_code, '00') as org_type_code,
           toUInt8(ifNull(t.transaction_type_id, 0) in {{ hnh_fusion_integration_type_ids() }}) as is_integration_type,
           if(is_integration_type = 1, {{ hnh_oasis_line_ref('t.transaction_reference') }}, cast(null as Nullable(Int64))) as parsed_line_id
    from {{ ref('stg_fusion__inventory_transactions') }} as t
    left join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = t.organization_id
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

oasis_lines as (
    -- every Oasis line the integration can reference, in scope or not
    select branch_id, line_id
    from {{ ref('stg_oasis__stock_document_lines') }}
    where line_date >= toDate32('{{ var("hnh_fusion_inventory_start") }}') - 92
),

valuation as (
    select inventory_item_id, inventory_org_id, cost_date, base_txn_type_id,
           sum(abs(quantity) * unit_cost) / sum(abs(quantity)) as layer_unit_cost
    from {{ ref('stg_fusion__inventory_valuation') }}
    where quantity != 0 and posted_flag in ('Y', 'E')
    group by inventory_item_id, inventory_org_id, cost_date, base_txn_type_id
),

lots as (
    select tl.transaction_id as transaction_id, min(tl.lot_number) as first_lot, min(lt.expiration_date) as first_expiry
    from {{ ref('stg_fusion__inventory_transaction_lots') }} as tl
    left join {{ ref('stg_fusion__lots') }} as lt
        on lt.inventory_item_id = tl.inventory_item_id and lt.organization_id = tl.organization_id and lt.lot_number = tl.lot_number
    group by tl.transaction_id
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
)

select
    t.transaction_id                                                    as fusion_transaction_id,
    t.branch_key                                                        as branch_key,
    t.organization_id                                                   as organization_id,
    t.org_type_code                                                     as org_type_code,
    t.subinventory_code                                                 as subinventory_code,
    t.transfer_organization_id                                          as transfer_organization_id,
    t.transfer_subinventory                                             as transfer_subinventory,
    t.inventory_item_id                                                 as inventory_item_id,
    t.transaction_type_id                                               as transaction_type_id,
    t.transaction_date                                                  as transaction_date,
    t.primary_quantity                                                  as primary_quantity,
    t.rcv_transaction_id                                                as rcv_transaction_id,
    t.is_integration_type                                               as is_integration_type,
    multiIf(t.is_integration_type = 0, 'not_integration', t.parsed_line_id is null, 'no_reference',
            ol.line_id is not null, 'oasis_line', 'not_in_oasis')       as reference_status,
    if(reference_status = 'oasis_line', t.parsed_line_id, cast(null as Nullable(Int64))) as oasis_line_id,
    {{ hnh_is_opening_balance('t.transaction_type_id', 't.transaction_reference') }} as is_opening_balance,
    {{ hnh_fusion_movement_type('t.transaction_type_id', 't.primary_quantity', 't.org_type_code', 'is_opening_balance') }} as fusion_movement_type,
    v.layer_unit_cost                                                   as valuation_unit_cost,
    lt.first_lot                                                        as lot_number,
    lt.first_expiry                                                     as expiry_date
from tx as t
left join oasis_lines as ol on ol.branch_id = t.branch_key and ol.line_id = t.parsed_line_id
left join valuation as v
    on v.inventory_item_id = t.inventory_item_id and v.inventory_org_id = t.organization_id
   and v.cost_date = t.transaction_date and v.base_txn_type_id = t.transaction_type_id
left join lots as lt on lt.transaction_id = t.transaction_id
{{ hnh_settings() }}
```

`int_store_crosswalk.sql`:

```sql
{{ config(order_by='(branch_key, store_id)') }}

-- The Fusion store (organisation + subinventory) each Oasis store maps to through the integration (spec 5.2): the pair
-- with the most integration transactions (ties: the lower organisation id, then subinventory code).
with pairs as (
    select f.branch_key as branch_key, assumeNotNull(l.store_id) as oasis_store_id, f.organization_id as fusion_organization_id,
           ifNull(f.subinventory_code, '*') as fusion_subinventory_code, count() as pair_lines
    from {{ ref('int_fusion_stock_line') }} as f
    inner join (select branch_id, line_id, store_id from {{ ref('stg_oasis__stock_document_lines') }}
                where store_id is not null and line_date >= toDate32('{{ var("hnh_fusion_inventory_start") }}') - 92) as l
        on l.branch_id = f.branch_key and l.line_id = f.oasis_line_id
    where f.reference_status = 'oasis_line' and f.organization_id is not null
    group by f.branch_key, l.store_id, f.organization_id, f.subinventory_code
)

select
    branch_key                          as branch_key,
    oasis_store_id                      as store_id,
    assumeNotNull(fusion_organization_id) as organization_id,
    fusion_subinventory_code            as subinventory_code,
    pair_lines                          as pair_lines
from pairs
order by branch_key, oasis_store_id, pair_lines desc, fusion_organization_id, fusion_subinventory_code
limit 1 by branch_key, oasis_store_id
```

- [ ] **Step 4: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select int_oasis_stock_line int_fusion_stock_line int_store_crosswalk`
Expected: both unit tests PASS; models built; YAML tests PASS. Expected build time: `int_oasis_stock_line` 2–4 minutes (the equivalent select read 155.5M lines and returned 32.2M rows in 78 s), the other two under a minute.

Check (measured): `select movement_type, count() from int.int_oasis_stock_line group by 1 order by 1` — Count adjustment 463,912; Department issue 911,477; Goods receipt 387,220; Patient return 182,061; Patient sale 26,275,976; Return to supplier 6,862; Transfer in 1,900,032; Transfer out 1,899,694; Write-off / misc 154,241 (total 32,181,475). `select reference_status, is_opening_balance, count() from int.int_fusion_stock_line group by 1, 2 order by 1, 2` — no_reference 38,406; not_in_oasis 8,282; not_integration 41,869 (+ 64,253 opening balance); oasis_line 881,340 (total 1,034,150, none on branch 0). `select count() from int.int_store_crosswalk` — about 325.

Record the peak memory: `select formatReadableSize(max(memory_usage)) from system.query_log where event_time > now() - interval 30 minute and type = 'QueryFinish' and query like '%int_oasis_stock_line%'` (through `ch_env`); BLOCKED if above 100 GiB.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/supply/
git commit -m "Classify Oasis stock lines and Fusion inventory transactions" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Item, store and movement-type dimensions, and Oasis suppliers

**Files:**
- Create in `hnh_dwh/models/hnh/marts/conformed/`: `hnh_dim_item.sql`, `dim_store.sql`, `dim_movement_type.sql`
- Modify: `hnh_dim_supplier.sql`, `_conformed__models.yml`

**Interfaces:**
- Consumes: `stg_fusion__items`, `stg_fusion__item_categories`, `stg_ref__item_group`, `int_item_crosswalk`, `stg_oasis__products`, `dim_product_category` (`branch_key`, `category_code`, `product_group`), `int_oasis_stock_line`, `stg_oasis__stock_document_lines`, `stg_oasis__stock_batch_snapshots`, `stg_ref__stock_snapshot`, `stg_oasis__stores`, `stg_ref__store_department`, `int_store_crosswalk`, `stg_fusion__subinventories`, `stg_fusion__inventory_orgs`, `int_fusion_stock_line`, `stg_fusion__inventory_onhand`, `stg_fusion__receipt_transactions`, `int_inventory_org_branch`, `stg_fusion__suppliers`, `stg_oasis__external_accounts` (`branch_id`, `account_code`, `account_type`, `account_name`).
- Produces:
  - `hnh_dim_item` (alias `dim_item`): `item_key, source_system ('fusion'|'oasis'|'unknown'), branch_key (0 for Fusion items), inventory_item_id, item_number, item_description, primary_uom_code, item_type, item_status, is_lot_controlled, category_code, item_group, is_deleted, oasis_product_code, oasis_product_codes ('branch:product, ...'), oasis_product_category, product_group`; Fusion `item_key` = `hnh_surrogate_key(['inventory_item_id'])`, Oasis-only `hnh_surrogate_key(['branch_id', 'product_code'])`, Unknown `-1`
  - `dim_store`: `store_key, source_system, branch_key, store_code, store_name, organization_id, subinventory_code, oasis_store_id, store_type, unified_department, store_group_key, is_expiry_store`; Oasis `store_key` = `hnh_surrogate_key(["'oasis'", 'branch_id', 'store_id'])`, Fusion `hnh_surrogate_key(["'fusion'", 'organization_id', 'subinventory_code'])` (organisation level `'*'`), Unknown `-1`
  - `dim_movement_type(movement_type_key, movement_type, direction Int8, is_consumption UInt8, sort_order UInt8)`, key `hnh_surrogate_key(['movement_type'])`
  - `hnh_dim_supplier` (alias `dim_supplier`) + `source_system`, `supplier_code`, `oasis_branch_key`; Oasis `supplier_key` = `hnh_surrogate_key(["'oasis'", 'branch_id', 'account_code'])`; Fusion keys unchanged

- [ ] **Step 1: Write the YAML tests**

Append to `_conformed__models.yml`:

```yaml
  - name: hnh_dim_item
    columns:
      - name: item_key
        tests: [unique, not_null]
      - name: item_group
        tests:
          - accepted_values:
              values: ['Medication', 'Medical consumable', 'Implant', 'Laboratory', 'General', 'Asset', 'Other']
      - name: source_system
        tests:
          - accepted_values:
              values: ['fusion', 'oasis', 'unknown']
  - name: dim_store
    columns:
      - name: store_key
        tests: [unique, not_null]
      - name: store_group_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
  - name: dim_movement_type
    columns:
      - name: movement_type_key
        tests: [unique, not_null]
      - name: movement_type
        tests: [unique]
```

and add under the existing `hnh_dim_supplier` entry's `columns:`:

```yaml
      - name: source_system
        tests:
          - accepted_values:
              values: ['fusion', 'oasis', 'unknown']
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select hnh_dim_item dim_store dim_movement_type`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the dimensions**

`dim_movement_type.sql`:

```sql
{{ config(order_by='movement_type_key') }}

-- Static movement types (spec 4.4, 5.3).
select
    {{ hnh_surrogate_key(['m']) }}          as movement_type_key,
    m                                       as movement_type,
    {{ hnh_movement_direction('m') }}       as direction,
    {{ hnh_is_consumption('m') }}           as is_consumption,
    toUInt8(s)                              as sort_order
from values('m String, s UInt8',
    ('Patient sale', 1), ('Patient return', 2), ('Department issue', 3), ('Transfer out', 4), ('Transfer in', 5),
    ('Goods receipt', 6), ('Return to supplier', 7), ('Count adjustment', 8), ('Write-off / misc', 9), ('Opening balance', 10))
```

`hnh_dim_item.sql`:

```sql
{{ config(alias='dim_item', order_by='item_key') }}

-- Fusion master items (the MST organisation holds every item) and Oasis products that have no Fusion item (spec 5.1).
-- Fusion items carry the Oasis products they map to per branch ("branch:product", through the crosswalk).
{% set master_org = var('hnh_fusion_item_master_org_id') %}
{% set first_day = "toDate32('" ~ var('hnh_history_start_date') ~ "')" %}

with categories as (
    select inventory_item_id, any(category_code) as master_category_code
    from {{ ref('stg_fusion__item_categories') }}
    where organization_id = {{ master_org }} and category_set_name = 'HNH Catalog' and category_code is not null
    group by inventory_item_id
),

products as (
    select branch_id, product_code, any(product_description) as product_name, any(product_category_code) as product_category
    from {{ ref('stg_oasis__products') }}
    group by branch_id, product_code
),

product_groups as (
    select branch_key, assumeNotNull(category_code) as category_code, product_group
    from {{ ref('dim_product_category') }}
    where category_code is not null
),

mapped_products as (
    select x.inventory_item_id as inventory_item_id,
           arrayStringConcat(arraySort(groupUniqArray(concat(toString(x.branch_key), ':', x.product_code))), ', ') as oasis_product_codes,
           topKIf(1)(p.product_category, p.product_category is not null)[1] as mapped_category,
           topKIf(1)(g.product_group, g.product_group is not null)[1] as mapped_product_group
    from {{ ref('int_item_crosswalk') }} as x
    left join products as p on p.branch_id = x.branch_key and p.product_code = x.product_code
    left join product_groups as g on g.branch_key = x.branch_key and g.category_code = p.product_category
    group by x.inventory_item_id
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

fusion_items as (
    select
        {{ hnh_surrogate_key(['i.inventory_item_id']) }}               as item_key,
        'fusion'                                                       as source_system,
        toUInt8(0)                                                     as branch_key,
        toNullable(i.inventory_item_id)                                as inventory_item_id,
        i.item_number                                                  as item_number,
        i.item_description                                             as item_description,
        i.primary_uom_code                                             as primary_uom_code,
        i.item_type                                                    as item_type,
        i.item_status                                                  as item_status,
        i.is_lot_controlled                                            as is_lot_controlled,
        c.master_category_code                                         as category_code,
        ifNull(ig.item_group, 'Other')                                 as item_group,
        toUInt8(ifNull(i.item_number, '') like 'Deleted-%')            as is_deleted,
        cast(null as Nullable(String))                                 as oasis_product_code,
        nullIf(m.oasis_product_codes, '')                              as oasis_product_codes,
        nullIf(m.mapped_category, '')                                  as oasis_product_category,
        if(ifNull(m.mapped_product_group, '') = '', 'Not Mapped', m.mapped_product_group) as product_group
    from {{ ref('stg_fusion__items') }} as i
    left join categories as c on c.inventory_item_id = i.inventory_item_id
    left join {{ ref('stg_ref__item_group') }} as ig on ig.category_code = c.master_category_code
    left join mapped_products as m on m.inventory_item_id = i.inventory_item_id
    where i.organization_id = {{ master_org }}
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

oasis_used as (
    -- Oasis products that occur in stock lines, purchase orders or stock snapshots and have no Fusion item
    select distinct branch_id, product_code from (
        select branch_key as branch_id, assumeNotNull(product_code) as product_code
        from {{ ref('int_oasis_stock_line') }} where inventory_item_id is null and product_code is not null
        union all
        select branch_id, assumeNotNull(product_code)
        from {{ ref('stg_oasis__stock_document_lines') }}
        where doc_type = 'PORDER' and product_code is not null and line_date >= {{ first_day }}
        union all
        select branch_id, product_code from {{ ref('stg_oasis__stock_batch_snapshots') }}
        union all
        select branch_id, product_code from {{ ref('stg_ref__stock_snapshot') }}
    )
    where (branch_id, product_code) not in (select branch_key, product_code from {{ ref('int_item_crosswalk') }})
),

oasis_items as (
    select
        {{ hnh_surrogate_key(['u.branch_id', 'u.product_code']) }}     as item_key,
        'oasis'                                                        as source_system,
        u.branch_id                                                    as branch_key,
        cast(null as Nullable(Int64))                                  as inventory_item_id,
        toNullable(u.product_code)                                     as item_number,
        p.product_name                                                 as item_description,
        cast(null as Nullable(String))                                 as primary_uom_code,
        cast(null as Nullable(String))                                 as item_type,
        cast(null as Nullable(String))                                 as item_status,
        toUInt8(0)                                                     as is_lot_controlled,
        cast(null as Nullable(String))                                 as category_code,
        multiIf(g.product_group = 'medication', 'Medication', g.product_group = 'medical', 'Medical consumable',
                g.product_group = 'non medical', 'General', 'Other')   as item_group,
        toUInt8(0)                                                     as is_deleted,
        toNullable(u.product_code)                                     as oasis_product_code,
        cast(null as Nullable(String))                                 as oasis_product_codes,
        p.product_category                                             as oasis_product_category,
        ifNull(g.product_group, 'Not Mapped')                          as product_group
    from oasis_used as u
    left join products as p on p.branch_id = u.branch_id and p.product_code = u.product_code
    left join product_groups as g on g.branch_key = u.branch_id and g.category_code = p.product_category
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
)

select * from fusion_items
union all
select * from oasis_items
union all
select toInt64(-1), 'unknown', toUInt8(0), null, null, 'Unknown', null, null, null, toUInt8(0), null, 'Other', toUInt8(0),
       null, null, null, 'Unknown'
{{ hnh_settings() }}
```

`dim_store.sql`:

```sql
{{ config(order_by='store_key') }}

-- One row per Oasis store (branch + c_id) and per Fusion store (organisation + subinventory) (spec 5.2). Every Fusion
-- organisation also has an organisation-level member, subinventory '*', for stock valued without a subinventory split.
-- Type and unified department come from map_store_department; a store with no mapping row is 'Unmapped'. An Oasis store
-- and the Fusion store it maps to through the integration share store_group_key.
with oasis_ids as (
    select branch_id, store_id, any(store_name) as known_name from (
        select branch_id, store_id, toNullable(store_name) as store_name from {{ ref('stg_oasis__stores') }}
        union all
        select branch_key, assumeNotNull(store_id), cast(null as Nullable(String))
        from {{ ref('int_oasis_stock_line') }} where store_id is not null group by branch_key, store_id
        union all
        select branch_key, assumeNotNull(transfer_store_id), cast(null as Nullable(String))
        from {{ ref('int_oasis_stock_line') }} where transfer_store_id is not null group by branch_key, transfer_store_id
        union all
        select branch_id, assumeNotNull(store_id), cast(null as Nullable(String))
        from {{ ref('stg_oasis__stock_document_lines') }} where doc_type = 'PORDER' and store_id is not null group by branch_id, store_id
        union all
        select branch_id, store_id, cast(null as Nullable(String)) from {{ ref('stg_oasis__stock_batch_snapshots') }} group by branch_id, store_id
        union all
        select branch_id, store_id, cast(null as Nullable(String)) from {{ ref('stg_ref__stock_snapshot') }} group by branch_id, store_id
    )
    group by branch_id, store_id
),

fusion_ids as (
    select organization_id, subinventory_code, any(description) as known_description from (
        select organization_id, subinventory_code, subinventory_description as description from {{ ref('stg_fusion__subinventories') }}
        union all
        select organization_id, '*', cast(null as Nullable(String)) from {{ ref('stg_fusion__inventory_orgs') }}
        union all
        select assumeNotNull(organization_id), ifNull(subinventory_code, '*'), cast(null as Nullable(String))
        from {{ ref('int_fusion_stock_line') }} where organization_id is not null group by organization_id, subinventory_code
        union all
        select assumeNotNull(transfer_organization_id), ifNull(transfer_subinventory, '*'), cast(null as Nullable(String))
        from {{ ref('int_fusion_stock_line') }} where transfer_organization_id is not null
        group by transfer_organization_id, transfer_subinventory
        union all
        select assumeNotNull(organization_id), ifNull(subinventory_code, '*'), cast(null as Nullable(String))
        from {{ ref('stg_fusion__inventory_onhand') }} where organization_id is not null group by organization_id, subinventory_code
        union all
        select assumeNotNull(organization_id), ifNull(subinventory_code, '*'), cast(null as Nullable(String))
        from {{ ref('stg_fusion__receipt_transactions') }} where organization_id is not null group by organization_id, subinventory_code
    )
    group by organization_id, subinventory_code
),

oasis_stores as (
    select
        {{ hnh_surrogate_key(["'oasis'", 'o.branch_id', 'o.store_id']) }}  as store_key,
        'oasis'                                                            as source_system,
        o.branch_id                                                        as branch_key,
        toString(o.store_id)                                               as store_code,
        coalesce(m.store_name, o.known_name, concat('Store ', toString(o.store_id))) as store_name,
        cast(null as Nullable(Int64))                                      as organization_id,
        cast(null as Nullable(String))                                     as subinventory_code,
        toNullable(o.store_id)                                             as oasis_store_id,
        ifNull(m.store_type, 'Unmapped')                                   as store_type,
        ifNull(m.unified_department, 'Not Mapped')                         as unified_department,
        if(x.organization_id is null, {{ hnh_surrogate_key(["'oasis'", 'o.branch_id', 'o.store_id']) }},
           {{ hnh_surrogate_key(["'fusion'", 'x.organization_id', 'x.subinventory_code']) }}) as store_group_key
    from oasis_ids as o
    left join (select branch_id, store_code, store_name, store_type, unified_department
               from {{ ref('stg_ref__store_department') }} where source = 'oasis') as m
        on m.branch_id = o.branch_id and m.store_code = toString(o.store_id)
    left join {{ ref('int_store_crosswalk') }} as x on x.branch_key = o.branch_id and x.store_id = o.store_id
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

fusion_stores as (
    select
        {{ hnh_surrogate_key(["'fusion'", 'f.organization_id', 'f.subinventory_code']) }} as store_key,
        'fusion'                                                           as source_system,
        ifNull(g.branch_key, toUInt8(0))                                   as branch_key,
        concat(ifNull(g.organization_code, toString(f.organization_id)), '/', f.subinventory_code) as store_code,
        coalesce(m.store_name, f.known_description,
                 if(f.subinventory_code = '*', g.organization_name, f.subinventory_code)) as store_name,
        toNullable(f.organization_id)                                      as organization_id,
        toNullable(f.subinventory_code)                                    as subinventory_code,
        cast(null as Nullable(Int64))                                      as oasis_store_id,
        ifNull(m.store_type, 'Unmapped')                                   as store_type,
        ifNull(m.unified_department, 'Not Mapped')                         as unified_department,
        {{ hnh_surrogate_key(["'fusion'", 'f.organization_id', 'f.subinventory_code']) }} as store_group_key
    from fusion_ids as f
    left join {{ ref('int_inventory_org_branch') }} as g on g.organization_id = f.organization_id
    left join (select store_code, store_name, store_type, unified_department
               from {{ ref('stg_ref__store_department') }} where source = 'fusion') as m
        on m.store_code = concat(ifNull(g.organization_code, toString(f.organization_id)), '/', f.subinventory_code)
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
)

select *, toUInt8(store_type = 'Expiry/damaged/recall') as is_expiry_store from oasis_stores
union all
select *, toUInt8(store_type = 'Expiry/damaged/recall') from fusion_stores
union all
select toInt64(-1), 'unknown', toUInt8(0), '', 'Unknown', null, null, null, 'Unmapped', 'Not Mapped', toInt64(-1), toUInt8(0)
{{ hnh_settings() }}
```

Replace `hnh_dim_supplier.sql` with (the Fusion select and keys are unchanged; Oasis supplier accounts are added):

```sql
{{ config(alias='dim_supplier', order_by='supplier_key') }}

-- Fusion supplier sites (Phase 3, keys unchanged) and Oasis supplier accounts (account type S) per branch (spec 5.4).
select
    {{ hnh_surrogate_key(['vendor_id', 'vendor_site_id']) }} as supplier_key,
    toNullable(vendor_id)       as vendor_id,
    toNullable(vendor_site_id)  as vendor_site_id,
    supplier_number,
    supplier_name,
    supplier_type,
    supplier_status,
    site_code,
    business_unit_id,
    country,
    'fusion'                    as source_system,
    toString(supplier_number)   as supplier_code,
    cast(null as Nullable(UInt8)) as oasis_branch_key
from {{ ref('stg_fusion__suppliers') }}

union all

select
    {{ hnh_surrogate_key(["'oasis'", 'branch_id', 'account_code']) }},
    null, null, null, account_name, 'Oasis supplier', null, null, null, null,
    'oasis', account_code, toNullable(branch_id)
from {{ ref('stg_oasis__external_accounts') }}
where account_type = 'S' and account_code is not null

union all

select toInt64(-1), null, null, null, 'Unknown', null, null, null, null, null, 'unknown', null, null
```

- [ ] **Step 3: Run the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select hnh_dim_item dim_store dim_movement_type hnh_dim_supplier+1`
(`+1` also rebuilds and tests the Phase 3 facts that read `hnh_dim_supplier`.)
Expected: all PASS, including `fact_ap_invoice_line_splits_spend_and_tax`. Check (measured): `select source_system, count(), countIf(is_deleted = 1), countIf(oasis_product_codes is not null) from gold.dim_item group by 1` — fusion 22,689 / 8,069 / 5,441; oasis 76,626; unknown 1. `select source_system, count(), countIf(store_type = 'Unmapped'), countIf(is_expiry_store = 1), countIf(store_group_key != store_key) from gold.dim_store group by 1` — oasis 1,585 / 228 / 32 / about 325; fusion 1,032 / 0 / 60 / 0; unknown 1. `select source_system, count() from gold.dim_supplier group by 1` — fusion 20,403, oasis 11,640, unknown 1. `gold.dim_movement_type` has 10 rows.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed/
git commit -m "Add item, store and movement-type dimensions and Oasis suppliers" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Stock movement fact and its conservation tests

**Files:**
- Create: `hnh_dwh/models/hnh/marts/supply/fact_stock_movement.sql`, `_supply_marts__models.yml`, `_supply_marts_unit_tests.yml`, `hnh_dwh/tests/hnh/assert_stock_movement_conservation.sql`, `assert_stock_line_single_source.sql`

**Interfaces:**
- Consumes: `int_oasis_stock_line`, `int_fusion_stock_line`, `stg_ref__scm_cutover`, `dim_store` (`store_key`), `hnh_dim_item` (`item_key`).
- Produces: `fact_stock_movement(movement_key, branch_key, date_key, store_key, transfer_store_key, item_key, movement_type_key, movement_type, source_system, is_in_oasis, is_in_fusion, is_fusion_gap, is_opening_balance, is_consumption, oasis_line_id Nullable(Int64), oasis_doc_no, oasis_product_code, fusion_transaction_id Nullable(Int64), fusion_transaction_count UInt32, fusion_transaction_date_key, primary_quantity, unit_cost, cost_amount, cost_source, consumption_quantity, consumption_cost, lot_number, expiry_date, _loaded_at)`. `movement_key` = `hnh_surrogate_key(["'oasis-line'", 'branch_key', 'oasis_line_id'])` for lines with an Oasis line id, else `hnh_surrogate_key(["'fusion-transaction'", 'fusion_transaction_id'])`.

- [ ] **Step 1: Write the failing unit test, the YAML and the two assertions**

`_supply_marts_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: fact_stock_movement_switches_at_go_live
    description: >
      Jazan goes live on 2026-07-12. Line 101 (11 July) stays Oasis although Fusion holds it; line 102 (12 July) is the
      Fusion transaction, costed from valuation (12); line 103 has no Fusion transaction (gap fill); line 104 has a
      Fusion transaction without valuation (cost from the Oasis line, 8 per unit); line 105 is an Oasis batch posting
      after go-live (left out); line 106 was posted twice in Fusion and corrected by a reversal (three transactions net
      to one, cost -40). Fusion-only: 9010 a PO receipt (valuation 5), 9011 before go-live (left out), 9012 an
      integration row without reference (left out), 9013 a reference Oasis does not hold (no cost), 9014 an opening
      balance. Alrabwah (no go-live) line 201 is Oasis.
    model: fact_stock_movement
    given:
      - input: ref('int_oasis_stock_line')
        format: sql
        rows: |
          select toUInt8(b) as branch_key, toInt64(l) as oasis_line_id, toNullable(concat('DOC', toString(l))) as oasis_doc_no, toDate32(d) as line_date, mt as movement_type, toUInt8(bp) as is_batch_posting, toNullable(toInt64(45)) as store_id, cast(null as Nullable(Int64)) as transfer_store_id, toNullable('P1') as product_code, toInt64(777) as item_key, toFloat64(q) as primary_quantity, toFloat64(c) as cost_amount, toFloat64(uc) as unit_cost, cast(null as Nullable(String)) as lot_number, cast(null as Nullable(Date32)) as expiry_date
          from values('b UInt8, l UInt32, d String, mt String, bp UInt8, q Float64, c Float64, uc Float64',
              (3, 101, '2026-07-11', 'Patient sale', 0, -2, -20, 10), (3, 102, '2026-07-12', 'Patient sale', 0, -1, -10, 10),
              (3, 103, '2026-07-12', 'Patient sale', 0, -3, -30, 10), (3, 104, '2026-07-13', 'Patient sale', 0, -1, -8, 8),
              (3, 105, '2026-07-14', 'Write-off / misc', 1, 5, 25, 5), (3, 106, '2026-07-14', 'Transfer out', 0, -4, -40, 10),
              (1, 201, '2026-08-01', 'Department issue', 0, -1, -3, 3))
      - input: ref('int_fusion_stock_line')
        format: sql
        rows: |
          select toInt64(t) as fusion_transaction_id, toUInt8(b) as branch_key, toNullable(toInt64(3004)) as organization_id, toNullable('IPH') as subinventory_code, cast(null as Nullable(Int64)) as transfer_organization_id, cast(null as Nullable(String)) as transfer_subinventory, toNullable(toInt64(500)) as inventory_item_id, toDate(d) as transaction_date, toFloat64(q) as primary_quantity, rs as reference_status, if(l = 0, cast(null as Nullable(Int64)), toNullable(toInt64(l))) as oasis_line_id, toUInt8(ob) as is_opening_balance, mt as fusion_movement_type, if(v < 0, cast(null as Nullable(Float64)), toNullable(toFloat64(v))) as valuation_unit_cost, cast(null as Nullable(String)) as lot_number, cast(null as Nullable(Date32)) as expiry_date
          from values('t UInt32, b UInt8, d String, q Float64, rs String, l UInt32, ob UInt8, mt String, v Float64',
              (9001, 3, '2026-07-12', -2, 'oasis_line', 101, 0, 'Patient sale', 11), (9002, 3, '2026-07-12', -1, 'oasis_line', 102, 0, 'Patient sale', 12),
              (9004, 3, '2026-07-14', -1, 'oasis_line', 104, 0, 'Patient sale', -1), (9005, 3, '2026-07-15', 5, 'oasis_line', 105, 0, 'Patient return', 5),
              (9061, 3, '2026-07-14', -4, 'oasis_line', 106, 0, 'Transfer out', 10), (9062, 3, '2026-07-14', -4, 'oasis_line', 106, 0, 'Transfer out', 10),
              (9063, 3, '2026-07-15', 4, 'oasis_line', 106, 0, 'Transfer in', 10),
              (9010, 3, '2026-07-15', 10, 'not_integration', 0, 0, 'Goods receipt', 5), (9011, 3, '2026-07-10', 10, 'not_integration', 0, 0, 'Goods receipt', 5),
              (9012, 3, '2026-07-15', -1, 'no_reference', 0, 0, 'Patient sale', 5), (9013, 3, '2026-07-16', -1, 'not_in_oasis', 0, 0, 'Patient sale', -1),
              (9014, 3, '2026-07-16', 7, 'not_integration', 0, 1, 'Opening balance', 2))
      - input: ref('stg_ref__scm_cutover')
        format: sql
        rows: |
          select toUInt8(b) as branch_id, if(d = '', cast(null as Nullable(Date)), toNullable(toDate(d))) as inventory_go_live_date
          from values('b UInt8, d String', (3, '2026-07-12'), (100, ''))
      - input: ref('dim_store')
        format: sql
        rows: |
          select toInt64(1) as store_key
      - input: ref('hnh_dim_item')
        format: sql
        rows: |
          select toInt64(777) as item_key
    expect:
      rows:
        - {oasis_line_id: 101, fusion_transaction_id: 9001, date_key: 20260711, source_system: 'oasis', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Patient sale', primary_quantity: -2, cost_amount: -20, cost_source: 'oasis_line', consumption_cost: 20, fusion_transaction_count: 1}
        - {oasis_line_id: 102, fusion_transaction_id: 9002, date_key: 20260712, source_system: 'fusion', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Patient sale', primary_quantity: -1, cost_amount: -12, cost_source: 'fusion_valuation', consumption_cost: 12, fusion_transaction_count: 1}
        - {oasis_line_id: 103, fusion_transaction_id: null, date_key: 20260712, source_system: 'oasis', is_in_fusion: 0, is_fusion_gap: 1, movement_type: 'Patient sale', primary_quantity: -3, cost_amount: -30, cost_source: 'oasis_line', consumption_cost: 30, fusion_transaction_count: 0}
        - {oasis_line_id: 104, fusion_transaction_id: 9004, date_key: 20260713, source_system: 'fusion', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Patient sale', primary_quantity: -1, cost_amount: -8, cost_source: 'oasis_line', consumption_cost: 8, fusion_transaction_count: 1}
        - {oasis_line_id: 106, fusion_transaction_id: 9061, date_key: 20260714, source_system: 'fusion', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Transfer out', primary_quantity: -4, cost_amount: -40, cost_source: 'fusion_valuation', consumption_cost: 0, fusion_transaction_count: 3}
        - {oasis_line_id: 201, fusion_transaction_id: null, date_key: 20260801, source_system: 'oasis', is_in_fusion: 0, is_fusion_gap: 0, movement_type: 'Department issue', primary_quantity: -1, cost_amount: -3, cost_source: 'oasis_line', consumption_cost: 3, fusion_transaction_count: 0}
        - {oasis_line_id: null, fusion_transaction_id: 9010, date_key: 20260715, source_system: 'fusion', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Goods receipt', primary_quantity: 10, cost_amount: 50, cost_source: 'fusion_valuation', consumption_cost: 0, fusion_transaction_count: 1}
        - {oasis_line_id: null, fusion_transaction_id: 9013, date_key: 20260716, source_system: 'fusion', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Patient sale', primary_quantity: -1, cost_amount: 0, cost_source: 'none', consumption_cost: 0, fusion_transaction_count: 1}
        - {oasis_line_id: null, fusion_transaction_id: 9014, date_key: 20260716, source_system: 'fusion', is_in_fusion: 1, is_fusion_gap: 0, movement_type: 'Opening balance', primary_quantity: 7, cost_amount: 14, cost_source: 'fusion_valuation', consumption_cost: 0, fusion_transaction_count: 1}
```

`_supply_marts__models.yml`:

```yaml
version: 2

models:
  - name: fact_stock_movement
    columns:
      - name: movement_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: store_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: transfer_store_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: item_key
        tests:
          - relationships: {to: ref('hnh_dim_item'), field: item_key}
      - name: movement_type_key
        tests:
          - relationships: {to: ref('dim_movement_type'), field: movement_type_key}
      - name: fusion_transaction_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: source_system
        tests:
          - accepted_values:
              values: ['oasis', 'fusion']
      - name: cost_source
        tests:
          - accepted_values:
              values: ['fusion_valuation', 'oasis_line', 'none']
```

`hnh_dwh/tests/hnh/assert_stock_movement_conservation.sql`:

```sql
-- Conservation (spec 8): every in-scope Oasis line appears in fact_stock_movement exactly once (as itself or through
-- Fusion), except Oasis batch postings from the go-live; and every Fusion transaction that is a line of its own (not an
-- integration row, or a reference Oasis does not hold, from the go-live) appears exactly once. Per branch.
with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }} where inventory_go_live_date is not null
),

expected_oasis as (
    select o.branch_key as branch_key, count() as expected_lines
    from {{ ref('int_oasis_stock_line') }} as o
    left join cutover as k on k.branch_id = o.branch_key
    where not (k.go_live_date is not null and o.line_date >= k.go_live_date and o.is_batch_posting = 1)
    group by o.branch_key
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

expected_fusion as (
    select f.branch_key as branch_key, count() as expected_lines
    from {{ ref('int_fusion_stock_line') }} as f
    inner join cutover as k on k.branch_id = f.branch_key
    where f.transaction_date >= k.go_live_date and f.reference_status in ('not_integration', 'not_in_oasis')
    group by f.branch_key
),

actual as (
    select branch_key, countIf(oasis_line_id is not null) as oasis_lines, countIf(oasis_line_id is null) as fusion_lines
    from {{ ref('fact_stock_movement') }}
    group by branch_key
),

compared as (
    select branch_key, sum(e_oasis) as expected_oasis, sum(a_oasis) as actual_oasis, sum(e_fusion) as expected_fusion,
           sum(a_fusion) as actual_fusion
    from (
        select branch_key, toInt64(expected_lines) as e_oasis, toInt64(0) as a_oasis, toInt64(0) as e_fusion, toInt64(0) as a_fusion from expected_oasis
        union all
        select branch_key, 0, 0, toInt64(expected_lines), 0 from expected_fusion
        union all
        select branch_key, 0, toInt64(oasis_lines), 0, toInt64(fusion_lines) from actual
    )
    group by branch_key
)

select * from compared
where expected_oasis != actual_oasis or expected_fusion != actual_fusion
```

`hnh_dwh/tests/hnh/assert_stock_line_single_source.sql`:

```sql
-- No Oasis line appears twice (as itself and through a Fusion transaction) and no Fusion transaction appears twice
-- (spec 8, S2).
select 'oasis line twice' as failure, toString(branch_key) as branch, toString(oasis_line_id) as id, count() as rows
from {{ ref('fact_stock_movement') }}
where oasis_line_id is not null
group by branch_key, oasis_line_id
having count() > 1

union all

select 'fusion transaction twice', toString(any(branch_key)), toString(fusion_transaction_id), count()
from {{ ref('fact_stock_movement') }}
where fusion_transaction_id is not null
group by fusion_transaction_id
having count() > 1
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_stock_movement_switches_at_go_live`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the fact**

`fact_stock_movement.sql`:

```sql
{{ config(order_by='(branch_key, date_key, movement_key)') }}

-- One row per stock line (spec 6.1, S1-S3). A line with an Oasis line id is that line: before the branch's inventory
-- go-live (or with no go-live) it is the Oasis line; from the go-live it is the Fusion transaction(s) that reference
-- it, else the Oasis line flagged is_fusion_gap. Fusion transactions without an Oasis line (receipts, counts, misc,
-- opening balances, and references to lines Oasis does not hold) are lines of their own from the go-live. Left out
-- (visible in rec_stock_interface_daily): Fusion rows before the go-live, integration rows with no reference or whose
-- line is out of scope, and from the go-live Oasis batch postings, which echo Fusion transactions (plan refinement).
-- The date of a line with an Oasis line id is the Oasis date, so a line keeps its day when it moves to Fusion.
with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }}
    where inventory_go_live_date is not null
),

oasis as (
    select o.branch_key as branch_key, o.oasis_line_id as oasis_line_id, o.oasis_doc_no as oasis_doc_no,
           o.line_date as line_date, o.movement_type as movement_type, o.is_batch_posting as is_batch_posting,
           o.store_id as store_id, o.transfer_store_id as transfer_store_id, o.product_code as product_code,
           o.item_key as item_key, o.primary_quantity as primary_quantity, o.cost_amount as cost_amount,
           o.unit_cost as unit_cost, o.lot_number as lot_number, o.expiry_date as expiry_date,
           k.go_live_date as go_live_date,
           toUInt8(k.go_live_date is not null and o.line_date >= k.go_live_date) as is_live
    from {{ ref('int_oasis_stock_line') }} as o
    left join cutover as k on k.branch_id = o.branch_key
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

fusion as (
    select f.*, k.go_live_date as go_live_date
    from {{ ref('int_fusion_stock_line') }} as f
    left join cutover as k on k.branch_id = f.branch_key
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

fusion_by_line as (
    -- the Fusion transactions that reference one Oasis line (a line posted twice and corrected nets to one)
    select branch_key as fl_branch_key, assumeNotNull(oasis_line_id) as fl_oasis_line_id,
           min(fusion_transaction_id) as fl_transaction_id, toUInt32(count()) as fl_transaction_count,
           min(transaction_date) as fl_transaction_date, sum(primary_quantity) as fl_quantity,
           sum(primary_quantity * ifNull(valuation_unit_cost, 0)) as fl_valuation_cost,
           countIf(valuation_unit_cost is null) as fl_missing_cost,
           argMin(organization_id, fusion_transaction_id) as fl_organization_id,
           argMin(subinventory_code, fusion_transaction_id) as fl_subinventory_code,
           argMin(transfer_organization_id, fusion_transaction_id) as fl_transfer_organization_id,
           argMin(transfer_subinventory, fusion_transaction_id) as fl_transfer_subinventory,
           argMin(inventory_item_id, fusion_transaction_id) as fl_inventory_item_id,
           min(lot_number) as fl_lot_number, min(expiry_date) as fl_expiry_date
    from fusion
    where reference_status = 'oasis_line'
    group by branch_key, oasis_line_id
),

oasis_identity as (
    select o.*, fl.*, toUInt8(fl.fl_oasis_line_id is not null) as has_fusion
    from oasis as o
    left join fusion_by_line as fl on fl.fl_branch_key = o.branch_key and fl.fl_oasis_line_id = o.oasis_line_id
    where not (o.is_live = 1 and o.is_batch_posting = 1)
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
),

identity_rows as (
    select
        {{ hnh_surrogate_key(["'oasis-line'", 'branch_key', 'oasis_line_id']) }}  as movement_key,
        branch_key,
        line_date,
        if(is_live = 1 and has_fusion = 1, 'fusion', 'oasis')                     as source_system,
        toUInt8(1)                                                                as is_in_oasis,
        has_fusion                                                                as is_in_fusion,
        toUInt8(is_live = 1 and has_fusion = 0)                                   as is_fusion_gap,
        toUInt8(0)                                                                as is_opening_balance,
        movement_type,
        if(source_system = 'fusion',
           {{ hnh_surrogate_key(["'fusion'", 'fl_organization_id', "ifNull(fl_subinventory_code, '*')"]) }},
           {{ hnh_surrogate_key(["'oasis'", 'branch_key', 'store_id']) }})         as store_key_raw,
        if(source_system = 'fusion',
           if(fl_transfer_organization_id is null and fl_transfer_subinventory is null, toInt64(-1),
              {{ hnh_surrogate_key(["'fusion'", 'ifNull(fl_transfer_organization_id, fl_organization_id)', "ifNull(fl_transfer_subinventory, '*')"]) }}),
           {{ hnh_surrogate_key(["'oasis'", 'branch_key', 'transfer_store_id']) }}) as transfer_store_key_raw,
        if(source_system = 'fusion', {{ hnh_surrogate_key(['fl_inventory_item_id']) }}, item_key) as item_key_raw,
        toNullable(oasis_line_id)                                                 as oasis_line_id,
        oasis_doc_no,
        product_code                                                              as oasis_product_code,
        if(has_fusion = 1, fl_transaction_id, cast(null as Nullable(Int64))) as fusion_transaction_id,
        if(has_fusion = 1, assumeNotNull(fl_transaction_count), toUInt32(0))                     as fusion_transaction_count,
        if(has_fusion = 1, fl_transaction_date, cast(null as Nullable(Date))) as fusion_transaction_date,
        if(source_system = 'fusion', ifNull(fl_quantity, 0), primary_quantity)    as movement_quantity,
        multiIf(source_system = 'oasis', if(cost_amount != 0, 'oasis_line', 'none'),
                fl_missing_cost = 0, 'fusion_valuation', unit_cost != 0, 'oasis_line', 'none') as cost_source,
        multiIf(source_system = 'oasis', cost_amount, fl_missing_cost = 0, ifNull(fl_valuation_cost, 0),
                unit_cost * ifNull(fl_quantity, 0))                               as movement_cost,
        if(source_system = 'fusion', coalesce(fl_lot_number, lot_number), lot_number) as lot_number,
        if(source_system = 'fusion', coalesce(fl_expiry_date, expiry_date), expiry_date) as expiry_date
    from oasis_identity
),

fusion_only_rows as (
    select
        {{ hnh_surrogate_key(["'fusion-transaction'", 'fusion_transaction_id']) }} as movement_key,
        branch_key,
        toDate32(transaction_date)                                                as line_date,
        'fusion'                                                                  as source_system,
        toUInt8(0)                                                                as is_in_oasis,
        toUInt8(1)                                                                as is_in_fusion,
        toUInt8(0)                                                                as is_fusion_gap,
        is_opening_balance,
        fusion_movement_type                                                      as movement_type,
        {{ hnh_surrogate_key(["'fusion'", 'organization_id', "ifNull(subinventory_code, '*')"]) }} as store_key_raw,
        if(transfer_organization_id is null and transfer_subinventory is null, toInt64(-1),
           {{ hnh_surrogate_key(["'fusion'", 'ifNull(transfer_organization_id, organization_id)', "ifNull(transfer_subinventory, '*')"]) }}) as transfer_store_key_raw,
        {{ hnh_surrogate_key(['inventory_item_id']) }}                            as item_key_raw,
        cast(null as Nullable(Int64))                                             as oasis_line_id,
        cast(null as Nullable(String))                                            as oasis_doc_no,
        cast(null as Nullable(String))                                            as oasis_product_code,
        toNullable(fusion_transaction_id)                                         as fusion_transaction_id,
        toUInt32(1)                                                               as fusion_transaction_count,
        toNullable(transaction_date)                                              as fusion_transaction_date,
        primary_quantity                                                          as movement_quantity,
        if(valuation_unit_cost is not null, 'fusion_valuation', 'none')           as cost_source,
        primary_quantity * ifNull(valuation_unit_cost, 0)                         as movement_cost,
        lot_number,
        expiry_date
    from fusion
    where go_live_date is not null and transaction_date >= go_live_date
      and reference_status in ('not_integration', 'not_in_oasis')
),

lines as (
    select * from identity_rows
    union all
    select * from fusion_only_rows
)

select
    l.movement_key                                                  as movement_key,
    l.branch_key                                                    as branch_key,
    {{ hnh_date_key('l.line_date') }}                               as date_key,
    ifNull(s.store_key, toInt64(-1))                                as store_key,
    ifNull(ts.store_key, toInt64(-1))                               as transfer_store_key,
    ifNull(i.item_key, toInt64(-1))                                 as item_key,
    {{ hnh_surrogate_key(['l.movement_type']) }}                    as movement_type_key,
    l.movement_type                                                 as movement_type,
    l.source_system                                                 as source_system,
    l.is_in_oasis                                                   as is_in_oasis,
    l.is_in_fusion                                                  as is_in_fusion,
    l.is_fusion_gap                                                 as is_fusion_gap,
    l.is_opening_balance                                            as is_opening_balance,
    {{ hnh_is_consumption('l.movement_type') }}                     as is_consumption,
    l.oasis_line_id                                                 as oasis_line_id,
    l.oasis_doc_no                                                  as oasis_doc_no,
    l.oasis_product_code                                            as oasis_product_code,
    l.fusion_transaction_id                                         as fusion_transaction_id,
    l.fusion_transaction_count                                      as fusion_transaction_count,
    {{ hnh_date_key_in_range('l.fusion_transaction_date') }}        as fusion_transaction_date_key,
    l.movement_quantity                                             as primary_quantity,
    if(l.movement_quantity != 0, abs(l.movement_cost / l.movement_quantity), 0) as unit_cost,
    l.movement_cost                                                 as cost_amount,
    l.cost_source                                                   as cost_source,
    if(is_consumption = 1, -l.movement_quantity, 0)                 as consumption_quantity,
    if(is_consumption = 1, -l.movement_cost, 0)                     as consumption_cost,
    l.lot_number                                                    as lot_number,
    l.expiry_date                                                   as expiry_date,
    now()                                                           as _loaded_at
from lines as l
left join (select store_key from {{ ref('dim_store') }}) as s on s.store_key = l.store_key_raw
left join (select store_key from {{ ref('dim_store') }}) as ts on ts.store_key = l.transfer_store_key_raw
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = l.item_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test, the build and the conservation tests**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_stock_movement assert_stock_movement_conservation assert_stock_line_single_source`
Expected: unit test PASS; model built (3–6 minutes); all tests PASS (the two assertions are error severity).

Check (measured) with `select branch_key, source_system, is_fusion_gap, count() from gold.fact_stock_movement group by 1, 2, 3 order by 1, 2, 3`:

| Branch | oasis (not gap) | oasis gap fill | fusion |
|---|---|---|---|
| 1 | 8,376,645 | – | – |
| 2 | 7,116,841 | 31,382 | 80,654 |
| 3 | 5,212,857 | 127,138 | 188,653 |
| 4 | 5,067,455 | 64,020 | 164,051 |
| 5 | 4,506,388 | 25,056 | 73,958 |
| 6 | 701,689 | 161,529 | 128,202 |
| 7 | 38,319 | 61,977 | 63,829 |
| 8 | – | 9,744 | 23,308 |

Total 32,223,695 rows: 32,158,972 with an Oasis line id (= 32,181,475 in-scope Oasis lines − 22,503 batch postings from the go-live) and 64,723 Fusion-only lines. No row has item -1. Record the table, `select countIf(is_opening_balance = 1), round(sum(consumption_cost) / 1e6, 2) from gold.fact_stock_movement` and the peak memory (query as in Task 6, filtered on `fact_stock_movement`).

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/supply/ hnh_dwh/tests/hnh/assert_stock_movement_conservation.sql hnh_dwh/tests/hnh/assert_stock_line_single_source.sql
git commit -m "Add the stock movement fact with the per-branch Fusion cutover and Oasis gap fill" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Patient consumption and its charge reconciliation

**Files:**
- Create: `hnh_dwh/models/hnh/marts/supply/fact_patient_consumption.sql`, `hnh_dwh/models/hnh/marts/reconciliation/rec_consumption_charge_monthly.sql`, `hnh_dwh/tests/hnh/assert_patient_consumption_matches_movements.sql`
- Modify: `_supply_marts__models.yml`, `_supply_marts_unit_tests.yml`, `hnh_dwh/models/hnh/marts/reconciliation/_reconciliation__models.yml`

**Interfaces:**
- Consumes: `fact_stock_movement`, `stg_oasis__charges` (`branch_id`, `invoice_doc_no`, `delivery_line`), `stg_oasis__delivery_lines` (`branch_id`, `delivery_line`, `product_code`), `fact_charge_line` (`charge_line_key`, `branch_key`, `delivery_line`, `delivery_date_key`, `revenue_amount`, `is_medication`, `encounter_key`, `episode_key`, `patient_key`, `staff_key`, `billed_payer_key`, `care_type_key` Int8, `service_key`, `department_key`).
- Produces:
  - `fact_patient_consumption(movement_key, branch_key, date_key, store_key, item_key, movement_type_key, movement_type, encounter_key, episode_key, patient_key, treating_staff_key, billed_payer_key, care_type_key Int8, service_key, department_key, charge_line_key, is_linked_to_charge, primary_quantity, cost_amount, consumption_quantity, consumption_cost, revenue_amount, source_system, is_in_oasis, is_in_fusion, is_fusion_gap, _loaded_at)`
  - `rec_consumption_charge_monthly(branch_key, month_start, patient_consumption_cost, linked_consumption_cost, linked_revenue, linked_margin, sale_lines_without_charge, cost_without_charge, medication_charges_without_cost, revenue_without_cost)`

- [ ] **Step 1: Write the failing unit test, the YAML and the assertion**

Append to `_supply_marts_unit_tests.yml`:

```yaml
  - name: fact_patient_consumption_counts_revenue_once
    description: >
      Lines 11 and 12 dispense P1 twice on invoice INV1, whose P1 delivery lines DL1 (charges 1001 of 30 and the co-pay
      1002 of 10) and DL2 (charge 1003 of 30) link to both lines: each charge line goes to line 11 only (revenue 70,
      line 12 none). Return line 13 links but carries no revenue. Line 14 (INV2) has no charge. Fusion-sourced line 15
      (INV3) links through the superseded INV3 charge row of DL3 to its live charge 1004 (50) on another invoice. A
      department issue is not a patient line.
    model: fact_patient_consumption
    given:
      - input: ref('fact_stock_movement')
        format: sql
        rows: |
          select toInt64(m) as movement_key, toUInt8(3) as branch_key, toInt32(20260905) as date_key, toInt64(1) as store_key, toInt64(2) as item_key, toInt64(3) as movement_type_key, mt as movement_type, toNullable(toInt64(l)) as oasis_line_id, toNullable(inv) as oasis_doc_no, toNullable(p) as oasis_product_code, toFloat64(q) as primary_quantity, toFloat64(c) as cost_amount, toFloat64(-q) as consumption_quantity, toFloat64(-c) as consumption_cost, src as source_system, toUInt8(1) as is_in_oasis, toUInt8(src = 'fusion') as is_in_fusion, toUInt8(0) as is_fusion_gap
          from values('m UInt32, mt String, l UInt32, inv String, p String, q Float64, c Float64, src String',
              (1, 'Patient sale', 11, 'INV1', 'P1', -1, -5, 'oasis'), (2, 'Patient sale', 12, 'INV1', 'P1', -1, -5, 'oasis'),
              (3, 'Patient return', 13, 'INV1', 'P1', 1, 5, 'oasis'), (4, 'Patient sale', 14, 'INV2', 'P2', -1, -4, 'oasis'),
              (5, 'Patient sale', 15, 'INV3', 'P3', -2, -6, 'fusion'), (6, 'Department issue', 16, 'ISS6', 'P1', -1, -5, 'oasis'))
      - input: ref('stg_oasis__charges')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toNullable(inv) as invoice_doc_no, toNullable(toInt64(dl)) as delivery_line
          from values('inv String, dl UInt32', ('INV1', 1), ('INV1', 1), ('INV1', 2), ('INV3', 3), ('INV4', 3))
      - input: ref('stg_oasis__delivery_lines')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toInt64(dl) as delivery_line, toNullable(p) as product_code
          from values('dl UInt32, p String', (1, 'P1'), (2, 'P1'), (3, 'P3'))
      - input: ref('fact_charge_line')
        format: sql
        rows: |
          select toInt64(k) as charge_line_key, toUInt8(3) as branch_key, toNullable(toInt64(dl)) as delivery_line, toFloat64(r) as revenue_amount,
                 toInt64(e) as encounter_key, toInt64(-1) as episode_key, toInt64(-1) as patient_key, toInt64(-1) as staff_key,
                 toInt64(-1) as billed_payer_key, toInt8(1) as care_type_key, toInt64(-1) as service_key, toInt64(-1) as department_key
          from values('k UInt32, dl UInt32, r Float64, e UInt32', (1001, 1, 30, 701), (1002, 1, 10, 701), (1003, 2, 30, 702), (1004, 3, 50, 703))
    expect:
      rows:
        - {movement_key: 1, is_linked_to_charge: 1, revenue_amount: 70, encounter_key: 701, charge_line_key: 1001}
        - {movement_key: 2, is_linked_to_charge: 1, revenue_amount: 0, encounter_key: 701, charge_line_key: 1001}
        - {movement_key: 3, is_linked_to_charge: 1, revenue_amount: 0, encounter_key: 701, charge_line_key: 1001}
        - {movement_key: 4, is_linked_to_charge: 0, revenue_amount: 0, encounter_key: -1, charge_line_key: -1}
        - {movement_key: 5, is_linked_to_charge: 1, revenue_amount: 50, encounter_key: 703, charge_line_key: 1004}
```

Append to `_supply_marts__models.yml`:

```yaml
  - name: fact_patient_consumption
    columns:
      - name: movement_key
        tests:
          - unique
          - not_null
          - relationships: {to: ref('fact_stock_movement'), field: movement_key}
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: store_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: item_key
        tests:
          - relationships: {to: ref('hnh_dim_item'), field: item_key}
      - name: movement_type_key
        tests:
          - relationships: {to: ref('dim_movement_type'), field: movement_type_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: treating_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: billed_payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: service_key
        tests:
          - relationships: {to: ref('dim_service'), field: service_key}
      - name: department_key
        tests:
          - relationships: {to: ref('hnh_dim_department'), field: department_key}
      - name: encounter_key
        tests:
          - relationships:
              to: ref('fact_encounter')
              field: encounter_key
              config: {severity: warn, where: "encounter_key != -1"}
```

Append to `_reconciliation__models.yml`:

```yaml
  - name: rec_consumption_charge_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
```

`hnh_dwh/tests/hnh/assert_patient_consumption_matches_movements.sql`:

```sql
-- The patient-consumption row count equals the patient sale and return rows of fact_stock_movement (spec 8).
select m.n as movement_rows, c.n as consumption_rows
from (select count() as n from {{ ref('fact_stock_movement') }} where movement_type in ('Patient sale', 'Patient return')) as m
cross join (select count() as n from {{ ref('fact_patient_consumption') }}) as c
where m.n != c.n
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_patient_consumption_counts_revenue_once`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the fact and the reconciliation**

`fact_patient_consumption.sql`:

```sql
{{ config(order_by='(branch_key, date_key, movement_key)') }}

-- One row per patient-sale or patient-return line of fact_stock_movement (spec 6.2). The line links to the charge
-- through its Oasis invoice line: docl.doc_no = delivery_charge.invoice_no and the line's product = the delivery line's
-- product (spec F9). A superseded charge row still names its delivery line, so the link goes invoice + product ->
-- delivery line (any charge row) -> the live charge lines of that delivery line in fact_charge_line (plan refinement).
-- Each charge line's revenue is counted once: on the linked patient-sale line with the lowest Oasis line id. Returns
-- carry the charge's keys but no revenue.
with sales as (
    select movement_key, branch_key, date_key, store_key, item_key, movement_type_key, movement_type, oasis_line_id,
           oasis_doc_no, oasis_product_code, primary_quantity, cost_amount, consumption_quantity, consumption_cost,
           source_system, is_in_oasis, is_in_fusion, is_fusion_gap
    from {{ ref('fact_stock_movement') }}
    where movement_type in ('Patient sale', 'Patient return')
),

invoice_lines as (
    select c.branch_id as branch_id, assumeNotNull(c.invoice_doc_no) as invoice_doc_no,
           assumeNotNull(d.product_code) as product_code, assumeNotNull(c.delivery_line) as delivery_line
    from {{ ref('stg_oasis__charges') }} as c
    inner join (select branch_id, delivery_line, product_code from {{ ref('stg_oasis__delivery_lines') }}
                where product_code is not null) as d
        on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
    where c.invoice_doc_no is not null and c.delivery_line is not null
      and (c.branch_id, c.invoice_doc_no) in (select branch_key, assumeNotNull(oasis_doc_no) from sales where oasis_doc_no is not null)
    group by c.branch_id, c.invoice_doc_no, d.product_code, c.delivery_line
),

links as (
    select s.movement_key as movement_key, assumeNotNull(s.oasis_line_id) as link_line_id, s.movement_type as link_movement_type,
           ch.charge_line_key as charge_line_key, ch.revenue_amount as charge_revenue,
           ch.encounter_key as charge_encounter_key, ch.episode_key as charge_episode_key, ch.patient_key as charge_patient_key,
           ch.staff_key as charge_staff_key, ch.billed_payer_key as charge_payer_key, ch.care_type_key as charge_care_type_key,
           ch.service_key as charge_service_key, ch.department_key as charge_department_key
    from sales as s
    inner join invoice_lines as il
        on il.branch_id = s.branch_key and il.invoice_doc_no = s.oasis_doc_no and il.product_code = s.oasis_product_code
    inner join (select charge_line_key, branch_key, assumeNotNull(delivery_line) as delivery_line, revenue_amount, encounter_key,
                       episode_key, patient_key, staff_key, billed_payer_key, care_type_key, service_key, department_key
                from {{ ref('fact_charge_line') }} where delivery_line is not null) as ch
        on ch.branch_key = il.branch_id and ch.delivery_line = il.delivery_line
),

revenue_owner as (
    select charge_line_key, argMin(movement_key, link_line_id) as owner_movement_key, any(charge_revenue) as owner_revenue
    from links
    where link_movement_type = 'Patient sale'
    group by charge_line_key
),

revenue as (
    select owner_movement_key, sum(owner_revenue) as line_revenue
    from revenue_owner
    group by owner_movement_key
),

charge_keys as (
    -- the keys of the linked charge line with the lowest key
    select movement_key as key_movement_key,
           argMin(charge_encounter_key, charge_line_key) as k_encounter_key, argMin(charge_episode_key, charge_line_key) as k_episode_key,
           argMin(charge_patient_key, charge_line_key) as k_patient_key, argMin(charge_staff_key, charge_line_key) as k_staff_key,
           argMin(charge_payer_key, charge_line_key) as k_payer_key, argMin(charge_care_type_key, charge_line_key) as k_care_type_key,
           argMin(charge_service_key, charge_line_key) as k_service_key, argMin(charge_department_key, charge_line_key) as k_department_key,
           min(charge_line_key) as k_charge_line_key
    from links
    group by movement_key
)

select
    s.movement_key                                      as movement_key,
    s.branch_key                                        as branch_key,
    s.date_key                                          as date_key,
    s.store_key                                         as store_key,
    s.item_key                                          as item_key,
    s.movement_type_key                                 as movement_type_key,
    s.movement_type                                     as movement_type,
    ifNull(k.k_encounter_key, toInt64(-1))              as encounter_key,
    ifNull(k.k_episode_key, toInt64(-1))                as episode_key,
    ifNull(k.k_patient_key, toInt64(-1))                as patient_key,
    ifNull(k.k_staff_key, toInt64(-1))                  as treating_staff_key,
    ifNull(k.k_payer_key, toInt64(-1))                  as billed_payer_key,
    ifNull(k.k_care_type_key, toInt8(-1))               as care_type_key,
    ifNull(k.k_service_key, toInt64(-1))                as service_key,
    ifNull(k.k_department_key, toInt64(-1))             as department_key,
    ifNull(k.k_charge_line_key, toInt64(-1))            as charge_line_key,
    toUInt8(k.key_movement_key is not null)             as is_linked_to_charge,
    s.primary_quantity                                  as primary_quantity,
    s.cost_amount                                       as cost_amount,
    s.consumption_quantity                              as consumption_quantity,
    s.consumption_cost                                  as consumption_cost,
    ifNull(r.line_revenue, 0)                           as revenue_amount,
    s.source_system                                     as source_system,
    s.is_in_oasis                                       as is_in_oasis,
    s.is_in_fusion                                      as is_in_fusion,
    s.is_fusion_gap                                     as is_fusion_gap,
    now()                                               as _loaded_at
from sales as s
left join charge_keys as k on k.key_movement_key = s.movement_key
left join revenue as r on r.owner_movement_key = s.movement_key
{{ hnh_settings() }}
```

`rec_consumption_charge_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_start)') }}

-- Patient consumption cost against the revenue of the same charge lines, per branch and month (spec 8), with the sale
-- lines that have no charge and the medication charges that no stock line links to.
with consumption as (
    select branch_key, toStartOfMonth(toDate(toString(date_key))) as month_start,
           sum(consumption_cost) as patient_consumption_cost,
           sumIf(consumption_cost, is_linked_to_charge = 1) as linked_consumption_cost,
           sum(revenue_amount) as linked_revenue,
           countIf(movement_type = 'Patient sale' and is_linked_to_charge = 0) as sale_lines_without_charge,
           sumIf(consumption_cost, movement_type = 'Patient sale' and is_linked_to_charge = 0) as cost_without_charge
    from {{ ref('fact_patient_consumption') }}
    group by branch_key, month_start
),

linked_delivery_lines as (
    -- delivery lines whose charge a patient-consumption line links to
    select branch_key, delivery_line
    from {{ ref('fact_charge_line') }}
    where charge_line_key in (select charge_line_key from {{ ref('fact_patient_consumption') }} where charge_line_key != -1)
),

unlinked_charges as (
    select c.branch_key as branch_key, toStartOfMonth(toDate(toString(c.delivery_date_key))) as month_start,
           count() as medication_charges_without_cost, sum(c.revenue_amount) as revenue_without_cost
    from {{ ref('fact_charge_line') }} as c
    where c.is_medication = 1 and c.revenue_amount != 0
      and (c.branch_key, c.delivery_line) not in (select branch_key, delivery_line from linked_delivery_lines)
    group by branch_key, month_start
),

spine as (
    select branch_key, month_start from consumption
    union distinct
    select branch_key, month_start from unlinked_charges
)

select
    s.branch_key                                        as branch_key,
    s.month_start                                       as month_start,
    ifNull(c.patient_consumption_cost, 0)               as patient_consumption_cost,
    ifNull(c.linked_consumption_cost, 0)                as linked_consumption_cost,
    ifNull(c.linked_revenue, 0)                         as linked_revenue,
    ifNull(c.linked_revenue, 0) - ifNull(c.linked_consumption_cost, 0) as linked_margin,
    ifNull(c.sale_lines_without_charge, 0)              as sale_lines_without_charge,
    ifNull(c.cost_without_charge, 0)                    as cost_without_charge,
    ifNull(u.medication_charges_without_cost, 0)        as medication_charges_without_cost,
    ifNull(u.revenue_without_cost, 0)                   as revenue_without_cost
from spine as s
left join consumption as c on c.branch_key = s.branch_key and c.month_start = s.month_start
left join unlinked_charges as u on u.branch_key = s.branch_key and u.month_start = s.month_start
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_patient_consumption rec_consumption_charge_monthly assert_patient_consumption_matches_movements`
Expected: unit test PASS; models built (`fact_patient_consumption` 3–8 minutes: it joins about 26.5M patient lines to the charges of their invoices); tests PASS (the encounter relationship may WARN). Expected link rate: about 99% of patient-sale rows `is_linked_to_charge = 1` (99.4% on Jazan 1–7 Sep 2026). Record `select branch_key, toYear(toDate(toString(date_key))) as y, countIf(movement_type = 'Patient sale') as sales, round(avgIf(is_linked_to_charge, movement_type = 'Patient sale'), 4) as link_rate, round(sum(consumption_cost) / 1e6, 2) as cost_m, round(sum(revenue_amount) / 1e6, 2) as revenue_m from gold.fact_patient_consumption group by 1, 2 order by 1, 2` and the peak memory. A branch-year link rate below 0.95 is a finding to report, not a failure.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/ hnh_dwh/tests/hnh/assert_patient_consumption_matches_movements.sql
git commit -m "Add patient consumption linked to the charge and its monthly reconciliation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Month-end stock

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/supply/int_stock_month_end.sql`, `hnh_dwh/models/hnh/marts/supply/fact_stock_monthly.sql`
- Modify: `_supply__models.yml`, `_supply_unit_tests.yml`, `_supply_marts__models.yml`

**Interfaces:**
- Consumes: `stg_ref__scm_cutover`, `int_item_crosswalk`, `stg_oasis__products`, `stg_ref__stock_snapshot`, `stg_oasis__stock_batch_snapshots`, `fact_stock_movement`, `stg_fusion__inventory_valuation`, `int_inventory_org_branch`, `stg_fusion__inventory_onhand`, `stg_fusion__lots`, `dim_store` (`store_key`, `is_expiry_store`), `hnh_dim_item`; macro `hnh_stock_last_month_end`.
- Produces:
  - `int_stock_month_end(branch_key UInt8, month_end Date, snapshot_date Date, store_key, item_key, oasis_product_code, quantity, stock_value, stock_source, source_system, has_expired_lot)`; `stock_source` ∈ `snapshot`, `derived`, `oasis_batch`, `fusion_valuation`
  - `fact_stock_monthly(stock_monthly_key, branch_key, month_date_key, month_end, store_key, item_key, quantity, stock_value, stock_source, source_system, is_expiry_store, is_closed_month, has_expired_lot, consumption_quantity, consumption_cost, _loaded_at)`

- [ ] **Step 1: Write the failing unit test and the YAML**

Append to `_supply_unit_tests.yml`:

```yaml
  - name: int_stock_month_end_switches_source
    description: >
      Khamis (go-live 2026-09-05), store 44, product P1 = Fusion item 500 (1 base unit per primary unit, average cost
      2). May: old snapshot, the last day (31st, 100) wins over the 30th. June and July: derived from the first batch
      month-end (31 August, 70) by reversing the later Oasis movements (August -5, July -15): July 75, June 90; the
      June movement and a September movement after the anchor do not count, nor does a Fusion-sourced row. August:
      Oasis batch, 60 + 10 in an expired batch = 70. September: Fusion valuation, 40 - 10 = 30 (value 150; an October
      layer is after the month-end), split by the 30 September on-hand into IPH 20 and OPH 10 (OPH in an expired lot).
    model: int_stock_month_end
    overrides:
      vars:
        hnh_stock_month_end_last: "2026-09-30"
    given:
      - input: ref('stg_ref__scm_cutover')
        format: sql
        rows: |
          select toUInt8(2) as branch_id, toNullable(toDate('2026-09-05')) as inventory_go_live_date
      - input: ref('int_item_crosswalk')
        format: sql
        rows: |
          select toUInt8(2) as branch_key, 'P1' as product_code, toInt64(500) as inventory_item_id, toFloat64(1) as units_per_primary
      - input: ref('stg_oasis__products')
        format: sql
        rows: |
          select toUInt8(2) as branch_id, 'P1' as product_code, toFloat64(2) as average_cost
      - input: ref('stg_ref__stock_snapshot')
        format: sql
        rows: |
          select toUInt8(2) as branch_id, toInt64(44) as store_id, 'P1' as product_code, toDate(d) as snapshot_date, toFloat64(q) as qty_on_hand, toFloat64(2) as average_cost
          from values('d String, q Float64', ('2026-05-30', 999), ('2026-05-31', 100))
      - input: ref('stg_oasis__stock_batch_snapshots')
        format: sql
        rows: |
          select toUInt8(2) as branch_id, toDate32(d) as snapshot_date, toInt64(44) as store_id, 'P1' as product_code, toNullable(toDate32(e)) as expiry_date, toFloat64(q) as quantity
          from values('d String, e String, q Float64', ('2026-08-30', '2027-01-01', 72), ('2026-08-31', '2027-01-01', 60), ('2026-08-31', '2026-08-01', 10))
      - input: ref('fact_stock_movement')
        format: sql
        rows: |
          select toUInt8(2) as branch_key, toInt32(dk) as date_key, toInt64(bitShiftRight(cityHash64(concat(toString('oasis'), '|', toString(toUInt8(2)), '|', toString(toInt64(44)), '|')), 1)) as store_key, toInt64(bitShiftRight(cityHash64(concat(toString(toInt64(500)), '|')), 1)) as item_key,
                 toNullable('P1') as oasis_product_code, toFloat64(q) as primary_quantity, src as source_system
          from values('dk UInt32, q Float64, src String', (20260615, -10, 'oasis'), (20260710, -15, 'oasis'), (20260810, -5, 'oasis'), (20260901, -3, 'oasis'), (20260720, -100, 'fusion'))
      - input: ref('stg_fusion__inventory_valuation')
        format: sql
        rows: |
          select toNullable(toInt64(2004)) as inventory_org_id, toNullable(toInt64(500)) as inventory_item_id, toDate(d) as cost_date, toFloat64(q) as quantity, toFloat64(5) as unit_cost, toNullable('Y') as posted_flag
          from values('d String, q Float64', ('2026-08-30', 40), ('2026-09-10', -10), ('2026-10-02', -5))
      - input: ref('int_inventory_org_branch')
        format: sql
        rows: |
          select toInt64(2004) as organization_id, toUInt8(2) as branch_key
      - input: ref('stg_fusion__inventory_onhand')
        format: sql
        rows: |
          select toNullable(toDate('2026-09-30')) as snapshot_date, toNullable(toInt64(2004)) as organization_id, toNullable(toInt64(500)) as inventory_item_id,
                 toNullable(s) as subinventory_code, toNullable(l) as lot_number, toFloat64(q) as primary_quantity
          from values('s String, l String, q Float64', ('IPH', 'A', 20), ('OPH', 'B', 10))
      - input: ref('stg_fusion__lots')
        format: sql
        rows: |
          select toInt64(500) as inventory_item_id, toInt64(2004) as organization_id, l as lot_number, toNullable(toDate32(e)) as expiration_date
          from values('l String, e String', ('A', '2027-06-30'), ('B', '2026-09-15'))
    expect:
      rows:
        - {month_end: 2026-05-31, stock_source: 'snapshot', source_system: 'oasis', quantity: 100, stock_value: 200, has_expired_lot: 0}
        - {month_end: 2026-06-30, stock_source: 'derived', source_system: 'oasis', quantity: 90, stock_value: 180, has_expired_lot: 0}
        - {month_end: 2026-07-31, stock_source: 'derived', source_system: 'oasis', quantity: 75, stock_value: 150, has_expired_lot: 0}
        - {month_end: 2026-08-31, stock_source: 'oasis_batch', source_system: 'oasis', quantity: 70, stock_value: 140, has_expired_lot: 1}
        - {month_end: 2026-09-30, stock_source: 'fusion_valuation', source_system: 'fusion', quantity: 20, stock_value: 100, has_expired_lot: 0}
        - {month_end: 2026-09-30, stock_source: 'fusion_valuation', source_system: 'fusion', quantity: 10, stock_value: 50, has_expired_lot: 1}
```

The fixture's `store_key` and `item_key` are the inline forms of `hnh_surrogate_key(["'oasis'", 'branch_id', 'store_id'])` (store 44 of branch 2) and `hnh_surrogate_key(['inventory_item_id'])` (item 500), so the movements roll back the same store and item as the batch snapshot.

Append to `_supply__models.yml`:

```yaml
  - name: int_stock_month_end
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_end, store_key, item_key]
    columns:
      - name: stock_source
        tests:
          - accepted_values:
              values: ['snapshot', 'derived', 'oasis_batch', 'fusion_valuation']
```

Append to `_supply_marts__models.yml`:

```yaml
  - name: fact_stock_monthly
    columns:
      - name: stock_monthly_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: month_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: store_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: item_key
        tests:
          - relationships: {to: ref('hnh_dim_item'), field: item_key}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select int_stock_month_end_switches_source`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the two models**

`int_stock_month_end.sql`:

```sql
{{ config(order_by='(branch_key, month_end, store_key, item_key)') }}

-- Month-end stock per branch, store and item (spec 6.4, S5). The source of a branch's month-end is the first that applies:
--   1 fusion_valuation: the branch is live on Fusion inventory (go-live on or before the month-end);
--   2 snapshot: an old-warehouse snapshot (bal_product_base) exists in the month (its last snapshot day);
--   3 oasis_batch: an Oasis batch snapshot exists in the month (its last snapshot day);
--   4 derived: a month after the branch's last old snapshot and before its first Oasis batch month, rolled back from
--     that first batch month-end by the branch's Oasis movements after the month-end. Nothing before the first snapshot.
-- Oasis quantities are converted to the item's primary unit. Values: snapshot qty x its average cost; batch and derived
-- qty x the product's current Oasis average cost; Fusion the cumulative valuation layers per organisation and item, split
-- across subinventories by the Fusion on-hand snapshot of the same month where one exists, else at organisation level '*'.
{% set last_month_end = hnh_stock_last_month_end() %}

with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }}
    where inventory_go_live_date is not null
),

crosswalk as (
    select branch_key, product_code, inventory_item_id, units_per_primary from {{ ref('int_item_crosswalk') }}
),

average_cost as (
    select branch_id, product_code, ifNotFinite(avgIf(average_cost, average_cost > 0), 0) as product_average_cost
    from {{ ref('stg_oasis__products') }}
    group by branch_id, product_code
),

snapshot_days as (
    select branch_id, toDate(toLastDayOfMonth(snapshot_date)) as month_end, max(snapshot_date) as snapshot_day
    from {{ ref('stg_ref__stock_snapshot') }}
    where snapshot_date <= {{ last_month_end }}
    group by branch_id, month_end
),

batch_days as (
    select branch_id, toDate(toLastDayOfMonth(snapshot_date)) as month_end, max(snapshot_date) as snapshot_day
    from {{ ref('stg_oasis__stock_batch_snapshots') }}
    where snapshot_date <= {{ last_month_end }}
    group by branch_id, month_end
),

fusion_month_ends as (
    select c.branch_id as branch_id,
           toDate(toLastDayOfMonth(addMonths(toStartOfMonth(c.go_live_date), toInt32(n.number)))) as month_end
    from cutover as c
    cross join numbers(240) as n
    where month_end <= {{ last_month_end }}
),

derived_month_ends as (
    select s.branch_id as branch_id,
           toDate(toLastDayOfMonth(addMonths(toStartOfMonth(s.last_snapshot_month_end), toInt32(n.number) + 1))) as month_end
    from (select branch_id, max(month_end) as last_snapshot_month_end from snapshot_days group by branch_id) as s
    inner join (select branch_id, min(month_end) as first_batch_month_end from batch_days group by branch_id) as b
        on b.branch_id = s.branch_id
    cross join numbers(240) as n
    where month_end < b.first_batch_month_end
),

candidates as (
    select branch_id, month_end, 'fusion_valuation' as stock_source, toUInt8(1) as priority from fusion_month_ends
    union all
    select branch_id, month_end, 'snapshot', toUInt8(2) from snapshot_days
    union all
    select branch_id, month_end, 'oasis_batch', toUInt8(3) from batch_days
    union all
    select branch_id, month_end, 'derived', toUInt8(4) from derived_month_ends
),

chosen as (
    select branch_id, month_end, argMin(stock_source, priority) as chosen_source
    from candidates
    group by branch_id, month_end
),

snapshot_rows as (
    select s.branch_id as branch_id, d.month_end as month_end, toDate(d.snapshot_day) as snapshot_date, s.store_id as store_id,
           s.product_code as product_code, s.qty_on_hand as base_quantity, s.qty_on_hand * s.average_cost as snapshot_value,
           toUInt8(0) as has_expired_lot
    from {{ ref('stg_ref__stock_snapshot') }} as s
    inner join snapshot_days as d on d.branch_id = s.branch_id and d.snapshot_day = s.snapshot_date
    inner join (select branch_id, month_end from chosen where chosen_source = 'snapshot') as k
        on k.branch_id = d.branch_id and k.month_end = d.month_end
),

batch_rows as (
    select b.branch_id as branch_id, d.month_end as month_end, toDate(d.snapshot_day) as snapshot_date, b.store_id as store_id,
           b.product_code as product_code, sum(b.quantity) as base_quantity,
           max(toUInt8(b.expiry_date is not null and b.expiry_date < d.month_end and b.quantity > 0)) as has_expired_lot
    from {{ ref('stg_oasis__stock_batch_snapshots') }} as b
    inner join batch_days as d on d.branch_id = b.branch_id and d.snapshot_day = b.snapshot_date
    group by b.branch_id, d.month_end, d.snapshot_day, b.store_id, b.product_code
),

anchor as (
    -- the first Oasis batch month-end of each branch: the known balance the derived months roll back from
    select branch_id, min(month_end) as anchor_month_end, argMin(snapshot_day, month_end) as anchor_day
    from batch_days
    group by branch_id
),

derived_parts as (
    -- anchor stock, plus each later movement with its sign reversed; a derived month sums the parts dated after it
    select r.branch_id as branch_id, r.month_end as part_month_end,
           {{ hnh_surrogate_key(["'oasis'", 'r.branch_id', 'r.store_id']) }} as part_store_key,
           if(x.inventory_item_id is not null, {{ hnh_surrogate_key(['x.inventory_item_id']) }},
              {{ hnh_surrogate_key(['r.branch_id', 'r.product_code']) }}) as part_item_key,
           r.product_code as part_product_code,
           {{ hnh_primary_qty('r.base_quantity', 'x.units_per_primary') }} as part_quantity
    from batch_rows as r
    inner join anchor as a on a.branch_id = r.branch_id and a.anchor_month_end = r.month_end
    left join crosswalk as x on x.branch_key = r.branch_id and x.product_code = r.product_code
    where r.branch_id in (select branch_id from chosen where chosen_source = 'derived')
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here

    union all

    select m.branch_key, toDate(toLastDayOfMonth(toDate(toString(m.date_key)))), m.store_key, m.item_key,
           m.oasis_product_code, -m.primary_quantity
    from {{ ref('fact_stock_movement') }} as m
    inner join anchor as a on a.branch_id = m.branch_key
    where m.source_system = 'oasis' and toDate(toString(m.date_key)) <= a.anchor_day
      and m.branch_key in (select branch_id from chosen where chosen_source = 'derived')
),

derived_rows as (
    select d.branch_id as branch_id, d.month_end as month_end, p.part_store_key as store_key, p.part_item_key as item_key,
           anyIf(p.part_product_code, p.part_product_code is not null) as product_code, sum(p.part_quantity) as derived_quantity
    from (select branch_id, month_end from chosen where chosen_source = 'derived') as d
    inner join derived_parts as p on p.branch_id = d.branch_id and p.part_month_end > d.month_end
    group by d.branch_id, d.month_end, p.part_store_key, p.part_item_key
),

oasis_rows as (
    select s.branch_id as branch_id, s.month_end as month_end, s.snapshot_date as snapshot_date,
           {{ hnh_surrogate_key(["'oasis'", 's.branch_id', 's.store_id']) }} as store_key,
           if(x.inventory_item_id is not null, {{ hnh_surrogate_key(['x.inventory_item_id']) }},
              {{ hnh_surrogate_key(['s.branch_id', 's.product_code']) }}) as item_key,
           toNullable(s.product_code) as oasis_product_code,
           {{ hnh_primary_qty('s.base_quantity', 'x.units_per_primary') }} as quantity,
           s.snapshot_value as stock_value, 'snapshot' as stock_source, s.has_expired_lot as has_expired_lot
    from snapshot_rows as s
    left join crosswalk as x on x.branch_key = s.branch_id and x.product_code = s.product_code
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here

    union all

    select b.branch_id, b.month_end, b.snapshot_date,
           {{ hnh_surrogate_key(["'oasis'", 'b.branch_id', 'b.store_id']) }},
           if(x.inventory_item_id is not null, {{ hnh_surrogate_key(['x.inventory_item_id']) }},
              {{ hnh_surrogate_key(['b.branch_id', 'b.product_code']) }}),
           toNullable(b.product_code),
           {{ hnh_primary_qty('b.base_quantity', 'x.units_per_primary') }},
           b.base_quantity * ifNull(c.product_average_cost, 0), 'oasis_batch', b.has_expired_lot
    from batch_rows as b
    inner join (select branch_id, month_end from chosen where chosen_source = 'oasis_batch') as k
        on k.branch_id = b.branch_id and k.month_end = b.month_end
    left join crosswalk as x on x.branch_key = b.branch_id and x.product_code = b.product_code
    left join average_cost as c on c.branch_id = b.branch_id and c.product_code = b.product_code
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here

    union all

    select r.branch_id, r.month_end, r.month_end, r.store_key, r.item_key, r.product_code, r.derived_quantity,
           r.derived_quantity * ifNull(x.units_per_primary, 1) * ifNull(c.product_average_cost, 0), 'derived', toUInt8(0)
    from derived_rows as r
    left join crosswalk as x on x.branch_key = r.branch_id and x.product_code = r.product_code
    left join average_cost as c on c.branch_id = r.branch_id and c.product_code = r.product_code
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

layers as (
    select o.branch_key as branch_id, v.inventory_org_id as organization_id, v.inventory_item_id as inventory_item_id,
           v.cost_date as cost_date, v.quantity as layer_quantity, v.quantity * v.unit_cost as layer_value
    from {{ ref('stg_fusion__inventory_valuation') }} as v
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = v.inventory_org_id
    where v.posted_flag in ('Y', 'E')
),

org_balances as (
    select k.branch_id as branch_id, k.month_end as month_end, l.organization_id as organization_id,
           l.inventory_item_id as inventory_item_id, sum(l.layer_quantity) as org_quantity, sum(l.layer_value) as org_value
    from (select branch_id, month_end from chosen where chosen_source = 'fusion_valuation') as k
    inner join layers as l on l.branch_id = k.branch_id and l.cost_date <= k.month_end
    group by k.branch_id, k.month_end, l.organization_id, l.inventory_item_id
    having abs(org_quantity) > 0.000001 or abs(org_value) > 0.01
),

onhand_days as (
    select toDate(toLastDayOfMonth(snapshot_date)) as month_end, max(snapshot_date) as onhand_day
    from {{ ref('stg_fusion__inventory_onhand') }}
    where snapshot_date is not null
    group by month_end
),

onhand as (
    select d.month_end as month_end, h.organization_id as organization_id, h.inventory_item_id as inventory_item_id,
           ifNull(h.subinventory_code, '*') as onhand_subinventory, sum(h.primary_quantity) as sub_quantity,
           max(toUInt8(lt.expiration_date is not null and lt.expiration_date < d.month_end and h.primary_quantity > 0)) as sub_expired
    from {{ ref('stg_fusion__inventory_onhand') }} as h
    inner join onhand_days as d on d.onhand_day = h.snapshot_date
    left join {{ ref('stg_fusion__lots') }} as lt
        on lt.inventory_item_id = h.inventory_item_id and lt.organization_id = h.organization_id and lt.lot_number = h.lot_number
    group by d.month_end, h.organization_id, h.inventory_item_id, h.subinventory_code
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

onhand_shares as (
    select o.month_end as month_end, o.organization_id as organization_id, o.inventory_item_id as inventory_item_id,
           o.onhand_subinventory as onhand_subinventory, o.sub_quantity / t.total_quantity as share, o.sub_expired as sub_expired
    from onhand as o
    inner join (select month_end, organization_id, inventory_item_id, sum(sub_quantity) as total_quantity
                from onhand group by month_end, organization_id, inventory_item_id having total_quantity > 0) as t
        on t.month_end = o.month_end and t.organization_id = o.organization_id and t.inventory_item_id = o.inventory_item_id
),

fusion_rows as (
    select b.branch_id as branch_id, b.month_end as month_end, least(b.month_end, today()) as snapshot_date,
           {{ hnh_surrogate_key(["'fusion'", 'b.organization_id', "ifNull(s.onhand_subinventory, '*')"]) }} as store_key,
           {{ hnh_surrogate_key(['b.inventory_item_id']) }} as item_key,
           cast(null as Nullable(String)) as oasis_product_code,
           b.org_quantity * ifNull(s.share, 1) as quantity,
           b.org_value * ifNull(s.share, 1) as stock_value,
           'fusion_valuation' as stock_source,
           ifNull(s.sub_expired, toUInt8(0)) as has_expired_lot
    from org_balances as b
    left join onhand_shares as s
        on s.month_end = b.month_end and s.organization_id = b.organization_id and s.inventory_item_id = b.inventory_item_id
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
),

all_rows as (
    select branch_id as r_branch_key, month_end as r_month_end, snapshot_date as r_snapshot_date, store_key as r_store_key,
           item_key as r_item_key, oasis_product_code as r_product_code, quantity as r_quantity, stock_value as r_value,
           stock_source as r_stock_source, 'oasis' as r_source_system, has_expired_lot as r_expired
    from oasis_rows
    union all
    select branch_id, month_end, snapshot_date, store_key, item_key, oasis_product_code, quantity, stock_value,
           stock_source, 'fusion', has_expired_lot
    from fusion_rows
)

-- one row per branch, month-end, store and item (two Oasis products can map to one Fusion item)
select
    r_branch_key                                            as branch_key,
    r_month_end                                             as month_end,
    max(r_snapshot_date)                                    as snapshot_date,
    r_store_key                                             as store_key,
    r_item_key                                              as item_key,
    anyIf(r_product_code, r_product_code is not null)       as oasis_product_code,
    sum(r_quantity)                                         as quantity,
    sum(r_value)                                            as stock_value,
    any(r_stock_source)                                     as stock_source,
    any(r_source_system)                                    as source_system,
    max(r_expired)                                          as has_expired_lot
from all_rows
group by r_branch_key, r_month_end, r_store_key, r_item_key
```

`fact_stock_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_date_key, store_key, item_key)') }}

-- Month-end stock per branch, store and item (spec 6.4) with the month's consumption from fact_stock_movement for
-- turnover and days of stock. A store and item with consumption but no stock that month gets a row with quantity 0.
-- A snapshot: never sum quantity or stock_value across months.
with stock as (
    select branch_key, month_end, store_key, item_key, quantity as part_quantity, stock_value as part_value,
           stock_source as part_stock_source, source_system as part_source_system, has_expired_lot as part_expired,
           toFloat64(0) as part_consumption_quantity, toFloat64(0) as part_consumption_cost
    from {{ ref('int_stock_month_end') }}
),

branch_months as (
    select branch_key, month_end, any(part_stock_source) as month_stock_source, any(part_source_system) as month_source_system
    from stock
    group by branch_key, month_end
),

consumption as (
    select m.branch_key as branch_key, toDate(toLastDayOfMonth(toDate(toString(m.date_key)))) as month_end,
           m.store_key as store_key, m.item_key as item_key, toFloat64(0) as part_quantity, toFloat64(0) as part_value,
           b.month_stock_source as part_stock_source, b.month_source_system as part_source_system, toUInt8(0) as part_expired,
           sum(m.consumption_quantity) as part_consumption_quantity, sum(m.consumption_cost) as part_consumption_cost
    from {{ ref('fact_stock_movement') }} as m
    inner join branch_months as b
        on b.branch_key = m.branch_key and b.month_end = toDate(toLastDayOfMonth(toDate(toString(m.date_key))))
    where m.is_consumption = 1
    group by m.branch_key, month_end, m.store_key, m.item_key, b.month_stock_source, b.month_source_system
),

combined as (
    select * from stock
    union all
    select * from consumption
)

select
    {{ hnh_surrogate_key(['c.branch_key', 'c.month_end', 'c.store_key', 'c.item_key']) }} as stock_monthly_key,
    c.branch_key                                            as branch_key,
    {{ hnh_date_key('c.month_end') }}                       as month_date_key,
    c.month_end                                             as month_end,
    ifNull(s.store_key, toInt64(-1))                        as store_key,
    ifNull(i.item_key, toInt64(-1))                         as item_key,
    sum(c.part_quantity)                                    as quantity,
    sum(c.part_value)                                       as stock_value,
    any(c.part_stock_source)                                as stock_source,
    any(c.part_source_system)                               as source_system,
    max(ifNull(s.is_expiry_store, toUInt8(0)))              as is_expiry_store,
    toUInt8(c.month_end < today())                          as is_closed_month,
    max(c.part_expired)                                     as has_expired_lot,
    sum(c.part_consumption_quantity)                        as consumption_quantity,
    sum(c.part_consumption_cost)                            as consumption_cost,
    now()                                                   as _loaded_at
from combined as c
left join (select store_key, is_expiry_store from {{ ref('dim_store') }}) as s on s.store_key = c.store_key
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = c.item_key
group by c.branch_key, c.month_end, c.store_key, c.item_key, s.store_key, i.item_key
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select int_stock_month_end fact_stock_monthly`
Expected: unit test PASS; models built (about 2 minutes); tests PASS. While `bal_product_base` is not loaded there are no `snapshot` or `derived` rows. Check (measured) `select branch_key, month_end, stock_source, count(), round(sum(stock_value) / 1e6, 2) from int.int_stock_month_end group by 1, 2, 3 order by 1, 2`: branch 1 `oasis_batch` for 2026-08-31, 09-30 and 10-31 (about 31k rows each); branches 2 and 5 `oasis_batch` for 2026-08-31 then `fusion_valuation` from 2026-09-30 (2: 9.98M, 5: 5.99M at 09-30); branch 3 `fusion_valuation` from 2026-07-31 (10.45M, 12.26M, 12.50M); 4 from 2026-08-31 (7.66M, 9.22M); 6 from 2026-05-31 (43.51M, **419.27M** in June: CEFODOX as recorded, 135.80M, 10.06M, 10.87M); 7 from 2026-04-30 (17.31M … 17.38M); 8 from 2026-07-31 (0.95M, 1.00M, 7.72M); no Head Office rows. Record the table and `select countIf(quantity < 0), countIf(has_expired_lot = 1) from gold.fact_stock_monthly`.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/supply/ hnh_dwh/models/hnh/marts/supply/
git commit -m "Add month-end stock from snapshots, rollback, Oasis batches and Fusion valuation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Purchase lines, goods receipts and the AP link

**Files:**
- Create: `hnh_dwh/models/hnh/marts/supply/fact_purchase_line.sql`, `fact_goods_receipt.sql`, `hnh_dwh/models/hnh/marts/reconciliation/rec_purchase_ap_monthly.sql`, `hnh_dwh/tests/hnh/assert_purchase_line_covers_fusion_schedules.sql`
- Modify: `hnh_dwh/models/hnh/staging/fusion/stg_fusion__ap_invoice_distributions.sql`, `hnh_dwh/models/hnh/marts/finance/fact_ap_invoice_line.sql`, `hnh_dwh/models/hnh/marts/finance/_finance_marts_unit_tests.yml`, `_supply_marts__models.yml`, `_supply_marts_unit_tests.yml`, `_reconciliation__models.yml`

**Interfaces:**
- Consumes: `stg_ref__scm_cutover`, `stg_fusion__po_schedules`, `stg_fusion__po_distributions`, `stg_fusion__requisition_distributions`, `stg_fusion__receipt_transactions`, `stg_fusion__po_line_types`, `int_inventory_org_branch`, `fact_ap_invoice_line` (`po_distribution_id`, `spend_amount`, `branch_key`, `accounting_date_key`), `stg_oasis__stock_documents`, `stg_oasis__stock_document_lines`, `int_item_crosswalk`, `int_oasis_stock_line`, `int_fusion_stock_line` (`rcv_transaction_id`, `lot_number`, `expiry_date`), `hnh_dim_supplier`, `hnh_dim_item`, `dim_store`.
- Produces:
  - `fact_ap_invoice_line` + `po_distribution_id Nullable(Int64)`, `rcv_transaction_id Nullable(Int64)` (spec 6.5 Phase 3 change)
  - `fact_purchase_line(purchase_line_key, branch_key, po_date_key, supplier_key, item_key, ship_to_store_key, source_system, po_number, fusion_line_location_id, oasis_line_id, requisition_number, requisition_approved_date_key, uom_code, quantity_ordered, quantity_received, quantity_cancelled, quantity_billed, unit_price, ordered_value, received_value, first_receipt_date_key, lead_time_days Nullable(Int32), po_status, line_type, is_ap_matched, ap_matched_amount, _loaded_at)`; key `hnh_surrogate_key(["'fusion'", 'line_location_id'])` or `hnh_surrogate_key(["'oasis'", 'branch_id', 'line_id'])`
  - `fact_goods_receipt(goods_receipt_key, branch_key, date_key, supplier_key, item_key, store_key, purchase_line_key, source_system, receipt_type, quantity, unit_price, received_value, free_quantity, is_free_of_charge, lot_number, expiry_date, oasis_line_id, fusion_transaction_id, _loaded_at)`
  - `rec_purchase_ap_monthly(branch_key, month_start, oasis_ordered_value, fusion_ordered_value, oasis_received_value, fusion_received_value, ap_po_matched_spend, ap_non_po_spend, fusion_received_not_matched)`

- [ ] **Step 1: Write the failing unit test, the YAML and the assertion**

Append to `_supply_marts_unit_tests.yml`:

```yaml
  - name: fact_purchase_line_lead_time_and_quantities
    description: >
      Jazan buys in Fusion from 202607. Schedule 10 (1 July, 10 ordered, 8 received, 1 cancelled at 5) is first
      received on 12 July (lead time 11), comes from requisition REQ-9 and has 40 of PO-matched AP. Schedule 11 (June)
      is before the cutover and left out. Schedule 12 is a 300 services line with no receipt. Oasis PO line 50 (10
      July, the overlap month) orders 30 at 14 less 50% = 7 and is received 20 + 10 from 15 July (lead time 5); a
      cancelled GRN line does not count. Line 51 (August) is after the overlap month and left out. Alrabwah line 60 (no
      Fusion purchasing) is a cancelled line of 12: all 12 cancelled.
    model: fact_purchase_line
    given:
      - input: ref('stg_ref__scm_cutover')
        format: sql
        rows: |
          select toUInt8(b) as branch_id, if(m = 0, cast(null as Nullable(Int32)), toNullable(toInt32(m))) as first_fusion_purchasing_month
          from values('b UInt8, m UInt32', (3, 202607), (1, 0))
      - input: ref('stg_fusion__po_schedules')
        format: sql
        rows: |
          select toInt64(ll) as line_location_id, toNullable(concat('PO', toString(ll))) as po_number, toNullable(toInt64(5)) as vendor_id, toNullable(toInt64(7)) as vendor_site_id, toNullable(toInt64(3004)) as ship_to_organization_id, toNullable(toInt64(500)) as item_id, toNullable('EACH') as uom_code, toNullable('OPEN') as document_status, toNullable(toInt64(lt)) as line_type_id, toUInt8(0) as is_cancelled, toNullable(toDate(d)) as po_creation_date, toFloat64(q) as quantity, toFloat64(qr) as quantity_received, toFloat64(0) as quantity_billed, toFloat64(qc) as quantity_cancelled, toFloat64(p) as unit_price, toFloat64(a) as amount, toFloat64(0) as amount_received
          from values('ll UInt32, lt UInt32, d String, q Float64, qr Float64, qc Float64, p Float64, a Float64',
              (10, 1, '2026-07-01', 10, 8, 1, 5, 0), (11, 1, '2026-06-15', 4, 4, 0, 5, 0), (12, 2, '2026-08-01', 0, 0, 0, 0, 300))
      - input: ref('int_inventory_org_branch')
        format: sql
        rows: |
          select toInt64(3004) as organization_id, toUInt8(3) as branch_key
      - input: ref('stg_fusion__po_distributions')
        format: sql
        rows: |
          select toInt64(100) as po_distribution_id, toNullable(toInt64(10)) as line_location_id, toNullable(toInt64(900)) as req_distribution_id
      - input: ref('stg_fusion__requisition_distributions')
        format: sql
        rows: |
          select toInt64(900) as distribution_id, toNullable('REQ-9') as requisition_number, toNullable(toDate32('2026-06-28')) as approved_date
      - input: ref('stg_fusion__receipt_transactions')
        format: sql
        rows: |
          select toNullable(tt) as transaction_type, toNullable(toInt64(10)) as po_line_location_id, toNullable(toDate(d)) as transaction_date
          from values('tt String, d String', ('RECEIVE', '2026-07-12'), ('RECEIVE', '2026-07-20'), ('DELIVER', '2026-07-11'))
      - input: ref('fact_ap_invoice_line')
        format: sql
        rows: |
          select toNullable(toInt64(100)) as po_distribution_id, toFloat64(s) as spend_amount from values('s Float64', (25), (15))
      - input: ref('stg_fusion__po_line_types')
        format: sql
        rows: |
          select toInt64(t) as line_type_id, toNullable(n) as line_type_name from values('t UInt32, n String', (1, 'Goods'), (2, 'Fixed Price Services'))
      - input: ref('stg_oasis__stock_documents')
        format: sql
        rows: |
          select toUInt8(b) as branch_id, toInt64(d) as doc_id, toNullable(concat('D', toString(d))) as doc_no, toNullable('210103-901') as account_code,
                 toNullable(st) as doc_status, toNullable(dt) as doc_type, toNullable(src) as source_code
          from values('b UInt8, d UInt32, st String, dt String, src String', (3, 1, 'R', 'PORDER', 'PO'), (3, 2, 'P', 'STOCKRCPT', 'GRN'), (1, 3, 'R', 'PORDER', 'PO'))
      - input: ref('stg_oasis__stock_document_lines')
        format: sql
        rows: |
          select toUInt8(b) as branch_id, toInt64(l) as line_id, toInt64(d) as doc_id, toNullable(dt) as doc_type, toNullable(toDate32(ld)) as line_date,
                 toNullable(toInt64(36)) as store_id, toNullable('P9') as product_code, toFloat64(qo) as qty_ordered, toFloat64(q) as quantity,
                 toFloat64(lp) as list_unit_price, toFloat64(0) as list_discount_pct, toFloat64(dp) as discount_pct,
                 if(ls = '', cast(null as Nullable(String)), toNullable(ls)) as line_status, if(x = 0, cast(null as Nullable(Int64)), toNullable(toInt64(x))) as cross_ref_line_id,
                 toNullable('EACH') as uom_code
          from values('b UInt8, l UInt32, d UInt32, dt String, ld String, qo Float64, q Float64, lp Float64, dp Float64, ls String, x UInt32',
              (3, 50, 1, 'PORDER', '2026-07-10', 30, 0, 14, 50, 'R', 0), (3, 51, 1, 'PORDER', '2026-08-05', 5, 0, 14, 50, 'R', 0),
              (3, 70, 2, 'STOCKRCPT', '2026-07-15', 20, 20, 0, 0, 'P', 50), (3, 71, 2, 'STOCKRCPT', '2026-07-25', 10, 10, 0, 0, 'P', 50),
              (3, 72, 2, 'STOCKRCPT', '2026-07-26', 99, 99, 0, 0, 'C', 50), (1, 60, 3, 'PORDER', '2025-03-01', 12, 0, 2, 0, 'C', 0))
      - input: ref('int_item_crosswalk')
        format: sql
        rows: |
          select toUInt8(3) as branch_key, 'P0' as product_code, toInt64(1) as inventory_item_id, toFloat64(1) as units_per_primary
      - input: ref('hnh_dim_supplier')
        format: sql
        rows: |
          select toInt64(1) as supplier_key
      - input: ref('hnh_dim_item')
        format: sql
        rows: |
          select toInt64(1) as item_key
      - input: ref('dim_store')
        format: sql
        rows: |
          select toInt64(1) as store_key
    expect:
      rows:
        - {source_system: 'fusion', po_number: 'PO10', quantity_ordered: 10, quantity_received: 8, quantity_cancelled: 1, unit_price: 5, ordered_value: 50, received_value: 40, lead_time_days: 11, requisition_number: 'REQ-9', is_ap_matched: 1, ap_matched_amount: 40, line_type: 'Goods', po_status: 'OPEN'}
        - {source_system: 'fusion', po_number: 'PO12', quantity_ordered: 0, quantity_received: 0, quantity_cancelled: 0, unit_price: 0, ordered_value: 300, received_value: 0, lead_time_days: null, requisition_number: null, is_ap_matched: 0, ap_matched_amount: 0, line_type: 'Services', po_status: 'OPEN'}
        - {source_system: 'oasis', po_number: 'D1', quantity_ordered: 30, quantity_received: 30, quantity_cancelled: 0, unit_price: 7, ordered_value: 210, received_value: 210, lead_time_days: 5, requisition_number: null, is_ap_matched: 0, ap_matched_amount: 0, line_type: 'Goods', po_status: 'RELEASED'}
        - {source_system: 'oasis', po_number: 'D3', quantity_ordered: 12, quantity_received: 0, quantity_cancelled: 12, unit_price: 2, ordered_value: 24, received_value: 0, lead_time_days: null, requisition_number: null, is_ap_matched: 0, ap_matched_amount: 0, line_type: 'Goods', po_status: 'CANCELED'}
```

Fill rate is a KPI over these columns (Σ `quantity_received` ÷ Σ (`quantity_ordered` − `quantity_cancelled`)); the test pins the three quantities it uses.

Append to `_supply_marts__models.yml`:

```yaml
  - name: fact_purchase_line
    columns:
      - name: purchase_line_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: po_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: supplier_key
        tests:
          - relationships: {to: ref('hnh_dim_supplier'), field: supplier_key}
      - name: item_key
        tests:
          - relationships: {to: ref('hnh_dim_item'), field: item_key}
      - name: ship_to_store_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: requisition_approved_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: first_receipt_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: source_system
        tests:
          - accepted_values:
              values: ['oasis', 'fusion']
  - name: fact_goods_receipt
    columns:
      - name: goods_receipt_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: supplier_key
        tests:
          - relationships: {to: ref('hnh_dim_supplier'), field: supplier_key}
      - name: item_key
        tests:
          - relationships: {to: ref('hnh_dim_item'), field: item_key}
      - name: store_key
        tests:
          - relationships: {to: ref('dim_store'), field: store_key}
      - name: purchase_line_key
        tests:
          - relationships:
              to: ref('fact_purchase_line')
              field: purchase_line_key
              config: {where: "purchase_line_key != -1"}
```

Append to `_reconciliation__models.yml`:

```yaml
  - name: rec_purchase_ap_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
```

`hnh_dwh/tests/hnh/assert_purchase_line_covers_fusion_schedules.sql`:

```sql
-- fact_purchase_line holds every Fusion PO schedule in scope (ship-to branch with a first Fusion purchasing month, PO
-- created in or after it) exactly once (spec 8).
with expected as (
    select count() as n
    from {{ ref('stg_fusion__po_schedules') }} as s
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = s.ship_to_organization_id
    inner join {{ ref('stg_ref__scm_cutover') }} as k on k.branch_id = o.branch_key
    where s.po_creation_date is not null and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(s.po_creation_date)) >= k.first_fusion_purchasing_month
),
actual as (
    select count() as n, uniqExact(fusion_line_location_id) as distinct_schedules
    from {{ ref('fact_purchase_line') }} where source_system = 'fusion'
)
select e.n as expected_schedules, a.n as fact_rows, a.distinct_schedules
from expected as e cross join actual as a
where e.n != a.n or a.n != a.distinct_schedules
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_purchase_line_lead_time_and_quantities`
Expected: FAIL — model not found.

- [ ] **Step 2: Add the AP link columns (Phase 3 change)**

Replace `stg_fusion__ap_invoice_distributions.sql` with (adds `rcv_transaction_id`):

```sql
select
    invoice_distribution_id,
    invoice_id,
    {{ hnh_str('invoice_num') }}                as invoice_num,
    {{ hnh_code('line_type_lookup_code') }}     as line_type,
    po_distribution_id,
    rcv_transaction_id,
    {{ hnh_flag('posted_flag') }}               as is_posted,
    {{ hnh_flag('cancellation_flag') }}         as is_cancelled,
    {{ hnh_flag('reversal_flag') }}             as is_reversal,
    {{ hnh_code('invoice_type_lookup_code') }}  as invoice_type_code,
    vendor_id,
    vendor_site_id,
    ledger_id,
    code_combination_id,
    toDate(invoice_date)                        as invoice_date,
    toDate(accounting_date)                     as accounting_date,
    toFloat64(ifNull(accounted_amount, 0))      as amount
from {{ hnh_fusion_source('fact_ap_invoice_distribution') }} final
```

In `fact_ap_invoice_line.sql`, after the line `    toUInt8(d.po_distribution_id is not null)                   as is_po_matched,` insert:

```sql
    d.po_distribution_id                                        as po_distribution_id,
    d.rcv_transaction_id                                        as rcv_transaction_id,
```

In `hnh_dwh/models/hnh/marts/finance/_finance_marts_unit_tests.yml`, test `fact_ap_invoice_line_splits_spend_and_tax`, in the `stg_fusion__ap_invoice_distributions` fixture replace `cast(null as Nullable(Int64)) as po_distribution_id,` with `cast(null as Nullable(Int64)) as po_distribution_id, cast(null as Nullable(Int64)) as rcv_transaction_id,` (the model now reads the column).

- [ ] **Step 3: Write the purchasing facts and the reconciliation**

`fact_purchase_line.sql`:

```sql
{{ config(order_by='(branch_key, po_date_key, purchase_line_key)') }}

-- One row per Fusion PO schedule (line location) from the branch's first Fusion purchasing month, and per Oasis PO line
-- (PORDER, source PO) up to and including that month, or always for a branch without one (spec 6.5, S1): the first
-- Fusion month is the overlap month and keeps both systems' POs, because they are different documents. Quantities are in each system's ordering unit (uom_code: Oasis base
-- unit, Fusion PO unit). Lead time = PO date to first receipt. AP match = Fusion AP lines on the schedule's PO
-- distributions, with Phase 3's spend definition. Oasis POs carry no requisition, billing or AP link.
{% set first_day = "toDate32('" ~ var('hnh_history_start_date') ~ "')" %}

with cutover as (
    select branch_id, first_fusion_purchasing_month from {{ ref('stg_ref__scm_cutover') }}
),

fusion_schedules as (
    select s.line_location_id as line_location_id, s.po_number as po_number, s.vendor_id as vendor_id,
           s.vendor_site_id as vendor_site_id, s.ship_to_organization_id as ship_to_organization_id, s.item_id as item_id,
           s.uom_code as uom_code, s.document_status as document_status, s.line_type_id as line_type_id,
           s.is_cancelled as is_cancelled, assumeNotNull(s.po_creation_date) as po_date, s.quantity as quantity,
           s.quantity_received as quantity_received, s.quantity_billed as quantity_billed,
           s.quantity_cancelled as quantity_cancelled, s.unit_price as unit_price, s.amount as amount,
           s.amount_received as amount_received, o.branch_key as branch_key
    from {{ ref('stg_fusion__po_schedules') }} as s
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = s.ship_to_organization_id
    inner join cutover as k on k.branch_id = o.branch_key
    where s.po_creation_date is not null and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(s.po_creation_date)) >= k.first_fusion_purchasing_month
),

requisitions as (
    select d.line_location_id as req_line_location_id, argMin(r.requisition_number, d.po_distribution_id) as req_number,
           argMin(r.approved_date, d.po_distribution_id) as req_approved_date
    from {{ ref('stg_fusion__po_distributions') }} as d
    inner join {{ ref('stg_fusion__requisition_distributions') }} as r on r.distribution_id = d.req_distribution_id
    where d.line_location_id is not null
    group by d.line_location_id
),

receipts as (
    select po_line_location_id as rcv_line_location_id, min(transaction_date) as first_receipt_date
    from {{ ref('stg_fusion__receipt_transactions') }}
    where transaction_type = 'RECEIVE' and po_line_location_id is not null
    group by po_line_location_id
),

ap_match as (
    select d.line_location_id as ap_line_location_id, sum(a.spend_amount) as matched_amount
    from {{ ref('fact_ap_invoice_line') }} as a
    inner join {{ ref('stg_fusion__po_distributions') }} as d on d.po_distribution_id = a.po_distribution_id
    where a.po_distribution_id is not null and d.line_location_id is not null
    group by d.line_location_id
),

fusion_lines as (
    select
        {{ hnh_surrogate_key(["'fusion'", 's.line_location_id']) }}            as purchase_line_key,
        s.branch_key                                                            as branch_key,
        'fusion'                                                                as source_system,
        s.po_date                                                               as po_date,
        {{ hnh_surrogate_key(['s.vendor_id', 's.vendor_site_id']) }}            as supplier_key_raw,
        {{ hnh_surrogate_key(['s.item_id']) }}                                  as item_key_raw,
        {{ hnh_surrogate_key(["'fusion'", 's.ship_to_organization_id', "'*'"]) }} as ship_to_store_key_raw,
        s.po_number                                                             as po_number,
        toNullable(s.line_location_id)                                          as fusion_line_location_id,
        cast(null as Nullable(Int64))                                           as oasis_line_id,
        q.req_number                                                            as requisition_number,
        q.req_approved_date                                                     as requisition_approved_date,
        s.uom_code                                                              as uom_code,
        s.quantity                                                              as quantity_ordered,
        s.quantity_received                                                     as quantity_received,
        s.quantity_cancelled                                                    as quantity_cancelled,
        s.quantity_billed                                                       as quantity_billed,
        s.unit_price                                                            as unit_price,
        if(s.quantity > 0, s.quantity * s.unit_price, s.amount)                 as ordered_value,
        if(s.quantity > 0, s.quantity_received * s.unit_price, s.amount_received) as received_value,
        r.first_receipt_date                                                    as first_receipt_date,
        ifNull(s.document_status, 'UNKNOWN')                                    as po_status,
        multiIf(lt.line_type_name = 'Goods', 'Goods', ifNull(lt.line_type_name, '') like '%Services%', 'Services',
                ifNull(lt.line_type_name, 'Unknown'))                           as line_type,
        toUInt8(m.ap_line_location_id is not null)                              as is_ap_matched,
        ifNull(m.matched_amount, 0)                                             as ap_matched_amount
    from fusion_schedules as s
    left join requisitions as q on q.req_line_location_id = s.line_location_id
    left join receipts as r on r.rcv_line_location_id = s.line_location_id
    left join ap_match as m on m.ap_line_location_id = s.line_location_id
    left join {{ ref('stg_fusion__po_line_types') }} as lt on lt.line_type_id = s.line_type_id
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

oasis_docs as (
    select branch_id, doc_id, doc_no, account_code, doc_status
    from {{ ref('stg_oasis__stock_documents') }}
    where doc_type = 'PORDER' and source_code = 'PO'
),

oasis_receipts as (
    -- posted GRN lines per PO line, in Oasis base units
    select l.branch_id as grn_branch_id, assumeNotNull(l.cross_ref_line_id) as grn_po_line_id,
           sum(l.quantity) as grn_quantity, min(l.line_date) as grn_first_date
    from {{ ref('stg_oasis__stock_document_lines') }} as l
    inner join (select branch_id, doc_id from {{ ref('stg_oasis__stock_documents') }}
                where doc_type = 'STOCKRCPT' and source_code = 'GRN' and doc_status = 'P') as d
        on d.branch_id = l.branch_id and d.doc_id = l.doc_id
    where l.doc_type = 'STOCKRCPT' and l.cross_ref_line_id is not null and ifNull(l.line_status, '') not in ('C', 'S')
    group by l.branch_id, l.cross_ref_line_id
),

oasis_lines as (
    select
        {{ hnh_surrogate_key(["'oasis'", 'l.branch_id', 'l.line_id']) }}       as purchase_line_key,
        l.branch_id                                                             as branch_key,
        'oasis'                                                                 as source_system,
        toDate(assumeNotNull(l.line_date))                                      as po_date,
        {{ hnh_surrogate_key(["'oasis'", 'l.branch_id', 'd.account_code']) }}  as supplier_key_raw,
        if(x.inventory_item_id is not null, {{ hnh_surrogate_key(['x.inventory_item_id']) }},
           {{ hnh_surrogate_key(['l.branch_id', 'l.product_code']) }})          as item_key_raw,
        {{ hnh_surrogate_key(["'oasis'", 'l.branch_id', 'l.store_id']) }}      as ship_to_store_key_raw,
        d.doc_no                                                                as po_number,
        cast(null as Nullable(Int64))                                           as fusion_line_location_id,
        toNullable(l.line_id)                                                   as oasis_line_id,
        cast(null as Nullable(String))                                          as requisition_number,
        cast(null as Nullable(Date32))                                          as requisition_approved_date,
        l.uom_code                                                              as uom_code,
        l.qty_ordered                                                           as quantity_ordered,
        ifNull(g.grn_quantity, 0)                                               as quantity_received,
        if(ifNull(l.line_status, '') = 'C', greatest(l.qty_ordered - ifNull(g.grn_quantity, 0), 0), 0) as quantity_cancelled,
        toFloat64(0)                                                            as quantity_billed,
        l.list_unit_price * (1 - l.list_discount_pct / 100) * (1 - l.discount_pct / 100) as unit_price,
        l.qty_ordered * unit_price                                              as ordered_value,
        ifNull(g.grn_quantity, 0) * unit_price                                  as received_value,
        if(g.grn_first_date is null, cast(null as Nullable(Date)), toDate(g.grn_first_date)) as first_receipt_date,
        {{ hnh_oasis_po_status('d.doc_status', 'l.line_status') }}              as po_status,
        'Goods'                                                                 as line_type,
        toUInt8(0)                                                              as is_ap_matched,
        toFloat64(0)                                                            as ap_matched_amount
    from {{ ref('stg_oasis__stock_document_lines') }} as l
    inner join oasis_docs as d on d.branch_id = l.branch_id and d.doc_id = l.doc_id
    left join cutover as k on k.branch_id = l.branch_id
    left join oasis_receipts as g on g.grn_branch_id = l.branch_id and g.grn_po_line_id = l.line_id
    left join {{ ref('int_item_crosswalk') }} as x on x.branch_key = l.branch_id and x.product_code = l.product_code
    where l.doc_type = 'PORDER' and l.line_date >= {{ first_day }} and l.line_date <= toDate32(today())
      and (k.first_fusion_purchasing_month is null or toInt32(toYYYYMM(l.line_date)) <= k.first_fusion_purchasing_month)
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

lines as (
    select * from fusion_lines
    union all
    select * from oasis_lines
)

select
    l.purchase_line_key                                         as purchase_line_key,
    l.branch_key                                                as branch_key,
    {{ hnh_date_key('l.po_date') }}                             as po_date_key,
    ifNull(sp.supplier_key, toInt64(-1))                        as supplier_key,
    ifNull(i.item_key, toInt64(-1))                             as item_key,
    ifNull(st.store_key, toInt64(-1))                           as ship_to_store_key,
    l.source_system                                             as source_system,
    l.po_number                                                 as po_number,
    l.fusion_line_location_id                                   as fusion_line_location_id,
    l.oasis_line_id                                             as oasis_line_id,
    l.requisition_number                                        as requisition_number,
    {{ hnh_date_key_in_range('l.requisition_approved_date') }}  as requisition_approved_date_key,
    l.uom_code                                                  as uom_code,
    l.quantity_ordered                                          as quantity_ordered,
    l.quantity_received                                         as quantity_received,
    l.quantity_cancelled                                        as quantity_cancelled,
    l.quantity_billed                                           as quantity_billed,
    l.unit_price                                                as unit_price,
    l.ordered_value                                             as ordered_value,
    l.received_value                                            as received_value,
    {{ hnh_date_key_in_range('l.first_receipt_date') }}         as first_receipt_date_key,
    if(l.first_receipt_date is null, cast(null as Nullable(Int32)),
       toInt32(dateDiff('day', l.po_date, assumeNotNull(l.first_receipt_date)))) as lead_time_days,
    l.po_status                                                 as po_status,
    l.line_type                                                 as line_type,
    l.is_ap_matched                                             as is_ap_matched,
    l.ap_matched_amount                                         as ap_matched_amount,
    now()                                                       as _loaded_at
from lines as l
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as sp on sp.supplier_key = l.supplier_key_raw
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = l.item_key_raw
left join (select store_key from {{ ref('dim_store') }}) as st on st.store_key = l.ship_to_store_key_raw
{{ hnh_settings() }}
```

`fact_goods_receipt.sql`:

```sql
{{ config(order_by='(branch_key, date_key, goods_receipt_key)') }}

-- One row per receipt line (spec 6.6): Fusion RECEIVE and RETURN TO VENDOR transactions from the branch's first Fusion
-- purchasing month, and Oasis GRN lines (STOCKRCPT source GRN, in scope as in int_oasis_stock_line) from the history
-- start; Oasis GRNs after the cutover receive Oasis POs of the overlap month. Quantities in the item's primary unit,
-- returns negative. Fusion store and lot come from the receipt's delivery into inventory.
with cutover as (
    select branch_id, first_fusion_purchasing_month from {{ ref('stg_ref__scm_cutover') }}
),

deliveries as (
    select parent_transaction_id as deliver_parent_id, min(transaction_id) as deliver_id,
           anyIf(subinventory_code, subinventory_code is not null) as deliver_subinventory
    from {{ ref('stg_fusion__receipt_transactions') }}
    where transaction_type = 'DELIVER' and parent_transaction_id is not null
    group by parent_transaction_id
),

deliver_lots as (
    select assumeNotNull(rcv_transaction_id) as lot_rcv_transaction_id, min(lot_number) as delivered_lot, min(expiry_date) as delivered_expiry
    from {{ ref('int_fusion_stock_line') }}
    where rcv_transaction_id is not null
    group by rcv_transaction_id
),

fusion_receipts as (
    select
        {{ hnh_surrogate_key(["'fusion'", 'r.transaction_id']) }}              as goods_receipt_key,
        o.branch_key                                                            as branch_key,
        assumeNotNull(r.transaction_date)                                       as receipt_date,
        'fusion'                                                                as source_system,
        {{ hnh_surrogate_key(['r.vendor_id', 'r.vendor_site_id']) }}            as supplier_key_raw,
        {{ hnh_surrogate_key(['r.item_id']) }}                                  as item_key_raw,
        {{ hnh_surrogate_key(["'fusion'", 'r.organization_id', "ifNull(dv.deliver_subinventory, '*')"]) }} as store_key_raw,
        {{ hnh_surrogate_key(["'fusion'", 'r.po_line_location_id']) }}          as purchase_line_key_raw,
        r.transaction_type                                                      as receipt_type,
        if(r.transaction_type = 'RETURN TO VENDOR', -1, 1) * r.primary_quantity as quantity,
        r.po_unit_price                                                         as unit_price,
        if(r.primary_quantity != 0, if(r.transaction_type = 'RETURN TO VENDOR', -1, 1) * r.quantity * r.po_unit_price,
           if(r.transaction_type = 'RETURN TO VENDOR', -1, 1) * r.amount)       as received_value,
        toFloat64(0)                                                            as free_quantity,
        coalesce(dl.delivered_lot, r.vendor_lot_number)                         as lot_number,
        dl.delivered_expiry                                                     as expiry_date,
        cast(null as Nullable(Int64))                                           as oasis_line_id,
        toNullable(r.transaction_id)                                            as fusion_transaction_id
    from {{ ref('stg_fusion__receipt_transactions') }} as r
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = r.organization_id
    inner join cutover as k on k.branch_id = o.branch_key
    left join deliveries as dv on dv.deliver_parent_id = r.transaction_id
    left join deliver_lots as dl on dl.lot_rcv_transaction_id = dv.deliver_id
    where r.transaction_type in ('RECEIVE', 'RETURN TO VENDOR') and r.transaction_date is not null
      and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(r.transaction_date)) >= k.first_fusion_purchasing_month
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

oasis_receipts as (
    select
        {{ hnh_surrogate_key(["'oasis-line'", 'g.branch_key', 'g.oasis_line_id']) }} as goods_receipt_key,
        g.branch_key                                                            as branch_key,
        toDate(g.line_date)                                                     as receipt_date,
        'oasis'                                                                 as source_system,
        {{ hnh_surrogate_key(["'oasis'", 'g.branch_key', 'g.account_code']) }} as supplier_key_raw,
        g.item_key                                                              as item_key_raw,
        {{ hnh_surrogate_key(["'oasis'", 'g.branch_key', 'g.store_id']) }}     as store_key_raw,
        {{ hnh_surrogate_key(["'oasis'", 'g.branch_key', 'g.cross_ref_line_id']) }} as purchase_line_key_raw,
        'GRN'                                                                   as receipt_type,
        g.primary_quantity                                                      as quantity,
        g.unit_cost                                                             as unit_price,
        g.cost_amount                                                           as received_value,
        g.bonus_quantity                                                        as free_quantity,
        g.lot_number                                                            as lot_number,
        g.expiry_date                                                           as expiry_date,
        toNullable(g.oasis_line_id)                                             as oasis_line_id,
        cast(null as Nullable(Int64))                                           as fusion_transaction_id
    from {{ ref('int_oasis_stock_line') }} as g
    where g.movement_type = 'Goods receipt'
),

receipts as (
    select * from fusion_receipts
    union all
    select * from oasis_receipts
)

select
    r.goods_receipt_key                                     as goods_receipt_key,
    r.branch_key                                            as branch_key,
    {{ hnh_date_key('r.receipt_date') }}                    as date_key,
    ifNull(sp.supplier_key, toInt64(-1))                    as supplier_key,
    ifNull(i.item_key, toInt64(-1))                         as item_key,
    ifNull(st.store_key, toInt64(-1))                       as store_key,
    ifNull(pl.purchase_line_key, toInt64(-1))               as purchase_line_key,
    r.source_system                                         as source_system,
    r.receipt_type                                          as receipt_type,
    r.quantity                                              as quantity,
    r.unit_price                                            as unit_price,
    r.received_value                                        as received_value,
    r.free_quantity                                         as free_quantity,
    toUInt8(r.free_quantity > 0)                            as is_free_of_charge,
    r.lot_number                                            as lot_number,
    r.expiry_date                                           as expiry_date,
    r.oasis_line_id                                         as oasis_line_id,
    r.fusion_transaction_id                                 as fusion_transaction_id,
    now()                                                   as _loaded_at
from receipts as r
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as sp on sp.supplier_key = r.supplier_key_raw
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = r.item_key_raw
left join (select store_key from {{ ref('dim_store') }}) as st on st.store_key = r.store_key_raw
left join (select purchase_line_key from {{ ref('fact_purchase_line') }}) as pl on pl.purchase_line_key = r.purchase_line_key_raw
{{ hnh_settings() }}
```

`rec_purchase_ap_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_start)') }}

-- Per branch and month (spec 8): received value against PO-matched AP spend, with non-PO AP spend; ordered value by
-- PO month. AP months are accounting months; spend follows Phase 3 (spend_amount).
with ordered as (
    select branch_key, toStartOfMonth(toDate(toString(po_date_key))) as month_start,
           sumIf(ordered_value, source_system = 'oasis') as oasis_ordered_value,
           sumIf(ordered_value, source_system = 'fusion') as fusion_ordered_value
    from {{ ref('fact_purchase_line') }}
    group by branch_key, month_start
),

received as (
    select branch_key, toStartOfMonth(toDate(toString(date_key))) as month_start,
           sumIf(received_value, source_system = 'oasis') as oasis_received_value,
           sumIf(received_value, source_system = 'fusion') as fusion_received_value
    from {{ ref('fact_goods_receipt') }}
    group by branch_key, month_start
),

ap as (
    select branch_key, toStartOfMonth(toDate(toString(accounting_date_key))) as month_start,
           sumIf(spend_amount, po_distribution_id is not null) as ap_po_matched_spend,
           sumIf(spend_amount, po_distribution_id is null) as ap_non_po_spend
    from {{ ref('fact_ap_invoice_line') }}
    where accounting_date_key is not null
    group by branch_key, month_start
),

spine as (
    select branch_key, month_start from ordered
    union distinct select branch_key, month_start from received
    union distinct select branch_key, month_start from ap
)

select
    s.branch_key                                        as branch_key,
    s.month_start                                       as month_start,
    ifNull(o.oasis_ordered_value, 0)                    as oasis_ordered_value,
    ifNull(o.fusion_ordered_value, 0)                   as fusion_ordered_value,
    ifNull(r.oasis_received_value, 0)                   as oasis_received_value,
    ifNull(r.fusion_received_value, 0)                  as fusion_received_value,
    ifNull(a.ap_po_matched_spend, 0)                    as ap_po_matched_spend,
    ifNull(a.ap_non_po_spend, 0)                        as ap_non_po_spend,
    ifNull(r.fusion_received_value, 0) - ifNull(a.ap_po_matched_spend, 0) as fusion_received_not_matched
from spine as s
left join ordered as o on o.branch_key = s.branch_key and o.month_start = s.month_start
left join received as r on r.branch_key = s.branch_key and r.month_start = s.month_start
left join ap as a on a.branch_key = s.branch_key and a.month_start = s.month_start
{{ hnh_settings() }}
```

- [ ] **Step 4: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_fusion__ap_invoice_distributions fact_ap_invoice_line fact_purchase_line fact_goods_receipt rec_purchase_ap_monthly assert_purchase_line_covers_fusion_schedules`
Expected: unit tests PASS (also `fact_ap_invoice_line_splits_spend_and_tax`); models built; tests PASS. Check (measured) `select source_system, branch_key, count(), countIf(supplier_key = -1), round(median(lead_time_days)), round(sum(ordered_value) / 1e6, 2) from gold.fact_purchase_line group by 1, 2 order by 1, 2` — Fusion 34,152 schedules (2: 1,807; 3: 5,403; 4: 3,561; 5: 1,759; 6: 16,597; 7: 2,335; 8: 1,091 of which 313 without supplier; 100: 1,599); Oasis 404,806 lines (1: 81,293; 2: 92,942; 3: 77,583; 4: 72,785; 5: 61,771; 6: 17,996; 7: 436); median lead time 6–16 days. Record it, `select source_system, receipt_type, count(), round(sum(received_value) / 1e6, 2) from gold.fact_goods_receipt group by 1, 2` (Fusion RECEIVE + RETURN TO VENDOR are 14,366 rows before the cutover filter) and `select * from gold.rec_purchase_ap_monthly where month_start >= '2026-01-01' order by 1, 2`.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/ hnh_dwh/tests/hnh/assert_purchase_line_covers_fusion_schedules.sql
git commit -m "Add purchase lines, goods receipts and the PO-to-AP link" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Interface and GL reconciliation, and the supply monitors

**Files:**
- Create: `hnh_dwh/models/hnh/marts/reconciliation/rec_stock_interface_daily.sql`, `rec_inventory_gl_monthly.sql`; tests `hnh_dwh/tests/hnh/assert_supply_facts_have_branch.sql` and `warn_fusion_interface_gap.sql`, `warn_unit_cost_outliers.sql`, `warn_movements_unknown_item_or_store.sql`, `warn_negative_month_end_stock.sql`, `warn_stock_in_expired_lots.sql`, `warn_opening_balance_after_first_sale.sql`, `warn_deleted_items_with_movements.sql`, `warn_po_lines_without_supplier.sql`, `warn_valuation_error_layers.sql`, `warn_future_stock_dates.sql`
- Modify: `_reconciliation__models.yml`

**Interfaces:**
- Consumes: `stg_ref__scm_cutover`, `int_fusion_stock_line`, `int_oasis_stock_line`, `fact_stock_movement`, `stg_fusion__inventory_valuation`, `int_inventory_org_branch`, `fact_gl_balance_monthly` (`branch_key`, `gl_account_key`, `period_key`, `balance_view`, `closing_balance`), `hnh_dim_gl_account` (`gl_account_key`, `natural_account`), `hnh_dim_gl_period` (`period_key`, `month_start`), `stg_fusion__cost_distributions`, `hnh_dim_branch`, the supply facts and dims, `stg_oasis__store_requisitions`.
- Produces:
  - `rec_stock_interface_daily(branch_key, line_date Date32, date_key, is_live, oasis_lines, oasis_quantity, oasis_cost, oasis_lines_in_fusion, fusion_integration_transactions, fusion_quantity, fusion_cost, fusion_without_reference, fusion_before_go_live, batch_lines_left_out, lines_from_go_live, gap_lines, gap_share Nullable(Float64))`
  - `rec_inventory_gl_monthly(branch_key, month_start, fusion_stock_value, gl_inventory_posted, gl_inventory_including_unposted, cost_distribution_lines, accounted_lines, accounted_share Nullable(Float64), difference_posted)`

- [ ] **Step 1: Write the YAML tests**

Append to `_reconciliation__models.yml`:

```yaml
  - name: rec_stock_interface_daily
    tests:
      - hnh_unique_combination:
          columns: [branch_key, line_date]
  - name: rec_inventory_gl_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select rec_stock_interface_daily rec_inventory_gl_monthly`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the reconciliation models**

`rec_stock_interface_daily.sql`:

```sql
{{ config(order_by='(branch_key, line_date)') }}

-- Per branch and day from the first Fusion inventory month (spec 8): Oasis stock lines against the Fusion integration
-- transactions (count, quantity, cost) and the gap share from the go-live. Fusion rows before the go-live, integration
-- rows without a reference and Oasis batch postings from the go-live are shown here; they are not in fact_stock_movement.
{% set start = "toDate32('" ~ var('hnh_fusion_inventory_start') ~ "')" %}

with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }} where inventory_go_live_date is not null
),

fusion_refs as (
    select distinct branch_key as ref_branch_key, assumeNotNull(oasis_line_id) as ref_line_id
    from {{ ref('int_fusion_stock_line') }}
    where reference_status = 'oasis_line'
),

oasis_daily as (
    select o.branch_key as branch_key, o.line_date as line_date, count() as oasis_lines,
           sum(o.primary_quantity) as oasis_quantity, sum(o.cost_amount) as oasis_cost,
           countIf(f.ref_line_id is not null) as oasis_lines_in_fusion,
           countIf(o.is_batch_posting = 1 and k.go_live_date is not null and o.line_date >= k.go_live_date) as batch_lines_left_out
    from {{ ref('int_oasis_stock_line') }} as o
    left join fusion_refs as f on f.ref_branch_key = o.branch_key and f.ref_line_id = o.oasis_line_id
    left join cutover as k on k.branch_id = o.branch_key
    where o.line_date >= {{ start }}
    group by o.branch_key, o.line_date
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
),

fusion_daily as (
    select f.branch_key as branch_key, toDate32(f.transaction_date) as line_date,
           countIf(f.is_integration_type = 1) as fusion_integration_transactions,
           sumIf(f.primary_quantity, f.is_integration_type = 1) as fusion_quantity,
           sumIf(f.primary_quantity * ifNull(f.valuation_unit_cost, 0), f.is_integration_type = 1) as fusion_cost,
           countIf(f.reference_status = 'no_reference') as fusion_without_reference,
           countIf(k.go_live_date is null or f.transaction_date < k.go_live_date) as fusion_before_go_live
    from {{ ref('int_fusion_stock_line') }} as f
    left join cutover as k on k.branch_id = f.branch_key
    group by f.branch_key, line_date
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

fact_daily as (
    select branch_key, toDate32(toDate(toString(date_key))) as line_date,
           countIf(oasis_line_id is not null and (source_system = 'fusion' or is_fusion_gap = 1)) as lines_from_go_live,
           countIf(is_fusion_gap = 1) as gap_lines
    from {{ ref('fact_stock_movement') }}
    where date_key >= toInt32(toYYYYMMDD({{ start }}))
    group by branch_key, line_date
),

spine as (
    select branch_key, line_date from oasis_daily
    union distinct select branch_key, line_date from fusion_daily
)

select
    s.branch_key                                            as branch_key,
    s.line_date                                             as line_date,
    {{ hnh_date_key('s.line_date') }}                       as date_key,
    toUInt8(k.go_live_date is not null and s.line_date >= k.go_live_date) as is_live,
    ifNull(o.oasis_lines, 0)                                as oasis_lines,
    ifNull(o.oasis_quantity, 0)                             as oasis_quantity,
    ifNull(o.oasis_cost, 0)                                 as oasis_cost,
    ifNull(o.oasis_lines_in_fusion, 0)                      as oasis_lines_in_fusion,
    ifNull(f.fusion_integration_transactions, 0)            as fusion_integration_transactions,
    ifNull(f.fusion_quantity, 0)                            as fusion_quantity,
    ifNull(f.fusion_cost, 0)                                as fusion_cost,
    ifNull(f.fusion_without_reference, 0)                   as fusion_without_reference,
    ifNull(f.fusion_before_go_live, 0)                      as fusion_before_go_live,
    ifNull(o.batch_lines_left_out, 0)                       as batch_lines_left_out,
    ifNull(d.lines_from_go_live, 0)                         as lines_from_go_live,
    ifNull(d.gap_lines, 0)                                  as gap_lines,
    if(ifNull(d.lines_from_go_live, 0) = 0, cast(null as Nullable(Float64)),
       ifNull(d.gap_lines, 0) / d.lines_from_go_live)       as gap_share
from spine as s
left join cutover as k on k.branch_id = s.branch_key
left join oasis_daily as o on o.branch_key = s.branch_key and o.line_date = s.line_date
left join fusion_daily as f on f.branch_key = s.branch_key and f.line_date = s.line_date
left join fact_daily as d on d.branch_key = s.branch_key and d.line_date = s.line_date
{{ hnh_settings() }}
```

`rec_inventory_gl_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_start)') }}

-- Per branch and month from the first Fusion inventory month (spec 8): Fusion valuation stock value at the month-end
-- (all organisations of the branch), the GL balance of the inventory accounts (natural account 115*) at the last
-- period of the month, the accounted share of the month's cost distributions, and the difference. Not expected to tie
-- from July 2026 (cost accounting backlog, spec F11); Abha carries CEFODOX as recorded.
{% set start = "toDate('" ~ var('hnh_fusion_inventory_start') ~ "')" %}

with months as (
    select toStartOfMonth(addMonths({{ start }}, toInt32(number))) as month_start
    from numbers(toUInt64(dateDiff('month', {{ start }}, today()) + 1))
),

layers as (
    select o.branch_key as branch_key, v.cost_date as cost_date, v.quantity * v.unit_cost as layer_value
    from {{ ref('stg_fusion__inventory_valuation') }} as v
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = v.inventory_org_id
    where v.posted_flag in ('Y', 'E')
),

valuation as (
    select l.branch_key as branch_key, m.month_start as month_start, sum(l.layer_value) as fusion_stock_value
    from months as m
    inner join layers as l on l.cost_date <= toLastDayOfMonth(m.month_start)
    group by l.branch_key, m.month_start
),

gl as (
    select b.branch_key as branch_key, p.month_start as month_start,
           sumIf(b.closing_balance, b.balance_view = 'posted') as gl_inventory_posted,
           sumIf(b.closing_balance, b.balance_view = 'including_unposted') as gl_inventory_including_unposted
    from {{ ref('fact_gl_balance_monthly') }} as b
    inner join (select gl_account_key from {{ ref('hnh_dim_gl_account') }}
                where toString(ifNull(natural_account, 0)) like '115%') as a on a.gl_account_key = b.gl_account_key
    inner join (select month_start, max(period_key) as last_period_key from {{ ref('hnh_dim_gl_period') }}
                group by month_start) as p on p.last_period_key = b.period_key
    group by b.branch_key, p.month_start
),

distributions as (
    select br.branch_key as branch_key, toStartOfMonth(d.gl_date) as month_start, count() as cost_distribution_lines,
           countIf(d.accounted_flag = 'F') as accounted_lines
    from {{ ref('stg_fusion__cost_distributions') }} as d
    inner join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as br
        on br.fusion_ledger_id = d.ledger_id
    where d.gl_date is not null
    group by br.branch_key, month_start
),

spine as (
    select branch_key, month_start from valuation
    union distinct select branch_key, month_start from gl where month_start between {{ start }} and toStartOfMonth(today())
    union distinct select branch_key, month_start from distributions
)

select
    s.branch_key                                            as branch_key,
    s.month_start                                           as month_start,
    ifNull(v.fusion_stock_value, 0)                         as fusion_stock_value,
    ifNull(g.gl_inventory_posted, 0)                        as gl_inventory_posted,
    ifNull(g.gl_inventory_including_unposted, 0)            as gl_inventory_including_unposted,
    ifNull(d.cost_distribution_lines, 0)                    as cost_distribution_lines,
    ifNull(d.accounted_lines, 0)                            as accounted_lines,
    if(ifNull(d.cost_distribution_lines, 0) = 0, cast(null as Nullable(Float64)),
       d.accounted_lines / d.cost_distribution_lines)       as accounted_share,
    ifNull(v.fusion_stock_value, 0) - ifNull(g.gl_inventory_posted, 0) as difference_posted
from spine as s
left join valuation as v on v.branch_key = s.branch_key and v.month_start = s.month_start
left join gl as g on g.branch_key = s.branch_key and g.month_start = s.month_start
left join distributions as d on d.branch_key = s.branch_key and d.month_start = s.month_start
{{ hnh_settings() }}
```

- [ ] **Step 3: Write the branch assertion and the monitors**

`assert_supply_facts_have_branch.sql`:

```sql
-- Supply-chain facts never fall back to the Group member (branch 0), and no Fusion inventory organisation is unresolved.
select 'fact_stock_movement' as fact, count() as rows_without_branch from {{ ref('fact_stock_movement') }} where branch_key = 0 having count() > 0
union all
select 'fact_patient_consumption', count() from {{ ref('fact_patient_consumption') }} where branch_key = 0 having count() > 0
union all
select 'fact_stock_monthly', count() from {{ ref('fact_stock_monthly') }} where branch_key = 0 having count() > 0
union all
select 'fact_purchase_line', count() from {{ ref('fact_purchase_line') }} where branch_key = 0 having count() > 0
union all
select 'fact_goods_receipt', count() from {{ ref('fact_goods_receipt') }} where branch_key = 0 having count() > 0
union all
select 'int_inventory_org_branch', count() from {{ ref('int_inventory_org_branch') }} where branch_key = 0 having count() > 0
```

`warn_fusion_interface_gap.sql`:

```sql
{{ config(severity='warn') }}
-- Closed days after go-live where more than 20% of the Oasis lines are not in Fusion yet (spec 8, F2).
select branch_key, line_date, lines_from_go_live, gap_lines, round(gap_share, 3) as gap_share
from {{ ref('rec_stock_interface_daily') }}
where is_live = 1 and line_date < today() and gap_share > 0.20
```

`warn_unit_cost_outliers.sql`:

```sql
{{ config(severity='warn') }}
-- Movements whose unit cost is above 20 x the item's median unit cost (listed, never changed: spec S6, e.g. CEFODOX).
with medians as (
    select item_key, median(unit_cost) as median_unit_cost
    from {{ ref('fact_stock_movement') }}
    where unit_cost > 0 and item_key != -1
    group by item_key
)
select m.branch_key, m.date_key, m.item_key, m.movement_type, m.source_system, m.unit_cost, d.median_unit_cost, m.cost_amount
from {{ ref('fact_stock_movement') }} as m
inner join medians as d on d.item_key = m.item_key
where d.median_unit_cost > 0 and m.unit_cost > 20 * d.median_unit_cost
```

`warn_movements_unknown_item_or_store.sql`:

```sql
{{ config(severity='warn') }}
-- Movements with the Unknown item (-1) or a store without a map_store_department row, by branch and source.
select m.branch_key, m.source_system, countIf(m.item_key = -1) as unknown_item_rows,
       countIf(m.store_key = -1 or s.store_type = 'Unmapped') as unmapped_store_rows
from {{ ref('fact_stock_movement') }} as m
left join (select store_key, store_type from {{ ref('dim_store') }}) as s on s.store_key = m.store_key
group by m.branch_key, m.source_system
having unknown_item_rows > 0 or unmapped_store_rows > 0
{{ hnh_settings() }}
```

`warn_negative_month_end_stock.sql`:

```sql
{{ config(severity='warn') }}
-- Negative month-end stock (spec F14: Muhayil's opening balance after its first sales, Unaizah on-hand).
select branch_key, month_end, stock_source, count() as rows, round(sum(quantity), 2) as quantity
from {{ ref('fact_stock_monthly') }}
where quantity < 0
group by branch_key, month_end, stock_source
```

`warn_stock_in_expired_lots.sql`:

```sql
{{ config(severity='warn') }}
-- Positive stock in expired lots or batches at the latest month-end of each branch.
select branch_key, month_end, count() as rows, round(sum(stock_value), 2) as stock_value
from {{ ref('fact_stock_monthly') }}
where has_expired_lot = 1 and quantity > 0
  and (branch_key, month_end) in (select branch_key, max(month_end) from {{ ref('fact_stock_monthly') }} group by branch_key)
group by branch_key, month_end
```

`warn_opening_balance_after_first_sale.sql`:

```sql
{{ config(severity='warn') }}
-- Branches whose Fusion opening balance is dated after their first Fusion patient sale (spec O-P5-7, Muhayil).
with sales as (
    select branch_key, min(transaction_date) as first_sale
    from {{ ref('int_fusion_stock_line') }}
    where transaction_type_id = 300000012981827
    group by branch_key
),
openings as (
    select branch_key, max(transaction_date) as last_opening
    from {{ ref('int_fusion_stock_line') }}
    where is_opening_balance = 1 and transaction_type_id = 42
    group by branch_key
)
select o.branch_key, s.first_sale, o.last_opening
from openings as o
inner join sales as s on s.branch_key = o.branch_key
where o.last_opening > s.first_sale
```

`warn_deleted_items_with_movements.sql`:

```sql
{{ config(severity='warn') }}
-- Movements on Fusion items whose number starts with Deleted- (spec F7).
select m.branch_key, count() as rows, uniqExact(m.item_key) as items
from {{ ref('fact_stock_movement') }} as m
inner join (select item_key from {{ ref('hnh_dim_item') }} where is_deleted = 1) as i on i.item_key = m.item_key
group by m.branch_key
```

`warn_po_lines_without_supplier.sql`:

```sql
{{ config(severity='warn') }}
-- PO lines whose supplier is not in hnh_dim_supplier.
select branch_key, source_system, count() as lines, round(sum(ordered_value), 2) as ordered_value
from {{ ref('fact_purchase_line') }}
where supplier_key = -1
group by branch_key, source_system
```

`warn_valuation_error_layers.sql`:

```sql
{{ config(severity='warn') }}
-- Fusion valuation layers with posted_flag E (spec F14); they are kept in costs and stock values.
select o.branch_key, toStartOfMonth(v.cost_date) as month_start, count() as layers, round(sum(v.quantity * v.unit_cost), 2) as layer_value
from {{ ref('stg_fusion__inventory_valuation') }} as v
inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = v.inventory_org_id
where v.posted_flag = 'E'
group by o.branch_key, month_start
```

`warn_future_stock_dates.sql`:

```sql
{{ config(severity='warn') }}
-- Oasis stock lines and bin transactions dated after today (spec F14: bintran dates reach 2299).
select 'stock line' as kind, branch_key, count() as rows, max(line_date) as latest
from {{ ref('int_oasis_stock_line') }}
where line_date > toDate32(today())
group by branch_key
union all
select 'bin transaction', branch_id, count(), max(transaction_date)
from {{ ref('stg_oasis__store_requisitions') }}
where transaction_date > toDate32(today())
group by branch_id
```

- [ ] **Step 4: Run the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select rec_stock_interface_daily rec_inventory_gl_monthly assert_supply_facts_have_branch warn_fusion_interface_gap warn_unit_cost_outliers warn_movements_unknown_item_or_store warn_negative_month_end_stock warn_stock_in_expired_lots warn_opening_balance_after_first_sale warn_deleted_items_with_movements warn_po_lines_without_supplier warn_valuation_error_layers warn_future_stock_dates`
Expected: models built; `assert_supply_facts_have_branch` and the uniqueness tests PASS; monitors PASS or WARN (never ERROR). Expected findings: `warn_fusion_interface_gap` lists most closed days since mid-August (overall gap share from go-live 480,846 ÷ 1,138,778 = 42%); `warn_unit_cost_outliers` includes CEFODOX in Abha (2026-06-20); `warn_opening_balance_after_first_sale` returns branch 8 (opening balance 2026-07-30 after the first sale on 2026-05-03); `warn_negative_month_end_stock` returns branch 8 rows (50 to 102 per month-end) and a few in branches 3, 4 and 7; `warn_valuation_error_layers` returns October 2026 (about 39.6k layers). `rec_inventory_gl_monthly` (measured): Abha GL inventory 147.52M posted at July against 135.80M Fusion stock value; Jazan 9.42M posted against 10.45M; Khamis and Madinah have no posted GL inventory; `accounted_share` is 0 or near 0 from July in every branch.

Record each monitor's row count and `select * from gold.rec_inventory_gl_monthly order by 1, 2` for Task 13.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation/ hnh_dwh/tests/hnh/
git commit -m "Add stock interface and inventory-GL reconciliation and the supply monitors" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Documentation, full build and measurements

**Files:**
- Create: `docs/reconciliation_phase5.md`
- Modify: `docs/receiving_project_config.md`, `docs/superpowers/specs/2026-10-06-hnh-dwh-phase5-supply-chain-design.md` (section 11 "Changes during implementation", only if anything changed while implementing)

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: `ERROR=0`. Note PASS, WARN and the duration (Phase 4: PASS=847 WARN=38 ERROR=0 in about 12.5 minutes; Phase 5 adds about 15–25 minutes). If a test errors, report BLOCKED with the node and error (do not change models in this task). Record the build's peak memory: `select formatReadableSize(max(memory_usage)), argMax(substring(query, 1, 120), memory_usage) from system.query_log where event_time > now() - interval 2 hour and type = 'QueryFinish'`.

- [ ] **Step 2: Measure**

Through `ch_env`, record: row counts of every supply model; `fact_stock_movement` by branch, source and gap flag (Task 8 table); consumption cost by branch and year (`sum(consumption_cost)` where `is_consumption = 1`); patient-consumption link rate and margin by branch and year; month-end stock value by branch and month (`fact_stock_monthly`, `is_expiry_store = 0`); `rec_stock_interface_daily` gap share by branch for the last 30 closed days; `rec_inventory_gl_monthly` for 2026; `rec_purchase_ap_monthly` for 2026; `rec_consumption_charge_monthly` for 2026; each monitor's row count from the build.

- [ ] **Step 3: Write `docs/reconciliation_phase5.md`**

Sections (fill every number from Step 2; no placeholders left):
1. **Stock lines and the cutover (`gold.fact_stock_movement`)** — rows by branch and source; the go-live dates of `map_scm_cutover`; lines taken from Fusion, gap-filled from Oasis, Fusion-only; the 22,503 batch postings left out from the go-live and why (they echo Fusion PO receipts); integration rows without a reference (38,406) and why they are left out.
2. **Fusion interface gap (`gold.rec_stock_interface_daily`)** — gap share by branch over the last 30 closed days; Jazan's fall from about 78% coverage in mid-July to 15–20% in late September (open item O-P5-1).
3. **Patient consumption against the charge (`gold.rec_consumption_charge_monthly`)** — link rate, cost, revenue and margin by branch and year; medication charges without a cost.
4. **Stock against the GL (`gold.rec_inventory_gl_monthly`)** — Fusion stock value, posted and including-unposted GL inventory (115*), accounted share of cost distributions, difference; not expected to tie from July 2026 (O-P5-3); Abha carries CEFODOX (O-P5-2).
5. **Purchasing against AP (`gold.rec_purchase_ap_monthly`)** — received value against PO-matched AP; non-PO AP spend.
6. **Month-end stock sources** — which branch-months come from `snapshot`, `derived`, `oasis_batch`, `fusion_valuation`; that `snapshot` and `derived` appear only after `default.bal_product_base` is loaded and the next build has run (O-P5-5); Muhayil May–July is not reliable (O-P5-7).
7. **Monitors at first build** — table of the ten supply monitors with row counts and a one-line note each.
8. **Known data findings** — CREDITAR excluded (with the measured amounts), Oasis units vs Fusion packs (the crosswalk factor), lines posted twice in Fusion, error valuation layers, the store and item-group maps awaiting review (O-P5-4: 228 Oasis stores Unmapped, 945 Oasis and 612 Fusion stores with unified department Not Mapped).

- [ ] **Step 4: Update `docs/receiving_project_config.md`**

1. Under "Add to `dbt/dbt_project.yml`" `vars:` add `hnh_fusion_inventory_start: "2026-02-01"`, `hnh_fusion_item_master_org_id: 300000005019401` and `hnh_stock_month_end_last: ""`, and change "add the ten `hnh_` vars" to "add the thirteen `hnh_` vars".
2. In "How the models read Fusion" add the supply-chain tables now read through `hnh_fusion_source`: `dim_inventory_org`, `dim_subinventory`, `dim_item`, `dim_item_category`, `dim_inv_transaction_type`, `dim_lot`, `fact_inventory_transaction`, `fact_inventory_transaction_lot`, `fact_inventory_valuation`, `fact_inventory_onhand`, `fact_cost_distribution`, `fact_po_distribution`, `fact_po_schedule`, `dim_po_line_type`, `fact_receipt_transaction`, `fact_requisition_distribution` (all have models of those names in `models/fusion/`).
3. In "How the models read Oasis" add that the supply-chain staging reads `doc`, `docl`, `docl_by_serial`, `product_base`, `bintran`, `control_contexts_data` and `delivery_lines` through `hnh_oasis_source` (all have `oasis_lake` models on the server).
4. In "Aliased models" add: `hnh_dim_item` is built into `gold.dim_item` (the project's Fusion `dim_item` model exists); `hnh_dim_supplier` now also holds Oasis supplier accounts (`source_system = 'oasis'`).
5. In "Reference tables that must exist in `default`" add `map_scm_cutover` (one row per branch: inventory go-live date and first Fusion purchasing month; set Alrabwah's and Head Office's go-live dates when they move, O-P5-6), `map_store_department` (drafted by `scripts/draft_store_department_map.py`) and `map_item_group` (drafted by `scripts/draft_item_group_map.py`), and say that `bal_product_base` is optional: until the user loads the old warehouse's daily snapshots (columns `BRANCH_ID`, `C_ID`, `PRODUCT_CODE`, `Snapshot_timestamp`, `QTY_ON_HAND`, `AVERAGE_COST`; other names are set in the `cols` dict at the top of `stg_ref__stock_snapshot.sql`), `stg_ref__stock_snapshot` is empty and month-end stock starts at 2026-08-31; the next `dbt build` after the load adds the snapshot and derived months.
6. Append to "Notes for the SSAS model" (spec 9):
   - Put `fact_stock_movement`, `fact_patient_consumption`, `fact_stock_monthly`, `fact_purchase_line` and `fact_goods_receipt` in a finance and supply-chain perspective and role; they carry cost and purchase prices. Every one joins `dim_branch`, so branch row-level security applies; `fact_patient_consumption` carries keys only.
   - Consumption = Σ `consumption_cost` / `consumption_quantity` (positive) of `fact_stock_movement` where `is_consumption = 1`; transfers move stock but are never consumption; opening balances are never receipts or consumption. Department consumption slices this by `dim_store` (store type, unified department) and `dim_item` (item group).
   - `fact_stock_monthly` is a snapshot: use the last month-end of the selection or an average, never a sum across months; filter `is_expiry_store = 0` for stock KPIs; `is_closed_month = 0` is the current month. Days of stock = stock value ÷ (the month's consumption cost ÷ days in month); turnover = 12 months' consumption cost ÷ average month-end stock value.
   - Every movement, stock and purchase row has `source_system`; `is_fusion_gap = 1` marks Oasis lines that Fusion has not received yet; a gap-filled line moves to Fusion on a later build without changing its date.
   - Margin = Σ `revenue_amount` − Σ `consumption_cost` over `fact_patient_consumption` rows with `is_linked_to_charge = 1`; revenue is on one line per charge line, so never average or repeat it.
   - Costs are as recorded (CEFODOX in Abha at 6,241,137 SAR per bottle); check `warn_unit_cost_outliers` before publishing a month.
   - Quantities are in the item's primary unit (Fusion primary unit for Fusion-mapped items, Oasis base unit otherwise); purchase quantities are in the ordering unit (`uom_code`) — compare purchase prices per item and supplier within one `source_system`.
   - ABC class, slow-moving, near-expiry, fill rate, lead time, last PO price and price change follow spec 7; `hnh_abc_class` gives the A/B/C thresholds (0.80 / 0.95).
7. Under "Deployment checklist" step 6, add the Phase 5 build totals from Step 1.

- [ ] **Step 5: Record changes in the spec**

If any rule or name changed while implementing, add `## 11. Changes during implementation (<date>)` to the spec, one sentence per change; otherwise skip.

- [ ] **Step 6: Commit**

```bash
git add docs/reconciliation_phase5.md docs/receiving_project_config.md docs/superpowers/specs/2026-10-06-hnh-dwh-phase5-supply-chain-design.md
git commit -m "Document Phase 5 hand-off and supply-chain reconciliation" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
