# Order Fulfilment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one order-line fact (`gold.fact_order_line`) that measures order leakage (ordered but never charged), order-to-delivery turnaround and ordering patterns. It replaces the old *Order Fulfillment* report's `mv_orders_fulfillment`, with that view's defects corrected.

**Architecture:** Five layers.
1. Staging views over `oasis.orders_master`, `order_lines` and `generics`, plus a reference package list.
2. `int_order_line_base` (table): one row per order line, with its header, episode care type and payer, IOS category and a per-line summary of live charges.
3. `int_order_line` (table): applies the cross-line rules (alternatives, same-generic substitutes, package exclusion, statuses and legacy fields).
4. `gold.fact_order_line`: adds the conformed keys.
5. `rec_orders_monthly` and four warn monitors: reconciliation and data checks.

**Tech Stack:** dbt-core 1.11 and dbt-clickhouse 1.9 on ClickHouse 26.5. Models are run through `python scripts/run_dbt.py …`.

**Spec:** `docs/superpowers/specs/2026-10-05-hnh-dwh-order-fulfilment-design.md`. Its parents are `2026-10-01-hnh-dwh-gold-layer-design.md` and `2026-10-04-hnh-dwh-phase2-revenue-cycle-design.md`.

## Global Constraints

- Everything lives under `hnh/` folders. Macros are `hnh_` prefixed. No dbt packages, no seeds, no CSVs in git (`static_mappings/` and `powerbi_tmdl/` are git-ignored).
- Read Oasis tables only through `{{ hnh_oasis_source('<table>') }}` and read them with `final`.
- Never use the machine-wide `CLICKHOUSE_PASSWORD`; it belongs to another server. Connect through `scripts/ch_env.py` (`from ch_env import client`).
- Patient PII never reaches gold: `orders_master.patient_name` is never selected.
- Every model that joins ends with `{{ hnh_settings() }}` (`join_use_nulls = 1`).
- Surrogate keys use `hnh_surrogate_key([...])`, which returns -1 when any part is null. Sort keys are non-Nullable and start with the branch.
- **History window:** `order_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')` and `toDate(order_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))`.
- **Live charge:** `stg_oasis__charges.cancel_flag is null` (Phase 2 rule R1).
- **Unit tests:**
  - Unit tests with `format: sql` must mock every `ref` the model uses.
  - All expected rows of a unit test must have the same keys, or ClickHouse raises error 53.
  - Unit tests go in `_*_unit_tests.yml` files.
- **ClickHouse gotchas:**
  - An alias that equals a column name *inside an aggregate* raises error 184; pick another alias.
  - `x.*` after a join yields qualified names, so list columns explicitly.
  - `final` is a keyword.
- **Commits:** every commit message ends with a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **User decisions (spec section 1):**
  - Delivered = at least one live charge.
  - All care types stay in the fact. Leak KPIs exclude inpatient.
  - A substitute counts only when it was charged.
  - Packages: a flag in the fact, with the included list held as reference data.
  - Both lines and units are measured.
  - One turnaround measure: order to first delivery.
  - Status A stays out of leak scope.
- **Plan refinements to the spec** (Task 8 records them in the spec):
  - The old view lists **46** included package names, not 45.
  - The fact carries the raw `urgency_code` (values R, S, H, A; meaning unconfirmed) instead of `is_urgent`.
  - The intermediate layer is split into `int_order_line_base` and `int_order_line`. Order lines are joined to charges once, and the cross-line rules then run over a materialised table.
  - `rec_orders_monthly` names the unit columns `scope_units_ordered` and `scope_units_delivered`, to avoid error 184.
  - `warn_unresolved_order_packages` lists names that match a `PK` product in **no** branch.

## Review Focus

1. **A split charge or several delivery lines:** units and amounts must be counted once per delivery line, not once per charge row. A purchaser and patient split has two live rows on one delivery line. Pinned by Task 4 unit test, line 1.
2. **An order line whose header row is missing:** it must be kept, with `Unknown` care type and the -1 episode and patient keys. Pinned by Task 4 unit test, line 3.
3. **The same generic in another episode** must not count as a substitute. Pinned by Task 5 unit test, line 15.
4. **Delivery recorded before the order time:** the negative minutes are kept, not nulled. Pinned by Task 5 unit test, line 8, and monitored by `warn_negative_order_turnaround`.
5. **A line whose own order time is null:** the header's `order_at` decides the window. A header before the window excludes the line. Pinned by Task 4 unit test, lines 5 and 6.

---

### Task 1: Reference list of included packages

**Files:**
- Create (git-ignored, not committed): `static_mappings/order_fulfilment_packages.csv`
- Modify: `scripts/load_reference_data.py` (add an entry to `SMALL_TABLES`)
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`, `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__order_fulfilment_packages.sql`

**Interfaces:**
- Produces `stg_ref__order_fulfilment_packages(package_description String)`: upper-cased and trimmed, one row per included package, 46 rows.

- [ ] **Step 1: Extract the 46 names from the old view into the CSV**

From the repo root, run the following Python script (save it to your scratchpad first). It reads `vw_excluded_pakages_order_fulfillment` from `old_dwh_views_definition.csv` and writes the list, un-escaping the SQL backslashes. The names contain non-breaking spaces (`\xa0`) and double quotes; keep them byte for byte.

```python
import csv, re
csv.field_size_limit(10**9)
q = next(r[3] for r in csv.reader(open("old_dwh_views_definition.csv", encoding="utf-8", errors="replace"))
         if r[1] == "vw_excluded_pakages_order_fulfillment")
body = q.split("NOT IN (", 1)[1].rsplit("))", 1)[0]
names = [n.replace(chr(92) * 2, chr(92)) for n in re.findall(r"'((?:[^'\\]|\\.)*)'", body)]
assert len(names) == 46 and len(set(names)) == 46, len(names)
with open("static_mappings/order_fulfilment_packages.csv", "w", encoding="utf-8", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["DESCRIPTION"])
    for n in names:
        w.writerow([n])
print("wrote", len(names))
```

Expected: `wrote 46`. Confirm the file is ignored: `git check-ignore -v static_mappings/order_fulfilment_packages.csv` prints a `.gitignore` rule.

- [ ] **Step 2: Add the loader entry**

In `scripts/load_reference_data.py`, add this entry to the `SMALL_TABLES` dict, after `"map_nphies_reason"`:

```python
    "map_order_fulfilment_packages": (
        "order_fulfilment_packages.csv",
        [("DESCRIPTION", "String", s)],
        "DESCRIPTION",
    ),
```

- [ ] **Step 3: Load it once**

Run: `python scripts/load_reference_data.py --only map_order_fulfilment_packages`
Expected: `default.map_order_fulfilment_packages: loaded 46 -> 46 rows in table`.

- [ ] **Step 4: Source, staging model and test**

Append `      - name: map_order_fulfilment_packages` to the `reference` source's `tables:` list in `_reference__sources.yml`.

Create `stg_ref__order_fulfilment_packages.sql`:

```sql
-- Packages the old Order Fulfillment report kept although their category is PK
-- (vw_excluded_pakages_order_fulfillment). Every other PK product is excluded from leak scope.
select distinct upper(trimBoth(DESCRIPTION)) as package_description
from {{ source('reference', 'map_order_fulfilment_packages') }}
where trimBoth(DESCRIPTION) != ''
```

Append to `_reference__models.yml` under `models:`:

```yaml
  - name: stg_ref__order_fulfilment_packages
    columns:
      - name: package_description
        tests: [unique, not_null]
```

- [ ] **Step 5: Build**

Run: `python scripts/run_dbt.py build --select stg_ref__order_fulfilment_packages --no-partial-parse`
Expected: PASS (model plus 2 tests). Then check that the names resolve. Read-only query through `scripts/ch_env.py`:

```sql
select count() from stg.stg_ref__order_fulfilment_packages p
where p.package_description in (
    select upper(trimBoth(si.description)) from stg.stg_oasis__service_items si where si.description is not null)
```

Report the number that match at least one service-item description (expected: most of the 46).

- [ ] **Step 6: Commit** (the CSV is not committed)

```bash
git add scripts/load_reference_data.py hnh_dwh/models/hnh/staging/reference
git commit -m "Add the order fulfilment package list as reference data"
```

---

### Task 2: Order staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`, `_oasis__models.yml`
- Create: `hnh_dwh/models/hnh/staging/oasis/stg_oasis__orders.sql`, `stg_oasis__order_lines.sql`, `stg_oasis__generics.sql`

