# Policy Class on Charge Lines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every charge line carries its insurance class (`REF`, `VIP`, `A`, `B`, `C`, `Not classified`), so Census, CPV,
CPE and Revenue slice by Policy Class in SSAS.

**Architecture:** The old server's hand mapping is copied into `default.map_contract_class`. `int_contract_class` gives
one class per branch + contract (Oasis class description first, mapping second). `int_charge_line_links` adds `REF`
for referral policies, and `fact_charge_line.policy_class` fills `Not classified`. The SSAS model gets the column from
the regenerated view contract.

**Tech Stack:** dbt on ClickHouse (receiving project, built by the user on 172.22.25.214), Python 3.12 scripts,
SSAS Tabular generator (`ssas/tools/generate.py`), Tabular Editor BPA.

**Spec:** `docs/superpowers/specs/2026-11-18-policy-class-design.md`

## Global Constraints

- Order: referral (`REF`) → class from the description → class from the mapping → `Not classified` (spec, the user's
  choice). The description wins when both give a class.
- Description patterns, on `upperUTF8(ifNull(description, ''))`, first match wins:
  `'\\^\\s*(VIP|A|B|C)'` (literal caret) then `'(?:^|\\s)(VIP|A|B|C)(?:\\s|$)'` (ClickHouse string literals as written).
- Values are repo labels, exact: `REF`, `VIP`, `A`, `B`, `C`, `Not classified`. Never wrap them in `hnh_title`.
- Key for both sources: (branch, contract number). Charge side: `delivery_charge.contract_no`.
- Reference table `default.map_contract_class`: `BRANCH_ID UInt8, CONTRACT_NO Int64, CLASS_ID Int64,
  CLASSIFICATION LowCardinality(String)`, ORDER BY `(BRANCH_ID, CONTRACT_NO)`, CSV
  `static_mappings/contract_class_mapping.csv` (git-ignored).
- Production server rules (CLAUDE.md): ClickHouse writes (the reference load), SSAS deploys and processing need the
  user's go-ahead. Reads through DSNs `HNH_Gold` (new) and `chDWH` (old server) need none.
- Work on branch `policy-class` in `D:\new_dwh_modeling-clr`; never push.

## Review Focus

1. A contract whose description has a class AND a mapping row that disagrees (`GOSI^C` vs mapping B) must get the
   description's class — the opposite of the old server. Pinned in Task 3's unit test.
2. A referral policy line whose contract has a class must be `REF`, not the class. Pinned in Task 4's fact test.
3. A line with no contract number (cash) or a contract without a class must be `Not classified`, never null (SSAS
   blank). Pinned in Task 4 (non-null in the view contract, `accepted_values` test).
4. Lower-case or padded descriptions (`class a`, `MG5^C\t\t`) must still classify. Pinned in Task 3.
5. A word that merely starts with A/B/C (`ART-1`, `ABC COMPANY`, `CHARITY`) must not classify on the token pattern.
   Pinned in Task 3.

---

### Task 1: Mapping reference table

**Files:**
- Create: `scripts/export_contract_class_mapping.py`
- Modify: `scripts/load_reference_data.py` (SMALL_TABLES)
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`, `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__contract_class.sql`

**Interfaces:**
- Produces: `stg_ref__contract_class(branch_id UInt8, contract_no Int64, class_id Int64, classification String)`,
  unique on (branch_id, contract_no); classification upper-cased and trimmed.

- [ ] **Step 1:** Write `export_contract_class_mapping.py`: reads
  `select BRANCH_ID, CONTRACT_NO, CLASS_ID, CLASSIFICATION from default.patient_contract_mapping order by 1, 2`
  through `hnh_dsn.select(sql, dsn="chDWH")` and writes the CSV (header row, UTF-8). Docstring: one-off copy of the old
  server's table; read-only.
- [ ] **Step 2:** Run it. Expected: 168,295 data rows in `static_mappings/contract_class_mapping.csv`.
- [ ] **Step 3:** Add the `map_contract_class` entry to SMALL_TABLES with the Global Constraints types (converters
  `i`, `i`, `i`, `s`) and a comment naming the source table and the order rule.
- [ ] **Step 4:** Add source `map_contract_class` and `stg_ref__contract_class` (select from the source, `toUInt8`,
  `toInt64`, `upper(trimBoth(CLASSIFICATION))`); YAML: `hnh_unique_combination [branch_id, contract_no]`,
  `accepted_values` on classification `['VIP', 'A', 'B', 'C']`.
- [ ] **Step 5:** Check the loader parses: `python -c "import ast,sys; ast.parse(open('scripts/load_reference_data.py').read())"`.
- [ ] **Step 6:** Commit.

### Task 2: Oasis staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml` (add `contracts`, `policy_classes`, `freshness: null`)
- Create: `stg_oasis__contracts.sql`, `stg_oasis__policy_classes.sql` in `hnh_dwh/models/hnh/staging/oasis/`
- Modify: `stg_oasis__charges.sql`, `_oasis__models.yml`

**Interfaces:**
- Produces: `stg_oasis__contracts(branch_id UInt8, contract_no Int64, class_id Nullable(Int64))`;
  `stg_oasis__policy_classes(branch_id UInt8, class_id Int64, description Nullable(String))`;
  `stg_oasis__charges.contract_no Nullable(Int64)` (`hnh_id`).

- [ ] **Step 1:** Write both staging models (`hnh_oasis_source(...) final`, `hnh_id` for class_id, `hnh_str` for
  description) and add `contract_no` to the charges model after `policy_code`.
- [ ] **Step 2:** YAML uniqueness tests: contracts `[branch_id, contract_no]`, policy classes `[branch_id, class_id]`.
- [ ] **Step 3:** Verify each renders and runs read-only: `python scripts/render_model_sql.py stg_oasis__contracts
  --wrap "select count(), uniqExact(branch_id, contract_no) from ({model})"` through `HNH_Gold`. Expected: both
  counts equal (693,757 on 2026-11-18); policy classes likewise (258,341).
- [ ] **Step 4:** Commit.