**Interfaces:**
- Produces `stg_oasis__orders`:

  | Column | Type |
  |---|---|
  | `branch_id` | UInt8 |
  | `master_order_no` | Int64 |
  | `patient_id` | Nullable(Int64) |
  | `episode_no` | Nullable(Int64) |
  | `admission_no` | Nullable(Int64) |
  | `orderer_staff_id` | Nullable(String) |
  | `ordered_at` | Nullable(DateTime('Asia/Riyadh')) |
  | `order_status` | Nullable(String) |
  | `attendance_type` | Nullable(String) |
  | `service_dept` | Nullable(Int64) |
  | `updated_at` | as in source |

- Produces `stg_oasis__order_lines`:

  | Column | Type |
  |---|---|
  | `branch_id` | UInt8 |
  | `order_line` | Int64 |
  | `master_order_no` | Nullable(Int64) |
  | `ios` | Nullable(Int64) |
  | `generic_id` | Nullable(Int64) |
  | `units_ordered` | Float64 |
  | `units_given` | Float64 |
  | `units_scheduled` | Float64 |
  | `units_completed` | Float64 |
  | `line_status_code` | Nullable(String) |
  | `status_reason` | Nullable(String) |
  | `original_order_line` | Nullable(Int64) |
  | `urgent_flag` | Nullable(String) |
  | `order_work_entity` | Nullable(Int64) |
  | `line_ordered_at` | Nullable(DateTime('Asia/Riyadh')) |
  | `std_price` | Float64 |
  | `updated_at` | as in source |

- Produces `stg_oasis__generics(branch_id UInt8, generic_id Int64, generic_name Nullable(String))`.

- [ ] **Step 1: Add the sources**

In `_oasis__sources.yml`, add to the `oasis` source's `tables:` list, keeping the file's alphabetical order where it has one:

```yaml
      - name: orders_master
      - name: order_lines
      - name: generics
```

- [ ] **Step 2: Add the uniqueness tests first**

Append to `_oasis__models.yml` under `models:`:

```yaml
  - name: stg_oasis__orders
    tests:
      - hnh_unique_combination:
          columns: [branch_id, master_order_no]
  - name: stg_oasis__order_lines
    tests:
      - hnh_unique_combination:
          columns: [branch_id, order_line]
  - name: stg_oasis__generics
    tests:
      - hnh_unique_combination:
          columns: [branch_id, generic_id]
```

Run: `python scripts/run_dbt.py build --select stg_oasis__orders stg_oasis__order_lines stg_oasis__generics --no-partial-parse`
Expected: FAIL. The models do not exist yet, so dbt reports that the tests reference missing nodes.

- [ ] **Step 3: Write the three models**

`stg_oasis__orders.sql` (`patient_name` is deliberately not selected):

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(master_order_no)                    as master_order_no,
    {{ hnh_id('patient_id') }}                  as patient_id,
    {{ hnh_id('episode_no') }}                  as episode_no,
    {{ hnh_id('admission_no') }}                as admission_no,
    {{ hnh_code('orderer_staff_id') }}          as orderer_staff_id,
    {{ hnh_ksa_wall_clock('order_date') }}      as ordered_at,
    {{ hnh_code('status') }}                    as order_status,
    {{ hnh_code('attendance_type') }}           as attendance_type,
    {{ hnh_id('service_dept') }}                as service_dept,
    recorded_updated_at                         as updated_at
from {{ hnh_oasis_source('orders_master') }} final
```

`stg_oasis__order_lines.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(order_line)                         as order_line,
    {{ hnh_id('master_order_no') }}             as master_order_no,
    {{ hnh_id('ios') }}                         as ios,
    {{ hnh_id('generic_id') }}                  as generic_id,
    toFloat64(ifNull(units_ordered, 0))         as units_ordered,
    toFloat64(ifNull(units_given, 0))           as units_given,
    toFloat64(ifNull(units_scheduled, 0))       as units_scheduled,
    toFloat64(ifNull(units_completed, 0))       as units_completed,
    {{ hnh_code('status') }}                    as line_status_code,
    {{ hnh_str('status_reason') }}              as status_reason,
    {{ hnh_id('original_order_line') }}         as original_order_line,
    {{ hnh_code('urgent_flag') }}               as urgent_flag,
    {{ hnh_id('order_work_entity') }}           as order_work_entity,
    {{ hnh_ksa_wall_clock('line_order_date') }} as line_ordered_at,
    toFloat64(ifNull(std_price, 0))             as std_price,
    recorded_updated_at                         as updated_at
from {{ hnh_oasis_source('order_lines') }} final
```

`stg_oasis__generics.sql`:

```sql
select
    toUInt8(branch_id)              as branch_id,
    toInt64(generic_id)             as generic_id,
    {{ hnh_str('generic_name') }}   as generic_name
from {{ hnh_oasis_source('generics') }} final
```

If `final` fails on one of these source tables (it is not a ReplacingMergeTree), drop `final` for that table only. Say so in the report, together with the duplicate count from the uniqueness test.

- [ ] **Step 4: Build and check**

Run: `python scripts/run_dbt.py build --select stg_oasis__orders stg_oasis__order_lines stg_oasis__generics --no-partial-parse`
Expected: PASS (3 views, 3 tests).

Then run these read-only checks and report them:
- the row count of each view;
- for branch 1 in 2026, the count of `line_status_code` values (expect D, R, C, P, A);
- the share of `orderer_staff_id` values that exist in `gold.dim_staff`, via `hnh_surrogate_key` on `(branch_id, staff_id)`. Compare `cityHash64`-based keys by querying `gold.dim_staff` for `staff_id` directly: `select countIf(s.staff_id is not null)/count() from (select branch_id, orderer_staff_id from stg.stg_oasis__orders where branch_id = 1 and ordered_at >= '2026-06-01' limit 100000) o left join gold.dim_staff s on s.branch_key = o.branch_id and s.staff_id = o.orderer_staff_id settings join_use_nulls = 1`. Adjust the column names to `dim_staff`'s real ones.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis
git commit -m "Stage Oasis orders, order lines and generics"
```

---

### Task 3: Order rule macros

**Files:**
- Modify: `hnh_dwh/macros/hnh/hnh_rules_flow.sql` (append)
- Create: `hnh_dwh/tests/hnh/assert_hnh_order_macros.sql`

**Interfaces:**
- Produces `hnh_order_line_status(status_code)`, which returns one of `Delivered`, `Ordered`, `Cancelled`, `Not applicable` or `Unknown`.
- Produces `hnh_order_category(product_category_code)`, which returns one of `Package`, `Lab`, `Radiology`, `Consultation`, `Pharmacy` or `Others`. It uses `hnh_is_medication` from `hnh_rules_revenue.sql`.
- Produces `hnh_order_fulfilment_status(line_status, has_live_charge, has_charged_alternative, has_charged_substitute)`, which returns one of `Cancelled`, `Not applicable`, `Delivered`, `Delivered by alternative`, `Delivered by substitute` or `Undelivered`.

- [ ] **Step 1: Write the failing macro test**

`tests/hnh/assert_hnh_order_macros.sql`:

```sql
-- Order rules (spec section 5). Each branch returns a row only when a rule is wrong.
select 'order line status wrong' as failure
where {{ hnh_order_line_status("'D'") }} != 'Delivered'
   or {{ hnh_order_line_status("'R'") }} != 'Ordered'
   or {{ hnh_order_line_status("'O'") }} != 'Ordered'
   or {{ hnh_order_line_status("'C'") }} != 'Cancelled'
   or {{ hnh_order_line_status("'P'") }} != 'Not applicable'
   or {{ hnh_order_line_status("'Q'") }} != 'Not applicable'
   or {{ hnh_order_line_status("'X'") }} != 'Not applicable'
   or {{ hnh_order_line_status("'A'") }} != 'Unknown'
   or {{ hnh_order_line_status("cast(null as Nullable(String))") }} != 'Unknown'

union all
select 'order category wrong'
where {{ hnh_order_category("'PK'") }} != 'Package'
   or {{ hnh_order_category("'LAB'") }} != 'Lab'
   or {{ hnh_order_category("'RAD'") }} != 'Radiology'
   or {{ hnh_order_category("'CON'") }} != 'Consultation'
   or {{ hnh_order_category("'PH'") }} != 'Pharmacy'
   or {{ hnh_order_category("'MLK'") }} != 'Pharmacy'
   or {{ hnh_order_category("'SUR'") }} != 'Others'
   or {{ hnh_order_category("cast(null as Nullable(String))") }} != 'Others'

union all
select 'fulfilment status wrong'
where {{ hnh_order_fulfilment_status("'Cancelled'", "toUInt8(1)", "toUInt8(0)", "toUInt8(0)") }} != 'Cancelled'
   or {{ hnh_order_fulfilment_status("'Not applicable'", "toUInt8(1)", "toUInt8(0)", "toUInt8(0)") }} != 'Not applicable'
   or {{ hnh_order_fulfilment_status("'Unknown'", "toUInt8(0)", "toUInt8(0)", "toUInt8(0)") }} != 'Not applicable'
   or {{ hnh_order_fulfilment_status("'Ordered'", "toUInt8(1)", "toUInt8(1)", "toUInt8(1)") }} != 'Delivered'
   or {{ hnh_order_fulfilment_status("'Ordered'", "toUInt8(0)", "toUInt8(1)", "toUInt8(1)") }} != 'Delivered by alternative'
   or {{ hnh_order_fulfilment_status("'Ordered'", "toUInt8(0)", "toUInt8(0)", "toUInt8(1)") }} != 'Delivered by substitute'
   or {{ hnh_order_fulfilment_status("'Delivered'", "toUInt8(0)", "toUInt8(0)", "toUInt8(0)") }} != 'Undelivered'
```