### Task 3: `int_contract_class`

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_contract_class.sql`
- Modify: `intermediate/revenue/_revenue__models.yml`, `_revenue_unit_tests.yml`

**Interfaces:**
- Consumes: Task 1 and Task 2 models.
- Produces: `int_contract_class(branch_id UInt8, contract_no Int64, policy_class String, class_source String)`, one
  row per contract that has a class (none → no row); `class_source` is `Description` or `Mapping`.

- [ ] **Step 1: Unit test** `int_contract_class_description_beats_mapping`. Contracts → class descriptions:
  1 `NTW2+^B`, 2 `VIP`, 3 `GOLD  (S)` + mapping A, 4 `GOSI^C` + mapping B, 5 `MOH`, 6 `class a`, 7 `MG5^C\t\t`,
  8 `ART-1`, 9 `ABC COMPANY`, 10 contract without class_id + mapping VIP, 11 absent from Oasis contracts + mapping C.
  Expected rows: (1, B, Description), (2, VIP, Description), (3, A, Mapping), (4, C, Description), (6, A, Description),
  (7, C, Description), (10, VIP, Mapping), (11, C, Mapping). No rows for 5, 8, 9.
- [ ] **Step 2: Implement.** Keys are the union of Oasis contracts and mapping rows; the class is
  `coalesce(caret pattern, token pattern, mapping)`; `order_by='(branch_id, contract_no)'`; `hnh_settings()`.
  YAML: description, uniqueness test, `accepted_values` on policy_class `['VIP', 'A', 'B', 'C']`.
- [ ] **Step 3: Verify** read-only against live data with `--replace stg_ref__contract_class=<stub of three mapping
  rows>`: one row per (branch, contract); `GOSI^C` contracts come back C; each stub contract without a description
  class comes back with its stub class and `Mapping`.
- [ ] **Step 4:** Commit.

### Task 4: Charge lines

**Files:**
- Modify: `intermediate/revenue/int_charge_line_links.sql` and its YAML description
- Modify: `marts/revenue/fact_charge_line.sql`, `_revenue_marts__models.yml`, `_revenue_marts_unit_tests.yml`
- Modify: `marts/ssas/_ssas__models.yml` (contract of `ssas_fact_charge_line`)

**Interfaces:**
- Consumes: `int_contract_class`, `int_policy_client.is_referral`.
- Produces: `int_charge_line_links.policy_class Nullable(String)` (`REF`, a class, or null);
  `fact_charge_line.policy_class String` right after `policy_key`; view column `policy_class` `"String"`.

- [ ] **Step 1: Tests first.** In `fact_charge_line_applies_billing_rules` give the link input a `policy_class` column:
  id 1 `B`, id 4 `REF`, the rest null; expected `policy_class` B, REF, and `Not classified` for every other line
  (including line 110, which has no link row). The second fact test's link input gets `policy_class` null and expects
  `Not classified`.
- [ ] **Step 2: Implement.** Links: `contract_no` in the charges CTE; left join `int_contract_class` on branch +
  contract and the referral policies (`int_policy_client where is_referral = 1`) on branch + policy_code;
  `if(referral matched, 'REF', cc.policy_class) as policy_class`. Fact: `ifNull(lk.policy_class, 'Not classified')`.
  YAML: column docs, `accepted_values` on `fact_charge_line.policy_class` with the six labels. Contract: add
  `policy_class` `"String"` after `policy_key`.
- [ ] **Step 3: Verify** the fact renders (temporary inlined copy for its `{% set %}`, deleted afterwards) and that
  `assert_mart_text_title_case` does not pick the column up (name matches none of its patterns).
- [ ] **Step 4:** Commit.

### Task 5: SSAS model, checks and docs

**Files:**
- Regenerate: `ssas/HNH_Analytics/` (tables/Charge Lines, perspectives)
- Modify: `ssas/tools/test_charge_line_links.py`, `ssas/tests/measures/revenue_cycle.json`
- Modify: `docs/receiving_project_config.md`, `ssas/README.md`

- [ ] **Step 1: Test.** `test_policy_class_column`: `Charge Lines` has a column `Policy Class`, not hidden, with no
  relationship.
- [ ] **Step 2:** `python ssas/tools/generate.py --from-contracts`, `measure_guards.py`, `sync_perspectives.py`;
  Tabular Editor BPA `-A ssas\bpa_rules.json -V` clean; `python -m pytest ssas/tools` passes.
- [ ] **Step 3: Measure check** in `revenue_cycle.json`: Census (Charged), branch 1, 2026-10, Policy Class `VIP`
  against SQL on `gold.fact_encounter` / `gold.ssas_fact_charge_line` (same shape as the Lab check), tolerance 0.01.
- [ ] **Step 4: Docs.** `receiving_project_config.md`: paragraph "Policy class (2026-11-18)" — load
  `python scripts/load_reference_data.py --only map_contract_class`; `contracts` and `policy_classes` need `oasis_lake`
  models or `hnh_oasis_source_only`; build command
  `dbt build --select stg_ref__contract_class stg_oasis__contracts stg_oasis__policy_classes stg_oasis__charges
  int_contract_class int_charge_line_links fact_charge_line ssas_fact_charge_line`; the nightly selector must also reach the four new models. README: one line
  under "Census by charges" that Policy Class slices the by-charges measures.
- [ ] **Step 5:** Commit.

### Handover (not tasks: the user's go-ahead each)

1. The user runs the reference load, copies the branch files and builds dbt.
2. I compare the built view to the contract (`scripts/gen_view_contracts.py` diff), then deploy `-Stage Test` with
   the user's go-ahead and run test.ps1.
3. Promote with GATE G3 of the charge-line relationships work.