Run: `python scripts/run_dbt.py test --select assert_hnh_order_macros --no-partial-parse`
Expected: ERROR, because the macros are undefined (compilation error naming `hnh_order_line_status`).

- [ ] **Step 2: Append the macros to `hnh_rules_flow.sql`**

```sql
{# Oasis order line status. P, Q and X are pending/queued/excluded states the old report left out;
   anything else unrecognised (e.g. A) is Unknown and stays out of leak scope. #}
{% macro hnh_order_line_status(status_code) -%}
multiIf({{ status_code }} = 'D', 'Delivered',
        {{ status_code }} in ('R', 'O'), 'Ordered',
        {{ status_code }} = 'C', 'Cancelled',
        {{ status_code }} in ('P', 'Q', 'X'), 'Not applicable',
        'Unknown')
{%- endmacro %}

{# Category of an ordered product, as the old Order Fulfillment report grouped it. #}
{% macro hnh_order_category(product_category_code) -%}
multiIf(ifNull({{ product_category_code }}, '') = 'PK', 'Package',
        ifNull({{ product_category_code }}, '') = 'LAB', 'Lab',
        ifNull({{ product_category_code }}, '') = 'RAD', 'Radiology',
        ifNull({{ product_category_code }}, '') = 'CON', 'Consultation',
        {{ hnh_is_medication(product_category_code, "cast(null as Nullable(String))") }} = 1, 'Pharmacy',
        'Others')
{%- endmacro %}

{# Fulfilment of an order line: its own live charge first, then a charged alternative, then a
   charged same-generic substitute in the same episode (pharmacy). #}
{% macro hnh_order_fulfilment_status(line_status, has_live_charge, has_charged_alternative, has_charged_substitute) -%}
multiIf({{ line_status }} = 'Cancelled', 'Cancelled',
        {{ line_status }} in ('Not applicable', 'Unknown'), 'Not applicable',
        {{ has_live_charge }} = 1, 'Delivered',
        {{ has_charged_alternative }} = 1, 'Delivered by alternative',
        {{ has_charged_substitute }} = 1, 'Delivered by substitute',
        'Undelivered')
{%- endmacro %}
```

- [ ] **Step 3: Run the test**

Run: `python scripts/run_dbt.py test --select assert_hnh_order_macros --no-partial-parse`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_flow.sql hnh_dwh/tests/hnh/assert_hnh_order_macros.sql
git commit -m "Add order status, category and fulfilment rule macros"
```

---

### Task 4: int_order_line_base

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/int_order_line_base.sql`
- Modify: `hnh_dwh/models/hnh/intermediate/patient_flow/_patient_flow_unit_tests.yml`, `_patient_flow__models.yml`

**Interfaces:**
- Consumes the Task 2 staging models, `stg_oasis__charges(branch_id, delivery_line, cancel_flag, units_delivered, price_paid_purchaser, delivered_at)`, `stg_oasis__delivery_lines(branch_id, delivery_line, order_line)`, `stg_oasis__ios_master(branch_id, ios, ios_main, product_category_code)`, `stg_oasis__service_items(branch_id, ios_main, description, product_category_code)` and `int_episode(branch_id, patient_id, episode_no, care_type, purchaser_code)`.
- Produces `int_order_line_base`, one row per `(branch_id, order_line)` in the window:

  | Column | Type |
  |---|---|
  | `branch_id` | UInt8 |
  | `order_line` | Int64 |
  | `master_order_no` | Nullable(Int64) |
  | `patient_id` | Nullable(Int64) |
  | `episode_no` | Nullable(Int64) |
  | `admission_no` | Nullable(Int64) |
  | `orderer_staff_id` | Nullable(String) |
  | `order_work_entity` | Nullable(Int64) |
  | `ios` | Nullable(Int64) |
  | `generic_id` | Nullable(Int64) |
  | `generic_name` | Nullable(String) |
  | `order_at` | Nullable(DateTime('Asia/Riyadh')); never null in the table |
  | `urgency_code` | Nullable(String) |
  | `status_reason` | Nullable(String) |
  | `line_status_code` | Nullable(String) |
  | `original_order_line` | Nullable(Int64) |
  | `units_ordered` | Float64 |
  | `std_price` | Float64 |
  | `product_category_code` | Nullable(String) |
  | `service_description_upper` | Nullable(String) |
  | `care_type` | String |
  | `episode_purchaser_code` | Int64 |
  | `live_charge_count` | UInt64 |
  | `has_live_charge` | UInt8 |
  | `units_delivered` | Float64 |
  | `charged_amount` | Float64 |
  | `first_delivered_at` | Nullable(DateTime('Asia/Riyadh')) |

- [ ] **Step 1: Write the failing unit test**

Append to `_patient_flow_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: int_order_line_base_summarises_live_charges_once_per_delivery_line
    description: >
      Line 1 has two delivery lines: 9001 is split between purchaser and patient (two live rows,
      2 units each) and 9011 has one live row and one cancelled row. Units count once per delivery
      line (2 + 1), amounts add up over live rows (60 + 40 + 25). Line 2 has only a cancelled charge.
      Line 3's order header is missing. Line 4 is an inpatient order of an episode int_episode does
      not know, with its category only on the service item. Line 5 has no own order time and a
      header before the window (excluded). Line 6 has no own order time and takes the header's.
    model: int_order_line_base
    given:
      - input: ref('stg_oasis__order_lines')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(ol) as order_line, toNullable(toInt64(mo)) as master_order_no,
                 toNullable(toInt64(ios)) as ios,
                 if(gen = 0, cast(null as Nullable(Int64)), toNullable(toInt64(gen))) as generic_id,
                 toFloat64(1) as units_ordered, toFloat64(0) as units_given, toFloat64(0) as units_scheduled,
                 toFloat64(0) as units_completed, toNullable('R') as line_status_code,
                 cast(null as Nullable(String)) as status_reason, cast(null as Nullable(Int64)) as original_order_line,
                 toNullable('R') as urgent_flag, toNullable(toInt64(700)) as order_work_entity,
                 if(oa = '', cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime(oa, 'Asia/Riyadh'))) as line_ordered_at,
                 toFloat64(10) as std_price
          from values('ol UInt32, mo UInt32, ios UInt32, gen UInt32, oa String',
              (1, 10, 501, 0, '2026-06-01 09:00:00'), (2, 10, 501, 0, '2026-06-01 09:00:00'),
              (3, 11, 501, 0, '2026-06-01 09:00:00'), (4, 12, 503, 77, '2026-06-01 09:00:00'),
              (5, 13, 501, 0, ''), (6, 14, 501, 0, ''))
      - input: ref('stg_oasis__orders')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(mo) as master_order_no, toNullable(toInt64(pat)) as patient_id,
                 toNullable(toInt64(ep)) as episode_no, cast(null as Nullable(Int64)) as admission_no,
                 toNullable('D1') as orderer_staff_id, toNullable(toDateTime(oa, 'Asia/Riyadh')) as ordered_at,
                 toNullable('R') as order_status, toNullable(att) as attendance_type,
                 cast(null as Nullable(Int64)) as service_dept
          from values('mo UInt32, pat UInt32, ep UInt32, oa String, att String',
              (10, 100, 1, '2026-06-01 08:55:00', 'O'), (12, 200, 9, '2026-06-01 08:55:00', 'I'),
              (13, 100, 1, '2021-12-31 10:00:00', 'O'), (14, 100, 1, '2026-06-02 08:00:00', 'O'))
      - input: ref('stg_oasis__delivery_lines')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(dl) as delivery_line, cast(null as Nullable(Int64)) as master_delivery_no,
                 toNullable(toInt64(ol)) as order_line
          from values('dl UInt32, ol UInt32', (9001, 1), (9011, 1), (9002, 2))
      - input: ref('stg_oasis__charges')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toNullable(toInt64(dl)) as delivery_line,
                 if(cf = '', cast(null as Nullable(String)), toNullable(cf)) as cancel_flag,
                 toFloat64(u) as units_delivered, toFloat64(p) as price_paid_purchaser,
                 toNullable(toDateTime(at, 'Asia/Riyadh')) as delivered_at
          from values('dl UInt32, cf String, u Float64, p Float64, at String',
              (9001, '', 2, 60, '2026-06-01 09:30:00'), (9001, '', 2, 40, '2026-06-01 09:30:00'),
              (9011, '', 1, 25, '2026-06-01 09:45:00'), (9011, 'C', 1, 99, '2026-06-01 09:20:00'),
              (9002, 'C', 1, 50, '2026-06-01 09:40:00'))
      - input: ref('stg_oasis__ios_master')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(ios) as ios, toNullable(toInt64(im)) as ios_main,
                 if(cat = '', cast(null as Nullable(String)), toNullable(cat)) as product_category_code
          from values('ios UInt32, im UInt32, cat String', (501, 5010, 'LAB'), (503, 5030, ''))
      - input: ref('stg_oasis__service_items')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(im) as ios_main, toNullable(d) as description,
                 toNullable(cat) as product_category_code
          from values('im UInt32, d String, cat String', (5010, 'cbc ', 'LAB'), (5030, 'Paracetamol 500', 'PH'))
      - input: ref('stg_oasis__generics')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(77) as generic_id, toNullable('PARACETAMOL') as generic_name
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(1) as episode_no,
                 'OP' as care_type, toInt64(300) as purchaser_code
    expect:
      rows:
        - {order_line: 1, patient_id: 100, order_at: '2026-06-01 09:00:00', care_type: OP, episode_purchaser_code: 300, product_category_code: LAB, service_description_upper: CBC, generic_name: null, live_charge_count: 3, has_live_charge: 1, units_delivered: 3, charged_amount: 125, first_delivered_at: '2026-06-01 09:30:00'}
        - {order_line: 2, patient_id: 100, order_at: '2026-06-01 09:00:00', care_type: OP, episode_purchaser_code: 300, product_category_code: LAB, service_description_upper: CBC, generic_name: null, live_charge_count: 0, has_live_charge: 0, units_delivered: 0, charged_amount: 0, first_delivered_at: null}
        - {order_line: 3, patient_id: null, order_at: '2026-06-01 09:00:00', care_type: Unknown, episode_purchaser_code: 9999, product_category_code: LAB, service_description_upper: CBC, generic_name: null, live_charge_count: 0, has_live_charge: 0, units_delivered: 0, charged_amount: 0, first_delivered_at: null}
        - {order_line: 4, patient_id: 200, order_at: '2026-06-01 09:00:00', care_type: IP, episode_purchaser_code: 9999, product_category_code: PH, service_description_upper: PARACETAMOL 500, generic_name: PARACETAMOL, live_charge_count: 0, has_live_charge: 0, units_delivered: 0, charged_amount: 0, first_delivered_at: null}
        - {order_line: 6, patient_id: 100, order_at: '2026-06-02 08:00:00', care_type: OP, episode_purchaser_code: 300, product_category_code: LAB, service_description_upper: CBC, generic_name: null, live_charge_count: 0, has_live_charge: 0, units_delivered: 0, charged_amount: 0, first_delivered_at: null}
```

Run: `python scripts/run_dbt.py test --select "int_order_line_base,test_type:unit" --no-partial-parse`
Expected: FAIL. The model does not exist yet.

- [ ] **Step 2: Write `int_order_line_base.sql`**

```sql
{{ config(order_by='(branch_id, order_line)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with lines as (
    -- An order line with its header. The line's own order time wins; the header's fills the gap.
    select
        l.branch_id                                     as branch_id,
        l.order_line                                    as order_line,
        l.master_order_no                               as master_order_no,
        l.ios                                           as ios,
        l.generic_id                                    as generic_id,
        l.units_ordered                                 as units_ordered,
        l.std_price                                     as std_price,
        l.line_status_code                              as line_status_code,
        l.status_reason                                 as status_reason,
        l.original_order_line                           as original_order_line,
        l.urgent_flag                                   as urgency_code,
        l.order_work_entity                             as order_work_entity,
        coalesce(l.line_ordered_at, o.ordered_at)       as order_at,
        o.patient_id                                    as patient_id,
        o.episode_no                                    as episode_no,
        o.admission_no                                  as admission_no,
        o.orderer_staff_id                              as orderer_staff_id,
        o.attendance_type                               as attendance_type
    from {{ ref('stg_oasis__order_lines') }} as l
    left join (
        select branch_id, master_order_no, patient_id, episode_no, admission_no, orderer_staff_id,
               ordered_at, attendance_type
        from {{ ref('stg_oasis__orders') }}
    ) as o on o.branch_id = l.branch_id and o.master_order_no = l.master_order_no
    where order_at >= {{ first_at }} and toDate(order_at) <= {{ last_day }}
),

charge_lines as (
    -- One row per delivery line that has a live charge. A charge split between purchaser and
    -- patient puts several live rows on one delivery line, so its units are taken once (max).
    select
        c.branch_id                         as branch_id,
        d.order_line                        as order_line,
        c.delivery_line                     as delivery_line,
        count()                             as live_rows,
        max(c.units_delivered)              as line_units,
        sum(c.price_paid_purchaser)         as line_amount,
        min(c.delivered_at)                 as line_first_at
    from (
        select branch_id, assumeNotNull(delivery_line) as delivery_line, units_delivered,
               price_paid_purchaser, delivered_at
        from {{ ref('stg_oasis__charges') }}
        where cancel_flag is null and delivery_line is not null and delivered_at >= {{ first_at }}
    ) as c
    inner join (
        select branch_id, delivery_line, assumeNotNull(order_line) as order_line
        from {{ ref('stg_oasis__delivery_lines') }}
        where order_line is not null
    ) as d on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
    group by c.branch_id, d.order_line, c.delivery_line
),

line_delivery as (
    select
        branch_id, order_line,
        sum(live_rows)          as live_charge_count,
        sum(line_units)         as units_delivered,
        sum(line_amount)        as charged_amount,
        min(line_first_at)      as first_delivered_at
    from charge_lines
    group by branch_id, order_line
),

ios_info as (
    select
        m.branch_id                                                     as branch_id,
        m.ios                                                           as ios,
        coalesce(m.product_category_code, si.product_category_code)     as product_category_code,
        nullIf(upper(trimBoth(ifNull(si.description, ''))), '')         as service_description_upper
    from {{ ref('stg_oasis__ios_master') }} as m
    left join {{ ref('stg_oasis__service_items') }} as si
        on si.branch_id = m.branch_id and si.ios_main = m.ios_main
)

select
    l.branch_id                                         as branch_id,
    l.order_line                                        as order_line,
    l.master_order_no                                   as master_order_no,
    l.patient_id                                        as patient_id,
    l.episode_no                                        as episode_no,
    l.admission_no                                      as admission_no,
    l.orderer_staff_id                                  as orderer_staff_id,
    l.order_work_entity                                 as order_work_entity,
    l.ios                                               as ios,
    l.generic_id                                        as generic_id,
    g.generic_name                                      as generic_name,
    l.order_at                                          as order_at,
    l.urgency_code                                      as urgency_code,
    l.status_reason                                     as status_reason,
    l.line_status_code                                  as line_status_code,
    l.original_order_line                               as original_order_line,
    l.units_ordered                                     as units_ordered,
    l.std_price                                         as std_price,
    ii.product_category_code                            as product_category_code,
    ii.service_description_upper                        as service_description_upper,
    -- The episode's care type; without a known episode, the order header's attendance type.
    if(ifNull(ep.care_type, 'Unknown') != 'Unknown', ifNull(ep.care_type, 'Unknown'),
       {{ hnh_care_type('l.attendance_type') }})        as care_type,
    ifNull(ep.purchaser_code, toInt64(9999))            as episode_purchaser_code,
    toUInt64(ifNull(ld.live_charge_count, 0))           as live_charge_count,
    toUInt8(ifNull(ld.live_charge_count, 0) > 0)        as has_live_charge,
    toFloat64(ifNull(ld.units_delivered, 0))            as units_delivered,
    toFloat64(ifNull(ld.charged_amount, 0))             as charged_amount,
    ld.first_delivered_at                               as first_delivered_at
from lines as l
left join line_delivery as ld on ld.branch_id = l.branch_id and ld.order_line = l.order_line
left join ios_info as ii on ii.branch_id = l.branch_id and ii.ios = l.ios
left join (select branch_id, generic_id, generic_name from {{ ref('stg_oasis__generics') }}) as g
    on g.branch_id = l.branch_id and g.generic_id = l.generic_id
left join (select branch_id, patient_id, episode_no, care_type, purchaser_code from {{ ref('int_episode') }}) as ep
    on ep.branch_id = l.branch_id and ep.patient_id = l.patient_id and ep.episode_no = l.episode_no
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "int_order_line_base,test_type:unit" --no-partial-parse`
Expected: PASS. If ClickHouse raises error 184, rename the clashing alias, and only that alias. A clash on an alias that equals a column inside `sum(...)` or `min(...)` is the usual cause.

- [ ] **Step 4: Model test and build**

Append to `_patient_flow__models.yml` under `models:`:

```yaml
  - name: int_order_line_base
    description: One order line in the history window with its header, episode care type and payer, IOS category and a summary of its live charges.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, order_line]
```

Run: `python scripts/run_dbt.py build --select int_order_line_base --no-partial-parse`
Expected: PASS.

Report:
- the row count;
- the build time and peak memory, from `system.query_log` (`memory_usage` of the INSERT; read-only);
- for branch 1 in June 2026, the count by `line_status_code` and `has_live_charge`. The spec's finding F3 expects all D lines charged and no C lines charged.

If peak memory goes above about 30 GiB, report DONE_WITH_CONCERNS with the figure. Do not restructure on your own.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/patient_flow
git commit -m "Summarise live charges per order line"
```

---

### Task 5: int_order_line (fulfilment rules)

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/patient_flow/int_order_line.sql`
- Modify: `_patient_flow_unit_tests.yml`, `_patient_flow__models.yml` (same folder)

**Interfaces:**
- Consumes `int_order_line_base` (Task 4), `stg_ref__order_fulfilment_packages(package_description)` (Task 1) and the Task 3 macros.
- Produces `int_order_line`, one row per `(branch_id, order_line)`:
  - **Carried from base:** `branch_id`, `order_line`, `master_order_no`, `patient_id`, `episode_no`, `admission_no`, `orderer_staff_id`, `order_work_entity`, `ios`, `generic_id`, `generic_name`, `order_at`, `urgency_code`, `status_reason`, `original_order_line`, `product_category_code`, `care_type`, `episode_purchaser_code`, `units_ordered`, `units_delivered`, `std_price`, `charged_amount`, `live_charge_count`, `first_delivered_at`.
  - **New:**

    | Column | Type |
    |---|---|
    | `ordered_value` | Float64 |
    | `order_category` | String |
    | `is_excluded_package` | UInt8 |
    | `is_inpatient` | UInt8 |
    | `is_alternative` | UInt8 |
    | `line_status` | String |
    | `has_charged_alternative` | UInt8 |
    | `has_charged_substitute` | UInt8 |
    | `fulfilment_status` | String |
    | `is_in_leak_scope` | UInt8 |
    | `is_lost` | UInt8 |
    | `is_partially_delivered` | UInt8 |
    | `order_to_delivery_minutes` | Nullable(Int64) |
    | `legacy_status` | String |
    | `legacy_in_scope` | UInt8 |
    | `legacy_is_lost` | UInt8 |

- [ ] **Step 1: Write the failing unit test**

Append to `_patient_flow_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: int_order_line_applies_fulfilment_rules
    description: >
      Episode 100-1 (OP), ordered 09:00.
      Line 1 charged; line 2 not charged.
      Line 3 not charged but its alternative 4 was; line 5 not charged and its alternative 6 not
      charged either (old rule: both delivered).
      Pharmacy lines 7 and 8 share generic 77 and only 8 was charged (3 of 5 units, delivered
      before the order time); lines 9 and 10 share generic 88 and neither was charged (old rule:
      both delivered).
      Line 11 is an included package, line 12 an excluded one.
      Line 13 is cancelled; line 14 has status A.
      Line 15 is generic 77 in another, inpatient episode (no substitute credit; old report
      excluded inpatient).
    model: int_order_line
    given:
      - input: ref('int_order_line_base')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(ol) as order_line, toNullable(toInt64(10)) as master_order_no,
                 toNullable(toInt64(pat)) as patient_id, toNullable(toInt64(ep)) as episode_no,
                 cast(null as Nullable(Int64)) as admission_no, toNullable('D1') as orderer_staff_id,
                 toNullable(toInt64(700)) as order_work_entity, toNullable(toInt64(ios)) as ios,
                 if(gen = 0, cast(null as Nullable(Int64)), toNullable(toInt64(gen))) as generic_id,
                 cast(null as Nullable(String)) as generic_name,
                 toNullable(toDateTime('2026-06-01 09:00:00', 'Asia/Riyadh')) as order_at,
                 toNullable('R') as urgency_code, cast(null as Nullable(String)) as status_reason,
                 toNullable(st) as line_status_code,
                 if(orig = 0, cast(null as Nullable(Int64)), toNullable(toInt64(orig))) as original_order_line,
                 toFloat64(uo) as units_ordered, toFloat64(10) as std_price,
                 toNullable(cat) as product_category_code, toNullable(descr) as service_description_upper,
                 ct as care_type, toInt64(9999) as episode_purchaser_code,
                 toUInt64(lc) as live_charge_count, toUInt8(lc > 0) as has_live_charge,
                 toFloat64(ud) as units_delivered, toFloat64(amt) as charged_amount,
                 if(fd = '', cast(null as Nullable(DateTime('Asia/Riyadh'))), toNullable(toDateTime(fd, 'Asia/Riyadh'))) as first_delivered_at
          from values('ol UInt32, pat UInt32, ep UInt32, ios UInt32, gen UInt32, st String, orig UInt32, uo Float64, cat String, descr String, ct String, lc UInt32, ud Float64, amt Float64, fd String',
              (1, 100, 1, 501, 0, 'D', 0, 2, 'LAB', 'CBC', 'OP', 2, 2, 100, '2026-06-01 09:30:00'),
              (2, 100, 1, 501, 0, 'R', 0, 1, 'LAB', 'CBC', 'OP', 0, 0, 0, ''),
              (3, 100, 1, 502, 0, 'R', 0, 1, 'RAD', 'XRAY', 'OP', 0, 0, 0, ''),
              (4, 100, 1, 502, 0, 'D', 3, 1, 'RAD', 'XRAY', 'OP', 1, 1, 200, '2026-06-01 10:00:00'),
              (5, 100, 1, 502, 0, 'R', 0, 1, 'RAD', 'XRAY', 'OP', 0, 0, 0, ''),
              (6, 100, 1, 502, 0, 'R', 5, 1, 'RAD', 'XRAY', 'OP', 0, 0, 0, ''),
              (7, 100, 1, 503, 77, 'R', 0, 1, 'PH', 'PARACETAMOL 500', 'OP', 0, 0, 0, ''),
              (8, 100, 1, 503, 77, 'D', 0, 5, 'PH', 'PARACETAMOL 500', 'OP', 1, 3, 30, '2026-06-01 08:50:00'),
              (9, 100, 1, 506, 88, 'R', 0, 1, 'PH', 'IBUPROFEN 400', 'OP', 0, 0, 0, ''),
              (10, 100, 1, 506, 88, 'R', 0, 1, 'PH', 'IBUPROFEN 400', 'OP', 0, 0, 0, ''),
              (11, 100, 1, 504, 0, 'R', 0, 1, 'PK', 'GENERAL CHECK UP (PROMO)', 'OP', 0, 0, 0, ''),
              (12, 100, 1, 505, 0, 'R', 0, 1, 'PK', 'OTHER PACKAGE', 'OP', 0, 0, 0, ''),
              (13, 100, 1, 501, 0, 'C', 0, 1, 'LAB', 'CBC', 'OP', 0, 0, 0, ''),
              (14, 100, 1, 501, 0, 'A', 0, 1, 'LAB', 'CBC', 'OP', 0, 0, 0, ''),
              (15, 200, 9, 503, 77, 'R', 0, 1, 'PH', 'PARACETAMOL 500', 'IP', 0, 0, 0, ''))
      - input: ref('stg_ref__order_fulfilment_packages')
        format: sql
        rows: |
          select 'GENERAL CHECK UP (PROMO)' as package_description
    expect:
      rows:
        - {order_line: 1, order_category: Lab, line_status: Delivered, fulfilment_status: Delivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 0, is_partially_delivered: 0, ordered_value: 20, order_to_delivery_minutes: 30, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 2, order_category: Lab, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Undelivered, legacy_in_scope: 1, legacy_is_lost: 1}
        - {order_line: 3, order_category: Radiology, line_status: Ordered, fulfilment_status: Delivered by alternative, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 0, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 4, order_category: Radiology, line_status: Delivered, fulfilment_status: Delivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 0, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: 60, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 5, order_category: Radiology, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 6, order_category: Radiology, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 7, order_category: Pharmacy, line_status: Ordered, fulfilment_status: Delivered by substitute, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 0, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 8, order_category: Pharmacy, line_status: Delivered, fulfilment_status: Delivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 0, is_partially_delivered: 1, ordered_value: 50, order_to_delivery_minutes: -10, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 9, order_category: Pharmacy, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 10, order_category: Pharmacy, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Delivered, legacy_in_scope: 1, legacy_is_lost: 0}
        - {order_line: 11, order_category: Package, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Undelivered, legacy_in_scope: 1, legacy_is_lost: 1}
        - {order_line: 12, order_category: Package, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 1, is_inpatient: 0, is_in_leak_scope: 0, is_lost: 0, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Undelivered, legacy_in_scope: 0, legacy_is_lost: 0}
        - {order_line: 13, order_category: Lab, line_status: Cancelled, fulfilment_status: Cancelled, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 0, is_lost: 0, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Undelivered, legacy_in_scope: 0, legacy_is_lost: 0}
        - {order_line: 14, order_category: Lab, line_status: Unknown, fulfilment_status: Not applicable, is_excluded_package: 0, is_inpatient: 0, is_in_leak_scope: 0, is_lost: 0, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Undelivered, legacy_in_scope: 1, legacy_is_lost: 1}
        - {order_line: 15, order_category: Pharmacy, line_status: Ordered, fulfilment_status: Undelivered, is_excluded_package: 0, is_inpatient: 1, is_in_leak_scope: 1, is_lost: 1, is_partially_delivered: 0, ordered_value: 10, order_to_delivery_minutes: null, legacy_status: Undelivered, legacy_in_scope: 0, legacy_is_lost: 0}
```

Line 14 is deliberate. The old view filtered only P, Q, X and cancelled, so status A was in its scope (`legacy_in_scope: 1`). The new rule keeps A out of leak scope, by the user's decision.

Run: `python scripts/run_dbt.py test --select "int_order_line,test_type:unit" --no-partial-parse`
Expected: FAIL. The model does not exist yet.

- [ ] **Step 2: Write `int_order_line.sql`**

```sql
{{ config(order_by='(branch_id, order_line)') }}

with base as (
    select * from {{ ref('int_order_line_base') }}
),

alternatives as (
    -- Lines ordered as an alternative to another line, per original line.
    select
        branch_id,
        assumeNotNull(original_order_line)  as original_line,
        count()                             as alternative_lines,
        max(has_live_charge)                as charged_alternatives
    from base
    where original_order_line is not null
    group by branch_id, original_line
),

generics as (
    -- Lines of the same generic within one episode, and how many of them were charged.
    select
        branch_id, patient_id, episode_no, generic_id,
        count()                 as generic_lines,
        sum(has_live_charge)    as charged_generic_lines
    from base
    where generic_id is not null and patient_id is not null and episode_no is not null
    group by branch_id, patient_id, episode_no, generic_id
)

select
    b.branch_id                                         as branch_id,
    b.order_line                                        as order_line,
    b.master_order_no                                   as master_order_no,
    b.patient_id                                        as patient_id,
    b.episode_no                                        as episode_no,
    b.admission_no                                      as admission_no,
    b.orderer_staff_id                                  as orderer_staff_id,
    b.order_work_entity                                 as order_work_entity,
    b.ios                                               as ios,
    b.generic_id                                        as generic_id,
    b.generic_name                                      as generic_name,
    b.order_at                                          as order_at,
    b.urgency_code                                      as urgency_code,
    b.status_reason                                     as status_reason,
    b.original_order_line                               as original_order_line,
    b.product_category_code                             as product_category_code,
    b.care_type                                         as care_type,
    b.episode_purchaser_code                            as episode_purchaser_code,
    b.units_ordered                                     as units_ordered,
    b.units_delivered                                   as units_delivered,
    b.std_price                                         as std_price,
    b.units_ordered * b.std_price                       as ordered_value,
    b.charged_amount                                    as charged_amount,
    b.live_charge_count                                 as live_charge_count,
    b.first_delivered_at                                as first_delivered_at,
    {{ hnh_order_category('b.product_category_code') }} as order_category,
    -- PK products are out of leak scope unless listed as an included package.
    toUInt8(order_category = 'Package' and ifNull(pk.package_description, '') = '') as is_excluded_package,
    toUInt8(b.care_type = 'IP')                         as is_inpatient,
    toUInt8(b.original_order_line is not null)          as is_alternative,
    {{ hnh_order_line_status('b.line_status_code') }}   as line_status,
    toUInt8(ifNull(a.charged_alternatives, 0) = 1)      as has_charged_alternative,
    -- Pharmacy only: another line of the same generic in the same episode was charged.
    toUInt8(order_category = 'Pharmacy' and b.has_live_charge = 0
            and ifNull(gl.charged_generic_lines, 0) > 0) as has_charged_substitute,
    {{ hnh_order_fulfilment_status('line_status', 'b.has_live_charge', 'has_charged_alternative', 'has_charged_substitute') }} as fulfilment_status,
    toUInt8(line_status in ('Delivered', 'Ordered') and is_excluded_package = 0) as is_in_leak_scope,
    toUInt8(is_in_leak_scope = 1 and fulfilment_status = 'Undelivered')          as is_lost,
    toUInt8(b.has_live_charge = 1 and b.units_delivered < b.units_ordered)       as is_partially_delivered,
    if(b.first_delivered_at is null or b.order_at is null, cast(null as Nullable(Int64)),
       dateDiff('minute', b.order_at, b.first_delivered_at))                     as order_to_delivery_minutes,
    -- old mv_orders_fulfillment + report: any alternative relation or a duplicated generic counted as delivered
    if(b.has_live_charge = 1 or b.original_order_line is not null or ifNull(a.alternative_lines, 0) > 0
       or (order_category = 'Pharmacy' and ifNull(gl.generic_lines, 0) > 1),
       'Delivered', 'Undelivered')                                               as legacy_status,
    toUInt8(ifNull(b.line_status_code, '') not in ('P', 'Q', 'X', 'C')
            and is_excluded_package = 0 and b.care_type != 'IP')                 as legacy_in_scope,
    toUInt8(legacy_in_scope = 1 and legacy_status = 'Undelivered')               as legacy_is_lost
from base as b
left join alternatives as a on a.branch_id = b.branch_id and a.original_line = b.order_line
left join generics as gl
    on gl.branch_id = b.branch_id and gl.patient_id = b.patient_id
   and gl.episode_no = b.episode_no and gl.generic_id = b.generic_id
left join (select distinct package_description from {{ ref('stg_ref__order_fulfilment_packages') }}) as pk
    on pk.package_description = b.service_description_upper
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "int_order_line,test_type:unit" --no-partial-parse`
Expected: PASS.

- [ ] **Step 4: Model tests and build**

Append to `_patient_flow__models.yml` under `models:`:

```yaml
  - name: int_order_line
    description: One order line with its fulfilment status (spec section 6) and the old report's legacy status.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, order_line]
    columns:
      - name: fulfilment_status
        tests:
          - accepted_values:
              values: ['Cancelled', 'Not applicable', 'Delivered', 'Delivered by alternative', 'Delivered by substitute', 'Undelivered']
      - name: line_status
        tests:
          - accepted_values:
              values: ['Delivered', 'Ordered', 'Cancelled', 'Not applicable', 'Unknown']
      - name: order_category
        tests:
          - accepted_values:
              values: ['Package', 'Lab', 'Radiology', 'Consultation', 'Pharmacy', 'Others']
```

Run: `python scripts/run_dbt.py build --select int_order_line --no-partial-parse`
Expected: PASS. Report:
- the row count and build time;
- for branch 1 in June 2026, non-inpatient lines: in-scope lines, lost lines, leak rate, and the count per `fulfilment_status`;
- the same month's `legacy_in_scope` and `legacy_is_lost` counts.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/patient_flow
git commit -m "Apply order fulfilment rules per order line"
```

---

### Task 6: gold.fact_order_line

**Files:**
- Create: `hnh_dwh/models/hnh/marts/patient_flow/fact_order_line.sql`
- Modify: `hnh_dwh/models/hnh/marts/patient_flow/_patient_flow_marts__models.yml`
- Create: `hnh_dwh/tests/hnh/assert_fact_order_line_matches_staging.sql`

**Interfaces:**
- Consumes `int_order_line` (Task 5), `dim_patient(patient_key)`, `dim_payer(payer_key)`, `dim_staff(staff_key)`, `hnh_dim_department(department_key)`, `dim_service(service_key)`, `dim_product_category(product_category_key)` and the macros `hnh_care_type_key`, `hnh_time_key` and `hnh_date_key_in_range`.
- Produces `gold.fact_order_line`:
  - **Keys:** `order_line_key`, `order_key`, `branch_key`, `order_date_key`, `order_time_key`, `first_delivery_date_key`, `patient_key`, `episode_key`, `payer_key`, `ordering_staff_key`, `ordering_department_key`, `service_key`, `product_category_key`, `care_type_key`.
  - **Order identifiers:** `master_order_no`, `order_line`.
  - **Attributes:** `order_category`, `line_status`, `fulfilment_status`, `status_reason`, `generic_name`, `urgency_code`.
  - **Flags:** `is_alternative`, `is_excluded_package`, `is_inpatient`, `is_in_leak_scope`, `is_lost`, `is_partially_delivered`.
  - **Measures:** `units_ordered`, `units_delivered`, `ordered_value`, `charged_amount`, `live_charge_count`, `order_to_delivery_minutes`.
  - **Legacy and audit:** `legacy_status`, `legacy_in_scope`, `legacy_is_lost`, `_loaded_at`.

- [ ] **Step 1: YAML tests and conservation test first**

Append to `_patient_flow_marts__models.yml` under `models:`:

```yaml
  - name: fact_order_line
    description: One clinical order line with its fulfilment (charged or not), units, value and order-to-delivery time. Leak KPIs use is_in_leak_scope = 1 and is_inpatient = 0.
    columns:
      - name: order_line_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: order_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: first_delivery_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: ordering_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: ordering_department_key
        tests:
          - relationships: {to: ref('hnh_dim_department'), field: department_key}
      - name: service_key
        tests:
          - relationships: {to: ref('dim_service'), field: service_key}
      - name: product_category_key
        tests:
          - relationships: {to: ref('dim_product_category'), field: product_category_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: fulfilment_status
        tests:
          - accepted_values:
              values: ['Cancelled', 'Not applicable', 'Delivered', 'Delivered by alternative', 'Delivered by substitute', 'Undelivered']
```

`tests/hnh/assert_fact_order_line_matches_staging.sql`:

```sql
-- One fact row per staged order line whose order time (own, else header) falls in the window.
select 'fact_order_line row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_order_line') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__order_lines') }} as l
    left join (select branch_id, master_order_no, ordered_at from {{ ref('stg_oasis__orders') }}) as o
        on o.branch_id = l.branch_id and o.master_order_no = l.master_order_no
    where coalesce(l.line_ordered_at, o.ordered_at) >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(coalesce(l.line_ordered_at, o.ordered_at)) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
    settings join_use_nulls = 1
) as s
where f.n != s.n
```

Run: `python scripts/run_dbt.py build --select fact_order_line assert_fact_order_line_matches_staging --no-partial-parse`
Expected: FAIL. The model does not exist yet.

- [ ] **Step 2: Write `fact_order_line.sql`**

```sql
{{ config(order_by='(branch_key, order_date_key, order_line_key)') }}

with keyed as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'order_line']) }}                as order_line_key,
        {{ hnh_surrogate_key(['branch_id', 'master_order_no']) }}           as order_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}  as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'orderer_staff_id']) }}          as staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'order_work_entity']) }}         as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'ios']) }}                       as service_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'product_category_code']) }}     as product_category_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'episode_purchaser_code']) }}    as payer_key_raw
    from {{ ref('int_order_line') }}
)

select
    k.order_line_key                                        as order_line_key,
    k.order_key                                             as order_key,
    k.branch_id                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(toDate(k.order_at))))  as order_date_key,
    {{ hnh_time_key('k.order_at') }}                        as order_time_key,
    {{ hnh_date_key_in_range('k.first_delivered_at') }}     as first_delivery_date_key,
    ifNull(dp.patient_key, toInt64(-1))                     as patient_key,
    k.episode_key                                           as episode_key,
    ifNull(dpy.payer_key, toInt64(-1))                      as payer_key,
    ifNull(ds.staff_key, toInt64(-1))                       as ordering_staff_key,
    ifNull(dd.department_key, toInt64(-1))                  as ordering_department_key,
    ifNull(dsv.service_key, toInt64(-1))                    as service_key,
    ifNull(dpc.product_category_key, toInt64(-1))           as product_category_key,
    {{ hnh_care_type_key('k.care_type') }}                  as care_type_key,
    k.master_order_no                                       as master_order_no,
    k.order_line                                            as order_line,
    k.order_category                                        as order_category,
    k.line_status                                           as line_status,
    k.fulfilment_status                                     as fulfilment_status,
    k.status_reason                                         as status_reason,
    k.generic_name                                          as generic_name,
    k.urgency_code                                          as urgency_code,
    k.is_alternative                                        as is_alternative,
    k.is_excluded_package                                   as is_excluded_package,
    k.is_inpatient                                          as is_inpatient,
    k.is_in_leak_scope                                      as is_in_leak_scope,
    k.is_lost                                               as is_lost,
    k.is_partially_delivered                                as is_partially_delivered,
    k.units_ordered                                         as units_ordered,
    k.units_delivered                                       as units_delivered,
    k.ordered_value                                         as ordered_value,
    k.charged_amount                                        as charged_amount,
    k.live_charge_count                                     as live_charge_count,
    k.order_to_delivery_minutes                             as order_to_delivery_minutes,
    k.legacy_status                                         as legacy_status,
    k.legacy_in_scope                                       as legacy_in_scope,
    k.legacy_is_lost                                        as legacy_is_lost,
    now()                                                   as _loaded_at
from keyed as k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.staff_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = k.department_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = k.service_key_raw
left join (select product_category_key from {{ ref('dim_product_category') }}) as dpc
    on dpc.product_category_key = k.product_category_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 3: Build and test**

Run: `python scripts/run_dbt.py build --select fact_order_line assert_fact_order_line_matches_staging --no-partial-parse`
Expected: PASS.

Report:
- the row count and build time;
- the share of rows with -1 on `ordering_staff_key`, `ordering_department_key`, `service_key`, `patient_key` and `payer_key`. A high staff share means `orderer_staff_id` does not match `dim_staff`'s id format: report it, do not change the key;
- for branch 1 in June 2026, non-inpatient: in-scope lines, lost lines, leak rate, lost value, the unit fulfilment rate, and the median `order_to_delivery_minutes` per `order_category` for delivered lines.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/patient_flow hnh_dwh/tests/hnh/assert_fact_order_line_matches_staging.sql
git commit -m "Add the order line fact"
```

---

### Task 7: Reconciliation and monitors

**Files:**
- Create: `hnh_dwh/models/hnh/marts/reconciliation/rec_orders_monthly.sql`
- Modify: `hnh_dwh/models/hnh/marts/reconciliation/_reconciliation__models.yml`, `_reconciliation_unit_tests.yml`
- Create: `hnh_dwh/tests/hnh/warn_delivered_status_without_charge.sql`, `warn_charges_without_order_line.sql`, `warn_unresolved_order_packages.sql`, `warn_negative_order_turnaround.sql`

**Interfaces:**
- Consumes `fact_order_line` (Task 6), `stg_oasis__charges`, `stg_oasis__delivery_lines`, `stg_oasis__order_lines`, `stg_oasis__ios_master`, `stg_oasis__service_items` and `stg_ref__order_fulfilment_packages`.
- Produces `rec_orders_monthly(branch_key, month_start, legacy_lines, legacy_lost, lines, lost, delivered_by_alternative, delivered_by_substitute, excluded_package_lines, scope_units_ordered, scope_units_delivered)`.

- [ ] **Step 1: Write the failing unit test and the unique test**

Append to `_reconciliation_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: rec_orders_monthly_counts_new_and_legacy_scope
    description: >
      June, branch 1: an OP lost line, an OP delivered line (3 of 4 units), an OP line delivered by
      alternative that the old report also counted, an IP lost line (in new leak scope but excluded
      from the non-inpatient KPI and from legacy scope), and an OP excluded package.
    model: rec_orders_monthly
    given:
      - input: ref('fact_order_line')
        format: sql
        rows: |
          select toUInt8(1) as branch_key, toInt32(20260615) as order_date_key, toUInt8(sc) as is_in_leak_scope,
                 toUInt8(lo) as is_lost, toUInt8(ip) as is_inpatient, toUInt8(xp) as is_excluded_package,
                 fs as fulfilment_status, toFloat64(uo) as units_ordered, toFloat64(ud) as units_delivered,
                 toUInt8(lsc) as legacy_in_scope, toUInt8(llo) as legacy_is_lost
          from values('sc UInt8, lo UInt8, ip UInt8, xp UInt8, fs String, uo Float64, ud Float64, lsc UInt8, llo UInt8',
              (1, 1, 0, 0, 'Undelivered', 1, 0, 1, 1),
              (1, 0, 0, 0, 'Delivered', 4, 3, 1, 0),
              (1, 0, 0, 0, 'Delivered by alternative', 1, 0, 1, 0),
              (1, 1, 1, 0, 'Undelivered', 2, 0, 0, 0),
              (0, 0, 0, 1, 'Undelivered', 1, 0, 0, 0))
    expect:
      rows:
        - {branch_key: 1, month_start: '2026-06-01', legacy_lines: 3, legacy_lost: 1, lines: 3, lost: 1, delivered_by_alternative: 1, delivered_by_substitute: 0, excluded_package_lines: 1, scope_units_ordered: 6, scope_units_delivered: 3}
```

Append to `_reconciliation__models.yml` under `models:`:

```yaml
  - name: rec_orders_monthly
    description: Order leakage per branch and order month, new rules (non-inpatient) against the old Order Fulfillment report's scope and status.
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
```

Run: `python scripts/run_dbt.py test --select "rec_orders_monthly,test_type:unit" --no-partial-parse`
Expected: FAIL. The model does not exist yet.

- [ ] **Step 2: Write `rec_orders_monthly.sql`**

```sql
{{ config(order_by='(branch_key, month_start)') }}

-- New measures follow the KPI default (non-inpatient); legacy measures use the old report's scope.
select
    branch_key,
    toStartOfMonth(YYYYMMDDToDate(toUInt32(order_date_key)))                         as month_start,
    countIf(legacy_in_scope = 1)                                                     as legacy_lines,
    countIf(legacy_is_lost = 1)                                                      as legacy_lost,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0)                               as lines,
    countIf(is_lost = 1 and is_inpatient = 0)                                        as lost,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0
            and fulfilment_status = 'Delivered by alternative')                      as delivered_by_alternative,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0
            and fulfilment_status = 'Delivered by substitute')                       as delivered_by_substitute,
    countIf(is_excluded_package = 1 and is_inpatient = 0)                            as excluded_package_lines,
    sumIf(units_ordered, is_in_leak_scope = 1 and is_inpatient = 0)                  as scope_units_ordered,
    sumIf(units_delivered, is_in_leak_scope = 1 and is_inpatient = 0)                as scope_units_delivered
from {{ ref('fact_order_line') }}
group by branch_key, month_start
```

Run the unit test again. Expected: PASS.

- [ ] **Step 3: Write the four monitors**

`tests/hnh/warn_delivered_status_without_charge.sql`:

```sql
{{ config(severity='warn') }}
-- Order lines Oasis marks delivered (D) that have no live charge, by branch and order month.
select branch_key, intDiv(order_date_key, 100) as order_month, count() as lines
from {{ ref('fact_order_line') }}
where line_status = 'Delivered' and live_charge_count = 0
group by branch_key, order_month
```

`tests/hnh/warn_charges_without_order_line.sql`:

```sql
{{ config(severity='warn') }}
-- Live charges of the last 365 days whose delivery line has no order line, or an order line
-- that is not in Oasis order_lines, by branch.
select c.branch_id as branch_id, count() as charges, sum(c.price_paid_purchaser) as amount
from {{ ref('stg_oasis__charges') }} as c
left join (select branch_id, delivery_line, order_line from {{ ref('stg_oasis__delivery_lines') }}) as d
    on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
left join (select branch_id, order_line from {{ ref('stg_oasis__order_lines') }}) as ol
    on ol.branch_id = c.branch_id and ol.order_line = d.order_line
where c.cancel_flag is null
  and c.delivered_at >= toDateTime(today() - 365, 'Asia/Riyadh')
  and (d.order_line is null or ol.order_line is null)
group by c.branch_id
settings join_use_nulls = 1
```

`tests/hnh/warn_unresolved_order_packages.sql`:

```sql
{{ config(severity='warn') }}
-- Included-package names that match no PK product in any branch (renamed or retired products).
select p.package_description as package_description
from {{ ref('stg_ref__order_fulfilment_packages') }} as p
left join (
    select distinct upper(trimBoth(si.description)) as description_upper
    from {{ ref('stg_oasis__ios_master') }} as m
    inner join {{ ref('stg_oasis__service_items') }} as si
        on si.branch_id = m.branch_id and si.ios_main = m.ios_main
    where coalesce(m.product_category_code, si.product_category_code) = 'PK'
) as x on x.description_upper = p.package_description
where x.description_upper is null
settings join_use_nulls = 1
```

`tests/hnh/warn_negative_order_turnaround.sql`:

```sql
{{ config(severity='warn') }}
-- Lines whose first live delivery is earlier than their order time, by branch and order month.
select branch_key, intDiv(order_date_key, 100) as order_month, count() as lines
from {{ ref('fact_order_line') }}
where order_to_delivery_minutes < 0
group by branch_key, order_month
```

- [ ] **Step 4: Build**

Run: `python scripts/run_dbt.py build --select rec_orders_monthly warn_delivered_status_without_charge warn_charges_without_order_line warn_unresolved_order_packages warn_negative_order_turnaround --no-partial-parse`
Expected: the model and its tests PASS. The warns may WARN but must never ERROR.

Report each warn's row count. For branch 1, June 2026, report every `rec_orders_monthly` column, and the legacy leak rate (`legacy_lost / legacy_lines`) against the new one (`lost / lines`).

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation hnh_dwh/tests/hnh/warn_delivered_status_without_charge.sql hnh_dwh/tests/hnh/warn_charges_without_order_line.sql hnh_dwh/tests/hnh/warn_unresolved_order_packages.sql hnh_dwh/tests/hnh/warn_negative_order_turnaround.sql
git commit -m "Add order leakage reconciliation and monitors"
```

---

### Task 8: Full build and hand-off

**Files:**
- Modify: `docs/receiving_project_config.md`, `docs/reconciliation_phase1.md`, `docs/superpowers/specs/2026-10-05-hnh-dwh-order-fulfilment-design.md`

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh` (it takes about 10–15 minutes).
Expected: `ERROR=0`. Warnings come only from `warn_*` tests and warn-severity tests. Record the totals, the elapsed time and the times of `int_order_line_base` and `int_order_line`.

- [ ] **Step 2: Receiving-project notes**

In `docs/receiving_project_config.md`:

1. Under "How the models read Oasis", add:

   "Order fulfilment reads `orders_master`, `order_lines` and `generics`. If the server's `oasis_lake` project has no model of those names, add them to `hnh_oasis_source_only`."

2. Under the reference-data section, add `map_order_fulfilment_packages` (46 rows, from `static_mappings/order_fulfilment_packages.csv`, loaded with `python scripts/load_reference_data.py --only map_order_fulfilment_packages`).

3. Under "Notes for the SSAS model", add:

   ```markdown
   - `fact_order_line`: leak KPIs (Order lines, Lost lines, Leak rate, Lost value, Unit fulfilment rate, Census, Contribution) filter `is_in_leak_scope = 1` and `is_inpatient = 0`; inpatient lines stay in the fact for separate analysis. Lost = `is_lost = 1`. Turnaround is the median of `order_to_delivery_minutes` over delivered lines, per category; negative values are kept and monitored. Speciality comes from `dim_staff` through `ordering_staff_key`.
   ```

- [ ] **Step 3: Reconciliation guide**

Append to `docs/reconciliation_phase1.md`:

```markdown
## Order fulfilment (`gold.rec_orders_monthly`)

1. Export No. Orders and Lost Orders from the old *Order Fulfillment* report for a closed month, per branch.
2. Compare with `legacy_lines` and `legacy_lost`. Acceptance: within 1% per branch. The old report also dropped orders whose episode had no `mv_eligibility` row, so the legacy columns can be slightly higher (open item O-OF-2, accepted).
3. Explain the gap to `lines` and `lost` with the spec's section 2.2: alternatives and duplicated generics count only when charged, status A is out of scope, and the old one-year window no longer applies.
```

Then add the four new monitors, with their row counts from Step 1, to the monitor list in that file (or create a short "Monitors" list if the file has none).

- [ ] **Step 4: Record the plan refinements in the spec**

Make three edits to the spec:

1. In `docs/superpowers/specs/2026-10-05-hnh-dwh-order-fulfilment-design.md`, change "45" to "46" wherever it counts the included packages.
2. In section 7, replace `is_urgent` with `urgency_code` (raw Oasis `urgent_flag`: R, S, H, A; meaning unconfirmed).
3. Append:

```markdown
## 12. Changes during implementation (2026-10-05)

1. The old view lists 46 included packages, not 45.
2. `fact_order_line` carries the raw `urgency_code` instead of `is_urgent`; the code meanings are unconfirmed.
3. The intermediate layer is two tables: `int_order_line_base` (line, header, episode, category, live-charge summary) and `int_order_line` (alternatives, substitutes, packages, statuses, legacy fields), so the charge join runs once.
4. `rec_orders_monthly` names its unit columns `scope_units_ordered` and `scope_units_delivered`.
5. `warn_unresolved_order_packages` lists package names that match a PK product in no branch.
```

- [ ] **Step 5: Commit**

```bash
git add docs/receiving_project_config.md docs/reconciliation_phase1.md docs/superpowers/specs/2026-10-05-hnh-dwh-order-fulfilment-design.md
git commit -m "Document order fulfilment hand-off and reconciliation"
```
