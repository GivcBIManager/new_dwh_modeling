# Phase 1A — Foundation and Conformed Dimensions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the dbt development harness, the portable `hnh` macros and tests, the staging layer for master and reference data, and every conformed dimension plus the security bridge in `gold`.

**Architecture:** A local dbt project (`hnh_dwh/`) builds views in `stg`, tables in `int` and tables in `gold` on the existing ClickHouse server. Everything that will later be copied into the receiving dbt instance lives under `models/hnh/`, `macros/hnh/` and `tests/hnh/`. Business rules that are pure expressions live in macros and are tested with literal inputs, so the tests run on any dbt version.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 (`clickhouse-connect`, `hijridate`).

**Spec:** `docs/superpowers/specs/2026-10-01-hnh-dwh-gold-layer-design.md`

**Follow-on plan:** `docs/superpowers/plans/2026-10-01-phase1b-patient-flow-facts.md` (depends on every task here).

## Global Constraints

- Databases: staging views in `stg`, intermediate tables in `int`, marts in `gold`. Never write to `oasis`, `fusion`, `press_ganey`. In `default`, only the two tables created by `scripts/load_hijri_calendar.py`.
- Portable content lives only under `hnh_dwh/models/hnh/`, `hnh_dwh/macros/hnh/`, `hnh_dwh/tests/hnh/`. No dbt packages. Every macro name starts with `hnh_`.
- Every model has tag `hnh` plus one of `hnh_stg`, `hnh_int`, `hnh_gold` (set by folder in `dbt_project.yml`).
- No CSV files and no seeds. `*.csv` and `profiles.yml` are git-ignored.
- Staging models: `select … from {{ source(...) }} final`, casts and renames only. No joins, no `where`, no calculations.
- Every Oasis key and join includes `branch_id`. `branch_id` is `UInt8` in every staging model.
- Ids are `Int64` (`hnh_id` / `toInt64`). Staff ids are strings, normalised with `hnh_code`.
- Oasis `DateTime64(6,'UTC')` columns hold KSA wall-clock time: use `hnh_ksa_wall_clock` for timestamps and `toDate32()` for date-only values. Never `toTimeZone`.
- Surrogate keys come only from `hnh_surrogate_key([...])` and are non-null `Int64`; a null component gives `-1`. Every dimension has a `-1` Unknown row.
- Any model containing a `left join` ends with `{{ hnh_settings() }}` (ClickHouse otherwise returns `0` / `''` instead of `NULL` for unmatched rows). When the model also has a top-level `union all`, wrap the union as `select * from ( … union all … ) {{ hnh_settings() }}` so the setting covers every branch.
- A selected column written as `alias.column` must come out named `column`. If a built table shows a column named like `c.los_days`, add an explicit `as los_days`.
- YAML uses the `tests:` key (works on every dbt version). Multi-column uniqueness uses the generic test `hnh_unique_combination`.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root `D:\new_dwh_modeling`.
- Commit after every task. Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. **A source id of `0` or `NULL`** (for example `patient_id = 0` on an empty appointment slot, or a staff id of `''`): must map to key `-1`, never to a hash of `'0'`, and never fail a build. Pinned in Task 1 (`assert_hnh_core_macros`).
2. **Unmerged duplicate versions in a source table** (`patient_master_data` holds 4.7M raw rows for 3.5M patients): every staging model must return one row per key. Pinned in Tasks 3, 4 and 5 (`hnh_unique_combination` on each staging key).
3. **A code referenced by a master row but absent from `codes_data`** (a patient with a nationality code that no longer exists): the row must be kept with a null or "Unknown" label, not dropped. Pinned in Task 8 (`assert_dim_patient_keeps_all_patients`).
4. **Two staff posts with the same start date, or two eligible licence documents:** `dim_staff` must still have exactly one row per staff member. Pinned in Task 9 (unique test plus `assert_dim_staff_row_count`).
5. **A BI user with no branch and no admin flag** (88 such rows today): must receive no access row and must be reported, not silently granted everything. Pinned in Task 11 (`assert_sec_no_access_without_branch`, `warn_sec_users_without_access`).

## File Structure

```
scripts/
  ch_env.py                     resolves connection settings (env, then ~/.claude.json)
  run_dbt.py                    runs dbt against hnh_dwh with those settings
  load_hijri_calendar.py        loads default.map_hijri_calendar and default.map_public_holiday
hnh_dwh/
  dbt_project.yml
  profiles.yml.example
  macros/generate_schema_name.sql        harness only (not portable)
  macros/hnh/hnh_core.sql                keys, casts, time helpers, settings
  macros/hnh/hnh_rules.sql               care type, outcome groups, care setting, person identifier
  macros/hnh/hnh_tests.sql               generic test hnh_unique_combination
  tests/hnh/assert_hnh_core_macros.sql
  tests/hnh/assert_hnh_rule_macros.sql
  tests/hnh/assert_dim_*.sql, assert_sec_*.sql, warn_*.sql
  models/hnh/staging/reference/          _reference__sources.yml, _reference__models.yml, stg_ref__*.sql
  models/hnh/staging/oasis/              _oasis__sources.yml, _oasis__models.yml, stg_oasis__*.sql
  models/hnh/intermediate/core/          _core__models.yml, int_code_decode.sql, int_department_conformed.sql
  models/hnh/marts/conformed/            _conformed__models.yml, dim_*.sql, sec_user_access.sql
docs/receiving_project_config.md
```

---

### Task 1: Development harness and core macros

**Files:**
- Create: `scripts/ch_env.py`, `scripts/run_dbt.py`
- Create: `hnh_dwh/dbt_project.yml`, `hnh_dwh/profiles.yml.example`, `hnh_dwh/macros/generate_schema_name.sql`
- Create: `hnh_dwh/macros/hnh/hnh_core.sql`, `hnh_dwh/macros/hnh/hnh_tests.sql`
- Test: `hnh_dwh/tests/hnh/assert_hnh_core_macros.sql`

**Interfaces:**
- Consumes: nothing.
- Produces (macros, used by every later task):
  - `hnh_surrogate_key(columns)` → non-null `Int64`; `-1` if any component is null.
  - `hnh_id(col)` → `Nullable(Int64)`, `0` becomes null. `hnh_str(col)` → trimmed `Nullable(String)`, `''` becomes null. `hnh_code(col)` → trimmed, upper-cased `Nullable(String)`. `hnh_flag(col)` → `UInt8` (1 when the value is `'Y'`).
  - `hnh_ksa_wall_clock(col)` → `Nullable(DateTime('Asia/Riyadh'))`. `hnh_julian_to_date(col)` → `Date`.
  - `hnh_date_key(col)` → `Nullable(Int32)` yyyymmdd. `hnh_time_key(col)` → `Nullable(Int16)` minute of day.
  - `hnh_minutes_between(start_col, end_col)` → `Nullable(Int64)`, null outside 0–1440.
  - `hnh_settings()` → `settings join_use_nulls = 1`.
  - Generic test `hnh_unique_combination(model, columns)`.
  - Command: `python scripts/run_dbt.py <dbt args>`.

- [ ] **Step 1: Write the connection helper and the dbt runner**

`scripts/ch_env.py`:

```python
"""Resolve ClickHouse connection settings for local development.

Order of precedence: HNH_CH_* environment variables, then the `clickhouse`
entry of ~/.claude.json. Values are placed in os.environ; nothing is printed.
"""
import json
import os
from pathlib import Path

KEYS = {
    "HNH_CH_HOST": "CLICKHOUSE_HOST",
    "HNH_CH_PORT": "CLICKHOUSE_PORT",
    "HNH_CH_USER": "CLICKHOUSE_USER",
    "HNH_CH_PASSWORD": "CLICKHOUSE_PASSWORD",
}


def resolve_env():
    missing = [k for k in KEYS if not os.environ.get(k)]
    if missing:
        cfg_path = Path.home() / ".claude.json"
        if cfg_path.exists():
            cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
            env = cfg.get("mcpServers", {}).get("clickhouse", {}).get("env", {})
            for key in missing:
                value = env.get(KEYS[key])
                if value is not None:
                    os.environ[key] = str(value)
    still_missing = [k for k in KEYS if not os.environ.get(k)]
    if still_missing:
        raise SystemExit("Missing connection settings: " + ", ".join(still_missing))
    return {k: os.environ[k] for k in KEYS}


def client():
    import clickhouse_connect

    env = resolve_env()
    return clickhouse_connect.get_client(
        host=env["HNH_CH_HOST"],
        port=int(env["HNH_CH_PORT"]),
        username=env["HNH_CH_USER"],
        password=env["HNH_CH_PASSWORD"],
        send_receive_timeout=1800,
    )
```

`scripts/run_dbt.py`:

```python
"""Run dbt against the hnh_dwh project with resolved connection settings.

Usage: python scripts/run_dbt.py build --select tag:hnh
"""
import subprocess
import sys
from pathlib import Path

from ch_env import resolve_env

PROJECT = Path(__file__).resolve().parent.parent / "hnh_dwh"


def main():
    resolve_env()
    cmd = ["dbt", *sys.argv[1:], "--project-dir", str(PROJECT), "--profiles-dir", str(PROJECT)]
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Write the project configuration**

`hnh_dwh/dbt_project.yml`:

```yaml
name: hnh_dwh
version: "1.0.0"
config-version: 2
profile: hnh_dwh

model-paths: ["models"]
macro-paths: ["macros"]
test-paths: ["tests"]
target-path: "target"
clean-targets: ["target"]

vars:
  hnh_history_start_date: "2022-01-01"
  hnh_ssas_machine_name: "SSAS-SERVER"

models:
  hnh_dwh:
    hnh:
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
```

`hnh_dwh/profiles.yml.example`:

```yaml
hnh_dwh:
  target: dev
  outputs:
    dev:
      type: clickhouse
      driver: http
      host: "{{ env_var('HNH_CH_HOST') }}"
      port: "{{ env_var('HNH_CH_PORT', '8123') | int }}"
      user: "{{ env_var('HNH_CH_USER', 'default') }}"
      password: "{{ env_var('HNH_CH_PASSWORD') }}"
      schema: gold
      secure: false
      verify: false
      threads: 4
      connect_timeout: 30
      send_receive_timeout: 1800
      use_lw_deletes: true
```

`use_lw_deletes` lets the one incremental model in Phase 1B use the `delete+insert` strategy.

`hnh_dwh/macros/generate_schema_name.sql` (harness only; it makes `+schema: stg` resolve to the database `stg` rather than `gold_stg`):

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

- [ ] **Step 3: Create the local profile and check the connection**

Run:

```bash
cp hnh_dwh/profiles.yml.example hnh_dwh/profiles.yml
python scripts/run_dbt.py debug
```

Expected: the last lines include `Connection test: [OK connection ok]` and `All checks passed!`.

- [ ] **Step 4: Write the failing macro test**

`hnh_dwh/tests/hnh/assert_hnh_core_macros.sql` (a dbt singular test passes when it returns no rows):

```sql
-- Each branch returns a row only when a core macro misbehaves.
select 'surrogate key differs by numeric type' as failure
where {{ hnh_surrogate_key(["toInt64(1)", "toInt64(25)"]) }} != {{ hnh_surrogate_key(["toUInt8(1)", "toFloat64(25)"]) }}

union all
select 'surrogate key collides across component boundary'
where {{ hnh_surrogate_key(["toInt64(1)", "toInt64(25)"]) }} = {{ hnh_surrogate_key(["toInt64(12)", "toInt64(5)"]) }}

union all
select 'surrogate key is not -1 for a null component'
where {{ hnh_surrogate_key(["toUInt8(1)", "cast(null as Nullable(Int64))"]) }} != -1

union all
select 'surrogate key is negative'
where {{ hnh_surrogate_key(["toUInt8(8)", "'R4809'"]) }} < 0

union all
select 'hnh_id keeps zero'
where {{ hnh_id("toFloat64(0)") }} is not null

union all
select 'hnh_id loses a float id'
where {{ hnh_id("toFloat64(280967596)") }} != 280967596

union all
select 'hnh_str keeps an empty string'
where {{ hnh_str("'   '") }} is not null

union all
select 'hnh_code does not trim and upper-case'
where {{ hnh_code("' r4809 '") }} != 'R4809'

union all
select 'hnh_flag wrong'
where {{ hnh_flag("'Y'") }} != 1 or {{ hnh_flag("'N'") }} != 0 or {{ hnh_flag("cast(null as Nullable(String))") }} != 0

union all
select 'wall clock is shifted'
where toString({{ hnh_ksa_wall_clock("toDateTime64('2026-10-01 06:03:21', 6, 'UTC')") }}) != '2026-10-01 06:03:21'

union all
select 'julian conversion wrong'
where {{ hnh_julian_to_date("toFloat64(2440588)") }} != toDate('1970-01-01')
   or {{ hnh_julian_to_date("toFloat64(2460585)") }} != toDate('2024-10-01')

union all
select 'date key wrong'
where {{ hnh_date_key("toDateTime('2026-10-01 23:59:59', 'Asia/Riyadh')") }} != 20261001
   or {{ hnh_date_key("cast(null as Nullable(DateTime))") }} is not null

union all
select 'time key wrong'
where {{ hnh_time_key("toDateTime('2026-10-01 16:30:59', 'Asia/Riyadh')") }} != 990

union all
select 'minutes guard wrong'
where {{ hnh_minutes_between("toDateTime('2026-10-01 10:00:00')", "toDateTime('2026-10-01 10:45:00')") }} != 45
   or {{ hnh_minutes_between("toDateTime('2026-10-01 10:00:00')", "toDateTime('2026-10-01 09:00:00')") }} is not null
   or {{ hnh_minutes_between("toDateTime('2026-10-01 10:00:00')", "toDateTime('2026-10-03 10:00:00')") }} is not null

union all
select 'left join miss is not null'
from (
    select b.v as v
    from (select 1 as k) as a
    left join (select 2 as k, 5 as v) as b on a.k = b.k
    {{ hnh_settings() }}
)
where v is not null

union all
select 'left join miss inside a wrapped union is not null'
from (
    select * from (
        select b.v as v
        from (select 1 as k) as a
        left join (select 2 as k, 5 as v) as b on a.k = b.k
        union all
        select cast(null as Nullable(UInt8))
    )
    {{ hnh_settings() }}
)
where v is not null
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_core_macros`
Expected: a compilation error containing `'hnh_surrogate_key' is undefined`.

- [ ] **Step 6: Write the core macros**

`hnh_dwh/macros/hnh/hnh_core.sql`:

```sql
{# Deterministic non-null Int64 key. Components are compared as strings so the
   key does not depend on the numeric type of an id. A null component gives -1. #}
{% macro hnh_surrogate_key(columns) -%}
if(
    {% for c in columns %}isNull({{ c }}){% if not loop.last %} or {% endif %}{% endfor %},
    toInt64(-1),
    toInt64(bitShiftRight(cityHash64(concat(
        {% for c in columns %}toString(assumeNotNull({{ c }})), '|'{% if not loop.last %}, {% endif %}{% endfor %}
    )), 1))
)
{%- endmacro %}

{# Optional numeric reference: Float64 / Decimal / Int to Nullable(Int64); 0 means "none". #}
{% macro hnh_id(col) -%}
nullIf(toInt64({{ col }}), 0)
{%- endmacro %}

{# Trimmed text; empty becomes null. #}
{% macro hnh_str(col) -%}
nullIf(trimBoth(ifNull(toString({{ col }}), '')), '')
{%- endmacro %}

{# Text identifier (staff ids, type letters): trimmed and upper-cased. #}
{% macro hnh_code(col) -%}
nullIf(upper(trimBoth(ifNull(toString({{ col }}), ''))), '')
{%- endmacro %}

{% macro hnh_flag(col) -%}
toUInt8(ifNull(toString({{ col }}), '') = 'Y')
{%- endmacro %}

{# Oasis timestamps are KSA wall-clock values labelled UTC. Keep the wall-clock
   value and give it its true zone. KSA has no daylight saving, so the offset is fixed. #}
{% macro hnh_ksa_wall_clock(col) -%}
toDateTime({{ col }} - toIntervalHour(3), 'Asia/Riyadh')
{%- endmacro %}

{# Oracle Julian day number to Date. Julian day 2440588 is 1970-01-01. #}
{% macro hnh_julian_to_date(col) -%}
(toDate('1970-01-01') + toInt32({{ col }} - 2440588))
{%- endmacro %}

{% macro hnh_date_key(col) -%}
toInt32(toYYYYMMDD({{ col }}))
{%- endmacro %}

{% macro hnh_time_key(col) -%}
toInt16(toHour({{ col }}) * 60 + toMinute({{ col }}))
{%- endmacro %}

{# Whole minutes from start to end; null when negative or longer than a day. #}
{% macro hnh_minutes_between(start_col, end_col) -%}
if(dateDiff('minute', {{ start_col }}, {{ end_col }}) between 0 and 1440,
   dateDiff('minute', {{ start_col }}, {{ end_col }}), null)
{%- endmacro %}

{# Unmatched left-join rows must be NULL, not 0 or ''. #}
{% macro hnh_settings() -%}
settings join_use_nulls = 1
{%- endmacro %}
```

`hnh_dwh/macros/hnh/hnh_tests.sql`:

```sql
{# Fails with one row per duplicated combination of the given columns. #}
{% test hnh_unique_combination(model, columns) %}
select {{ columns | join(', ') }}, count() as n
from {{ model }}
group by {{ columns | join(', ') }}
having n > 1
{% endtest %}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_core_macros`
Expected: `PASS=1 WARN=0 ERROR=0`.

If the `julian conversion wrong` branch fails, check the expected date with `select toDate('1970-01-01') + (2460585 - 2440588)` in ClickHouse and correct the literal in the test, not the macro: the macro's anchor (2440588 = 1970-01-01) is the definition.

- [ ] **Step 8: Commit**

```bash
git add scripts/ch_env.py scripts/run_dbt.py hnh_dwh/dbt_project.yml hnh_dwh/profiles.yml.example hnh_dwh/macros hnh_dwh/tests
git commit -m "Add dbt harness and core hnh macros

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Rule macros

**Files:**
- Create: `hnh_dwh/macros/hnh/hnh_rules.sql`
- Test: `hnh_dwh/tests/hnh/assert_hnh_rule_macros.sql`

**Interfaces:**
- Consumes: `hnh_surrogate_key` (Task 1).
- Produces:
  - `hnh_care_type(attendance_type_col)` → `'OP' | 'ER' | 'IP' | 'DAYCASE' | 'Unknown'`.
  - `hnh_care_type_key(care_type_expr)` → `Int8` (`1` OP, `2` ER, `3` IP, `4` DAYCASE, `-1` Unknown).
  - `hnh_outcome_group(description_upper_col)` → one of `Attended`, `Cancelled`, `Rescheduled`, `No-show recorded`, `Left without being seen`, `Admitted`, `Referred`, `Left against advice`, `Died`, `Other`.
  - `hnh_discharge_outcome_group(description_upper_col)` → one of `Normal discharge`, `Left against advice`, `Died`, `Transferred out`, `Transferred to another episode`, `Wrong admission`, `Absconded`, `Other`.
  - `hnh_care_setting(entity_type_col)` → `'OP' | 'IP' | 'ER' | 'Theatre' | 'Ancillary' | 'Support'`.
  - `hnh_person_identifier(national_id, passport_no, border_no, branch_id, patient_id)` → `String` such as `N:1012345678`.
  - `hnh_person_identifier_source(national_id, passport_no, border_no)` → `String`.
  - `hnh_shift(time_col)` → one of the four shift labels.

- [ ] **Step 1: Write the failing test**

`hnh_dwh/tests/hnh/assert_hnh_rule_macros.sql`:

```sql
select 'care type mapping wrong' as failure
where {{ hnh_care_type("'O'") }} != 'OP' or {{ hnh_care_type("'E'") }} != 'ER'
   or {{ hnh_care_type("'I'") }} != 'IP' or {{ hnh_care_type("'D'") }} != 'DAYCASE'
   or {{ hnh_care_type("'S'") }} != 'Unknown'
   or {{ hnh_care_type("cast(null as Nullable(String))") }} != 'Unknown'

union all
select 'care type key wrong'
where {{ hnh_care_type_key("'OP'") }} != 1 or {{ hnh_care_type_key("'ER'") }} != 2
   or {{ hnh_care_type_key("'IP'") }} != 3 or {{ hnh_care_type_key("'DAYCASE'") }} != 4
   or {{ hnh_care_type_key("'Unknown'") }} != -1

union all
select 'outcome group wrong'
where {{ hnh_outcome_group("'CANCELLED BY HOSPITAL\\\\DOCTOR'") }} != 'Cancelled'
   or {{ hnh_outcome_group("'CANCELLED BY PATIENT'") }} != 'Cancelled'
   or {{ hnh_outcome_group("'RESCHEDULED BY HOSPITAL'") }} != 'Rescheduled'
   or {{ hnh_outcome_group("'DNA'") }} != 'No-show recorded'
   or {{ hnh_outcome_group("'NOSHOW'") }} != 'No-show recorded'
   or {{ hnh_outcome_group("'LEFT WITHOUT BEING SEEN'") }} != 'Left without being seen'
   or {{ hnh_outcome_group("'ADMISSION TO ICU (CRITICAL)'") }} != 'Admitted'
   or {{ hnh_outcome_group("'PATIENT ADMITTED (DON''T USE)'") }} != 'Admitted'
   or {{ hnh_outcome_group("'REFERRED TO OPD (CARDIOLOGY)'") }} != 'Referred'
   or {{ hnh_outcome_group("'TRANSFERRED TO ANOTHER HOSPITAL'") }} != 'Referred'
   or {{ hnh_outcome_group("'LAMA'") }} != 'Left against advice'
   or {{ hnh_outcome_group("'DIED'") }} != 'Died'
   or {{ hnh_outcome_group("'FOLLOW-UP BOOKED'") }} != 'Attended'
   or {{ hnh_outcome_group("'CONDITION CURED'") }} != 'Attended'
   or {{ hnh_outcome_group("'EPISODE CLOSED-CANCELED'") }} != 'Other'
   or {{ hnh_outcome_group("'TEST OUTCOME 1'") }} != 'Other'
   or {{ hnh_outcome_group("cast(null as Nullable(String))") }} != 'Other'

union all
select 'discharge outcome group wrong'
where {{ hnh_discharge_outcome_group("'NORMAL DISCHARGE'") }} != 'Normal discharge'
   or {{ hnh_discharge_outcome_group("'DAMA'") }} != 'Left against advice'
   or {{ hnh_discharge_outcome_group("'LAMA'") }} != 'Left against advice'
   or {{ hnh_discharge_outcome_group("'DIED'") }} != 'Died'
   or {{ hnh_discharge_outcome_group("'TRANSFEFRED TO ANOTHER HOSPITAL'") }} != 'Transferred out'
   or {{ hnh_discharge_outcome_group("'TRANSFERRED TO ANOTHER EPISODE'") }} != 'Transferred to another episode'
   or {{ hnh_discharge_outcome_group("'WRONG ADMISSION'") }} != 'Wrong admission'
   or {{ hnh_discharge_outcome_group("'ESCAPED'") }} != 'Absconded'
   or {{ hnh_discharge_outcome_group("'STATISTICAL DISCHARGE FROM LEAVE'") }} != 'Other'

union all
select 'care setting wrong'
where {{ hnh_care_setting("'C'") }} != 'OP' or {{ hnh_care_setting("'W'") }} != 'IP'
   or {{ hnh_care_setting("'E'") }} != 'ER' or {{ hnh_care_setting("'D'") }} != 'Theatre'
   or {{ hnh_care_setting("'Z'") }} != 'Theatre' or {{ hnh_care_setting("'X'") }} != 'Ancillary'
   or {{ hnh_care_setting("'A'") }} != 'Support'
   or {{ hnh_care_setting("cast(null as Nullable(String))") }} != 'Support'

union all
select 'person identifier wrong'
where {{ hnh_person_identifier("' 0010-123 456 '", "'A1'", "'B1'", "toUInt8(1)", "toInt64(7)") }} != 'N:10123456'
   or {{ hnh_person_identifier("cast(null as Nullable(String))", "'a 99-1'", "'B1'", "toUInt8(1)", "toInt64(7)") }} != 'P:A991'
   or {{ hnh_person_identifier("''", "''", "'0042'", "toUInt8(1)", "toInt64(7)") }} != 'B:42'
   or {{ hnh_person_identifier("''", "cast(null as Nullable(String))", "''", "toUInt8(3)", "toInt64(7)") }} != 'L:3|7'

union all
select 'person identifier source wrong'
where {{ hnh_person_identifier_source("'1'", "'A1'", "'B1'") }} != 'National id or iqama'
   or {{ hnh_person_identifier_source("''", "'A1'", "'B1'") }} != 'Passport'
   or {{ hnh_person_identifier_source("''", "''", "'B1'") }} != 'Border number'
   or {{ hnh_person_identifier_source("''", "''", "''") }} != 'Local'

union all
select 'shift wrong'
where {{ hnh_shift("toDateTime('2026-10-01 07:59:00')") }} != '00:00-08:00'
   or {{ hnh_shift("toDateTime('2026-10-01 08:00:00')") }} != '08:00-12:00'
   or {{ hnh_shift("toDateTime('2026-10-01 16:29:00')") }} != '12:00-16:30'
   or {{ hnh_shift("toDateTime('2026-10-01 16:30:00')") }} != '16:30-24:00'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_rule_macros`
Expected: a compilation error containing `'hnh_care_type' is undefined`.

- [ ] **Step 3: Write the rule macros**

`hnh_dwh/macros/hnh/hnh_rules.sql`:

```sql
{# Episode attendance type to care type. Anything unrecognised is Unknown, never IP. #}
{% macro hnh_care_type(col) -%}
multiIf({{ col }} = 'O', 'OP', {{ col }} = 'E', 'ER', {{ col }} = 'I', 'IP', {{ col }} = 'D', 'DAYCASE', 'Unknown')
{%- endmacro %}

{% macro hnh_care_type_key(expr) -%}
toInt8(multiIf({{ expr }} = 'OP', 1, {{ expr }} = 'ER', 2, {{ expr }} = 'IP', 3, {{ expr }} = 'DAYCASE', 4, -1))
{%- endmacro %}

{# Appointment / ER outcome description (upper-cased, trimmed) to a group label.
   Codes differ by branch; descriptions are what is shared. #}
{% macro hnh_outcome_group(col) -%}
multiIf(
    startsWith(ifNull({{ col }}, ''), 'CANCELLED'), 'Cancelled',
    startsWith(ifNull({{ col }}, ''), 'RESCHEDULED'), 'Rescheduled',
    ifNull({{ col }}, '') in ('DNA', 'NOSHOW') or startsWith(ifNull({{ col }}, ''), 'CARE LESS'), 'No-show recorded',
    startsWith(ifNull({{ col }}, ''), 'LEFT WITHOUT BEING SEEN'), 'Left without being seen',
    startsWith(ifNull({{ col }}, ''), 'ADMISSION TO') or startsWith(ifNull({{ col }}, ''), 'ADMITTED TO')
        or startsWith(ifNull({{ col }}, ''), 'PATIENT ADMITTED') or startsWith(ifNull({{ col }}, ''), 'DIRECT TO OR')
        or startsWith(ifNull({{ col }}, ''), 'CATH LAB'), 'Admitted',
    startsWith(ifNull({{ col }}, ''), 'REFER') or startsWith(ifNull({{ col }}, ''), 'TRANSFERRED TO')
        or startsWith(ifNull({{ col }}, ''), 'EHALA'), 'Referred',
    startsWith(ifNull({{ col }}, ''), 'DAMA') or startsWith(ifNull({{ col }}, ''), 'LAMA'), 'Left against advice',
    ifNull({{ col }}, '') = 'DIED', 'Died',
    ifNull({{ col }}, '') in ('FOLLOW-UP BOOKED', 'CONDITION CURED', 'DISCHARGED', 'ER DISCHARGE (CURED)',
        'FOLLOW-UP RECOMMENDED IN OPD (IMPROVED)', 'RETURN AT WILL', 'IMPROVEMENT IN CONDITION',
        'DISCHARGE AND CLOSE FUTURE APPT', 'CLOSE EPISODE'), 'Attended',
    'Other'
)
{%- endmacro %}

{# Inpatient discharge outcome description (upper-cased, trimmed) to a group label. #}
{% macro hnh_discharge_outcome_group(col) -%}
multiIf(
    ifNull({{ col }}, '') = 'NORMAL DISCHARGE', 'Normal discharge',
    ifNull({{ col }}, '') in ('DAMA', 'LAMA'), 'Left against advice',
    ifNull({{ col }}, '') = 'DIED', 'Died',
    ifNull({{ col }}, '') like '%ANOTHER HOSPITAL%', 'Transferred out',
    ifNull({{ col }}, '') like '%ANOTHER EPISODE%', 'Transferred to another episode',
    ifNull({{ col }}, '') = 'WRONG ADMISSION', 'Wrong admission',
    ifNull({{ col }}, '') = 'ESCAPED', 'Absconded',
    'Other'
)
{%- endmacro %}

{# Work-entity type letter to care setting. #}
{% macro hnh_care_setting(col) -%}
multiIf(
    ifNull({{ col }}, '') in ('C', '1'), 'OP',
    ifNull({{ col }}, '') = 'W', 'IP',
    ifNull({{ col }}, '') = 'E', 'ER',
    ifNull({{ col }}, '') in ('D', 'Z', 'J', 'F', 'O'), 'Theatre',
    ifNull({{ col }}, '') in ('B', 'X', 'P', 'Y', 'R', 'K'), 'Ancillary',
    'Support'
)
{%- endmacro %}

{# Letters and digits only, upper-cased, leading zeros removed. #}
{% macro hnh_normalise_identifier(col) -%}
replaceRegexpOne(upper(replaceRegexpAll(ifNull(toString({{ col }}), ''), '[^0-9A-Za-z]', '')), '^0+', '')
{%- endmacro %}

{# The identifier a person is known by across branches. The type prefix stops a
   passport number colliding with a national id. Falls back to the local patient. #}
{% macro hnh_person_identifier(national_id, passport_no, border_no, branch_id, patient_id) -%}
multiIf(
    {{ hnh_normalise_identifier(national_id) }} != '', concat('N:', {{ hnh_normalise_identifier(national_id) }}),
    {{ hnh_normalise_identifier(passport_no) }} != '', concat('P:', {{ hnh_normalise_identifier(passport_no) }}),
    {{ hnh_normalise_identifier(border_no) }} != '', concat('B:', {{ hnh_normalise_identifier(border_no) }}),
    concat('L:', toString({{ branch_id }}), '|', toString({{ patient_id }}))
)
{%- endmacro %}

{% macro hnh_person_identifier_source(national_id, passport_no, border_no) -%}
multiIf(
    {{ hnh_normalise_identifier(national_id) }} != '', 'National id or iqama',
    {{ hnh_normalise_identifier(passport_no) }} != '', 'Passport',
    {{ hnh_normalise_identifier(border_no) }} != '', 'Border number',
    'Local'
)
{%- endmacro %}

{# The four shifts used by the existing reports. #}
{% macro hnh_shift(col) -%}
multiIf(
    toHour({{ col }}) < 8, '00:00-08:00',
    toHour({{ col }}) < 12, '08:00-12:00',
    toHour({{ col }}) * 60 + toMinute({{ col }}) < 990, '12:00-16:30',
    '16:30-24:00'
)
{%- endmacro %}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_rule_macros`
Expected: `PASS=1 WARN=0 ERROR=0`.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules.sql hnh_dwh/tests/hnh/assert_hnh_rule_macros.sql
git commit -m "Add hnh rule macros for care type, outcome groups and person identifier

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Reference staging

**Files:**
- Create: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/_reference__models.yml`
- Create: eleven `hnh_dwh/models/hnh/staging/reference/stg_ref__*.sql` files (below)

**Interfaces:**
- Consumes: `hnh_str`, `hnh_code`, `hnh_unique_combination` (Task 1).
- Produces (all with `branch_id` as `UInt8` where present):
  - `stg_ref__branch(branch_id, branch_name, city, licensed_beds, fusion_ledger_id, fusion_branch_code, pg_branch_code)`
  - `stg_ref__purchaser_mapping(branch_id, purchaser_code, insurer, creditor, category, billing_type, manual_submission)`
  - `stg_ref__referral_policy(branch_id, purchaser_code, policy_code)`
  - `stg_ref__unified_department(department, unified_department, not_admitting, high_value)` — `department` upper-cased, one row per department
  - `stg_ref__bed_classification(branch_id, bed_location, classification)`
  - `stg_ref__ward_tower(branch_id, work_entity, tower)`
  - `stg_ref__clinic_duration(specialty, clinic_duration_hours, slots_per_hour)` — `specialty` upper-cased
  - `stg_ref__clinic_count(branch_id, clinics_count)`
  - `stg_ref__home_care_entity(branch_id, work_entity)`
  - `stg_ref__termination_reason(branch_id, termination_reason_code, unified_reason)`
  - `stg_ref__bi_users(user_name, branch_id, is_admin, unified_specialty)`

- [ ] **Step 1: Declare the sources**

`hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`:

```yaml
version: 2

sources:
  - name: reference
    schema: default
    description: Hand-maintained mapping tables, loaded once by scripts/load_reference_data.py.
    tables:
      - name: branch_dict_source
      - name: map_purchasers
      - name: map_referral_policies
      - name: map_unified_department_v2
      - name: map_bed_classification
      - name: map_ward_tower
      - name: map_clinic_duration
      - name: map_clinic_count
      - name: map_home_care_entity
      - name: map_termination_reason
      - name: bi_users
      - name: budget_data
      - name: map_hijri_calendar
      - name: map_public_holiday
```

- [ ] **Step 2: Write the tests**

`hnh_dwh/models/hnh/staging/reference/_reference__models.yml`:

```yaml
version: 2

models:
  - name: stg_ref__branch
    columns:
      - name: branch_id
        tests: [unique, not_null]
  - name: stg_ref__purchaser_mapping
    tests:
      - hnh_unique_combination:
          columns: [branch_id, purchaser_code]
  - name: stg_ref__referral_policy
    tests:
      - hnh_unique_combination:
          columns: [branch_id, purchaser_code, policy_code]
  - name: stg_ref__unified_department
    columns:
      - name: department
        tests: [unique, not_null]
      - name: unified_department
        tests: [not_null]
  - name: stg_ref__bed_classification
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bed_location]
    columns:
      - name: classification
        tests:
          - accepted_values:
              values: ["Critical", "Intermediate Care", "Non Critical", "Non-Admitting Unit"]
  - name: stg_ref__ward_tower
    tests:
      - hnh_unique_combination:
          columns: [branch_id, work_entity]
  - name: stg_ref__clinic_duration
    columns:
      - name: specialty
        tests: [unique, not_null]
  - name: stg_ref__clinic_count
    columns:
      - name: branch_id
        tests: [unique, not_null]
  - name: stg_ref__home_care_entity
    tests:
      - hnh_unique_combination:
          columns: [branch_id, work_entity]
  - name: stg_ref__termination_reason
    tests:
      - hnh_unique_combination:
          columns: [branch_id, termination_reason_code]
  - name: stg_ref__bi_users
    columns:
      - name: user_name
        tests: [not_null]
```

- [ ] **Step 3: Run to verify the tests have nothing to test yet**

Run: `python scripts/run_dbt.py test --select tag:hnh_stg`
Expected: warnings of the form `Did not find matching node for patch with name 'stg_ref__branch'` and `Nothing to do`.

- [ ] **Step 4: Write the models**

`stg_ref__branch.sql`:

```sql
select
    toUInt8(branch_id)          as branch_id,
    {{ hnh_str('branch_name') }} as branch_name,
    {{ hnh_str('city') }}        as city,
    toInt32(licensed_beds)      as licensed_beds,
    toInt64(oracle_ledger_id)   as fusion_ledger_id,
    toInt64(oracle_branch_id)   as fusion_branch_code,
    {{ hnh_str('pg_branch_code') }} as pg_branch_code
from {{ source('reference', 'branch_dict_source') }}
```

`stg_ref__purchaser_mapping.sql` (the source is a `ReplacingMergeTree`):

```sql
select
    toUInt8(BRANCH_ID)             as branch_id,
    toInt64(PURCHASER_CODE)        as purchaser_code,
    {{ hnh_str('INSURANCE') }}     as insurer,
    {{ hnh_str('CREDITOR') }}      as creditor,
    {{ hnh_str('CATEGORY') }}      as category,
    {{ hnh_str('BILLING_TYPE') }}  as billing_type,
    {{ hnh_str('MANUAL_SUBMISSION') }} as manual_submission
from {{ source('reference', 'map_purchasers') }} final
```

`stg_ref__referral_policy.sql`:

```sql
select distinct
    toUInt8(BRANCH_ID)      as branch_id,
    toInt64(PURCHASER_CODE) as purchaser_code,
    toInt64(POLICY_CODE)    as policy_code
from {{ source('reference', 'map_referral_policies') }}
```

`stg_ref__unified_department.sql`:

```sql
select
    upper(trimBoth(DEPARTMENT))            as department,
    any(trimBoth(UNIFIED_DEPARTMENT))      as unified_department,
    toUInt8(max(NOT_ADMITTING))            as not_admitting,
    toUInt8(max(High_Value))               as high_value
from {{ source('reference', 'map_unified_department_v2') }}
group by department
```

`stg_ref__bed_classification.sql`:

```sql
select
    toUInt8(BRANCH_ID)        as branch_id,
    trimBoth(BED)             as bed_location,
    any(trimBoth(CLASSIFICATION)) as classification
from {{ source('reference', 'map_bed_classification') }}
group by branch_id, bed_location
```

`stg_ref__ward_tower.sql`:

```sql
select
    toUInt8(BRANCH_ID)    as branch_id,
    toInt64(ID)           as work_entity,
    any(trimBoth(Tower))  as tower
from {{ source('reference', 'map_ward_tower') }}
group by branch_id, work_entity
```

`stg_ref__clinic_duration.sql`:

```sql
select
    upper(trimBoth(SPECIALTY))   as specialty,
    max(CLINIC_DURATION)         as clinic_duration_hours,
    max(SLOTS_PER_HOUR)          as slots_per_hour
from {{ source('reference', 'map_clinic_duration') }}
group by specialty
```

`stg_ref__clinic_count.sql`:

```sql
select
    toUInt8(BRANCH_ID)      as branch_id,
    toInt32(CLINICS_COUNT)  as clinics_count
from {{ source('reference', 'map_clinic_count') }}
```

`stg_ref__home_care_entity.sql`:

```sql
select distinct
    toUInt8(BRANCH_ID)    as branch_id,
    toInt64(WORK_ENTITY)  as work_entity
from {{ source('reference', 'map_home_care_entity') }}
```

`stg_ref__termination_reason.sql`:

```sql
select
    toUInt8(BRANCH_ID)                as branch_id,
    toInt64(TERMINATION_REASON_CODE)  as termination_reason_code,
    any(trimBoth(UNIFIED_REASON))     as unified_reason
from {{ source('reference', 'map_termination_reason') }}
group by branch_id, termination_reason_code
```

`stg_ref__bi_users.sql` (the source table has no password column):

```sql
select
    trimBoth(UserName)                   as user_name,
    nullIf(toUInt8(BRANCH_ID), 0)        as branch_id,
    toUInt8(IsAdmin)                     as is_admin,
    {{ hnh_str('Unified_Speciality') }}  as unified_specialty
from {{ source('reference', 'bi_users') }}
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select tag:hnh_stg`
Expected: 11 views created, all tests pass (`ERROR=0`).

- [ ] **Step 6: Spot-check one model**

Run: `python scripts/run_dbt.py show --inline "select count() as n, countIf(not_admitting = 1) as non_admitting from {{ ref('stg_ref__unified_department') }}"`
Expected: `n` = 192 (fewer only if two source rows differ by case alone) and `non_admitting` = 42.

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/models/hnh/staging/reference
git commit -m "Add reference staging models

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Oasis master staging and code decode

**Files:**
- Create: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`
- Create: `hnh_dwh/models/hnh/staging/oasis/_oasis__models.yml`
- Create: `stg_oasis__codes_data.sql`, `stg_oasis__work_entities.sql`, `stg_oasis__service_departments.sql`, `stg_oasis__cost_centres.sql`, `stg_oasis__purchasers.sql`, `stg_oasis__external_accounts.sql`, `stg_oasis__eligibility_types.sql`, `stg_oasis__discharge_mode_moh.sql`, `stg_oasis__admission_reason_moh.sql`, `stg_oasis__er_priorities.sql` in `hnh_dwh/models/hnh/staging/oasis/`
- Create: `hnh_dwh/models/hnh/intermediate/core/_core__models.yml`, `hnh_dwh/models/hnh/intermediate/core/int_code_decode.sql`

**Interfaces:**
- Consumes: core macros (Task 1).
- Produces:
  - `stg_oasis__codes_data(branch_id, code, code_type, description, description_ar, user_code, prog_code)`
  - `stg_oasis__work_entities(branch_id, work_entity, description, short_name, entity_type, service_dept, parent_work_entity, cost_centre_id, max_beds_in_ward, is_virtual_clinic, is_private, is_vip)`
  - `stg_oasis__service_departments(branch_id, service_dept, description, dept_type, short_code)`
  - `stg_oasis__cost_centres(branch_id, cost_centre_id, heading, description)`
  - `stg_oasis__purchasers(branch_id, purchaser_code, description, account_code, account_type, account_c_id, cchi_no, nphies_license, is_tpa, is_active)`
  - `stg_oasis__external_accounts(branch_id, account_code, account_type, c_id, account_name, group_code)`
  - `stg_oasis__eligibility_types(branch_id, eligibility_type, description, attendance_type, free_follow_up_days)`
  - `stg_oasis__discharge_mode_moh(branch_id, reason, moh_code)`, `stg_oasis__admission_reason_moh(branch_id, reason, moh_code)`
  - `stg_oasis__er_priorities(branch_id, priority, description, colour, target_minutes)`
  - `int_code_decode(branch_id, code, code_type, description, description_upper, description_ar, user_code, prog_code, moh_code)` — one row per `(branch_id, code)`, `code > 0`

- [ ] **Step 1: Declare the Oasis sources (all Phase 1 tables)**

`hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`:

```yaml
version: 2

sources:
  - name: oasis
    schema: oasis
    description: Hospital information system staging tables. ReplacingMergeTree on recorded_updated_at.
    loaded_at_field: recorded_updated_at
    freshness:
      warn_after: {count: 30, period: hour}
      error_after: {count: 54, period: hour}
    tables:
      - name: codes_data
        freshness: null
      - name: work_entities_data
        freshness: null
      - name: service_dept_data
        freshness: null
      - name: control_contexts_data
        freshness: null
      - name: purchasers
        freshness: null
      - name: external_accounts_data
        freshness: null
      - name: eligibility_types
        freshness: null
      - name: hnh_disacharge_mode_mapping
        freshness: null
      - name: hnh_admission_reason_mapping
        freshness: null
      - name: er_priorities
        freshness: null
      - name: patient_master_data
      - name: patient_file_master
        freshness: null
      - name: patient_ids
        freshness: null
      - name: staff_master_data
        freshness: null
      - name: staff_posts
        freshness: null
      - name: positions_data
        freshness: null
      - name: staff_types_data
        freshness: null
      - name: staff_type_classification
        freshness: null
      - name: staff_contracts
        freshness: null
      - name: hnh_internal_doctor_list
        freshness: null
      - name: personnel_documents
        freshness: null
      - name: bed_slots_master
        freshness: null
      - name: room_master
        freshness: null
      - name: bed_class_master_data
        freshness: null
      - name: bed_details
      - name: appointments
      - name: patient_emergency_visit
      - name: patient_ad
      - name: admission_request
        freshness: null
      - name: patient_episodes
      - name: patient_eligibility
      - name: patient_bill_agreements
      - name: operating_diary_slots
        freshness: null
      - name: operating_slot_details
        freshness: null
      - name: ios_main_data
        freshness: null
```

Freshness is checked only on the transactional tables that change every day; master tables may legitimately go days without a change.

- [ ] **Step 2: Write the tests**

`hnh_dwh/models/hnh/staging/oasis/_oasis__models.yml`:

```yaml
version: 2

models:
  - name: stg_oasis__codes_data
    tests:
      - hnh_unique_combination:
          columns: [branch_id, code]
  - name: stg_oasis__work_entities
    tests:
      - hnh_unique_combination:
          columns: [branch_id, work_entity]
  - name: stg_oasis__service_departments
    tests:
      - hnh_unique_combination:
          columns: [branch_id, service_dept]
  - name: stg_oasis__cost_centres
    tests:
      - hnh_unique_combination:
          columns: [branch_id, cost_centre_id]
  - name: stg_oasis__purchasers
    tests:
      - hnh_unique_combination:
          columns: [branch_id, purchaser_code]
  - name: stg_oasis__external_accounts
    tests:
      - hnh_unique_combination:
          columns: [branch_id, account_code, account_type, c_id]
  - name: stg_oasis__eligibility_types
    tests:
      - hnh_unique_combination:
          columns: [branch_id, eligibility_type]
  - name: stg_oasis__er_priorities
    tests:
      - hnh_unique_combination:
          columns: [branch_id, priority]
```

`hnh_dwh/models/hnh/intermediate/core/_core__models.yml`:

```yaml
version: 2

models:
  - name: int_code_decode
    tests:
      - hnh_unique_combination:
          columns: [branch_id, code]
    columns:
      - name: code
        tests: [not_null]
```

- [ ] **Step 3: Run to verify nothing is tested yet**

Run: `python scripts/run_dbt.py test --select int_code_decode stg_oasis__codes_data`
Expected: `Did not find matching node for patch` warnings and `Nothing to do`.

- [ ] **Step 4: Write the staging models**

`stg_oasis__codes_data.sql`:

```sql
select
    toUInt8(branch_id)              as branch_id,
    toInt64(code)                   as code,
    toInt32(code_type)              as code_type,
    {{ hnh_str('description') }}    as description,
    {{ hnh_str('description_a') }}  as description_ar,
    {{ hnh_str('user_code') }}      as user_code,
    toInt32(prog_code)              as prog_code
from {{ source('oasis', 'codes_data') }} final
```

`stg_oasis__work_entities.sql`:

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(work_entity)                     as work_entity,
    {{ hnh_str('description') }}             as description,
    {{ hnh_str('short_name') }}              as short_name,
    {{ hnh_code('entity_type') }}            as entity_type,
    {{ hnh_id('clinic_service_dept') }}      as service_dept,
    {{ hnh_id('part_of_work_entity') }}      as parent_work_entity,
    toInt64OrNull(trimBoth(ifNull(gl_section_code, ''))) as cost_centre_id,
    toInt32(max_beds_in_ward)                as max_beds_in_ward,
    {{ hnh_flag('virtual_clinic') }}         as is_virtual_clinic,
    {{ hnh_flag('private_flag') }}           as is_private,
    {{ hnh_flag('vip_flag') }}               as is_vip
from {{ source('oasis', 'work_entities_data') }} final
```

`stg_oasis__service_departments.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    toInt64(service_dept)              as service_dept,
    {{ hnh_str('description') }}       as description,
    {{ hnh_code('dept_type') }}        as dept_type,
    {{ hnh_str('dept_short_code') }}   as short_code
from {{ source('oasis', 'service_dept_data') }} final
```

`stg_oasis__cost_centres.sql`:

```sql
select
    toUInt8(branch_id)             as branch_id,
    toInt64(c_id)                  as cost_centre_id,
    {{ hnh_str('heading') }}       as heading,
    {{ hnh_str('description') }}   as description
from {{ source('oasis', 'control_contexts_data') }} final
```

`stg_oasis__purchasers.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    toInt64(purchaser_code)            as purchaser_code,
    {{ hnh_str('description') }}       as description,
    {{ hnh_code('account_code') }}     as account_code,
    {{ hnh_code('account_type') }}     as account_type,
    toInt64(account_c_id)              as account_c_id,
    {{ hnh_str('cchi_no') }}           as cchi_no,
    {{ hnh_str('nphies_license') }}    as nphies_license,
    {{ hnh_flag('is_tpa') }}           as is_tpa,
    toUInt8(ifNull(toString(activity_indicator), 'Y') != 'N') as is_active
from {{ source('oasis', 'purchasers') }} final
```

`stg_oasis__external_accounts.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    {{ hnh_code('account_code') }}     as account_code,
    {{ hnh_code('account_type') }}     as account_type,
    toInt64(c_id)                      as c_id,
    {{ hnh_str('account_name') }}      as account_name,
    {{ hnh_str('group_code') }}        as group_code
from {{ source('oasis', 'external_accounts_data') }} final
```

`stg_oasis__eligibility_types.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(eligibility_type)                   as eligibility_type,
    {{ hnh_str('eligibility_description') }}    as description,
    {{ hnh_code('attendence_type') }}           as attendance_type,
    toInt32(eligibility_no_days)                as free_follow_up_days
from {{ source('oasis', 'eligibility_types') }} final
```

`stg_oasis__discharge_mode_moh.sql`:

```sql
select
    toUInt8(branch_id)           as branch_id,
    {{ hnh_str('reason') }}      as reason,
    {{ hnh_str('moh_code') }}    as moh_code
from {{ source('oasis', 'hnh_disacharge_mode_mapping') }} final
```

`stg_oasis__admission_reason_moh.sql`:

```sql
select
    toUInt8(branch_id)           as branch_id,
    {{ hnh_str('reason') }}      as reason,
    {{ hnh_str('moh_code') }}    as moh_code
from {{ source('oasis', 'hnh_admission_reason_mapping') }} final
```

`stg_oasis__er_priorities.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    toInt64(priority)                  as priority,
    {{ hnh_str('description') }}       as description,
    {{ hnh_str('priority_color') }}    as colour,
    toInt32(target_time_mins)          as target_minutes
from {{ source('oasis', 'er_priorities') }} final
```

- [ ] **Step 5: Write `int_code_decode`**

`hnh_dwh/models/hnh/intermediate/core/int_code_decode.sql`:

```sql
{{ config(order_by='(branch_id, code)') }}

with codes as (
    select * from {{ ref('stg_oasis__codes_data') }} where code > 0
),

moh as (
    select branch_id, reason_upper, any(moh_code) as moh_code
    from (
        select branch_id, upper(reason) as reason_upper, moh_code from {{ ref('stg_oasis__discharge_mode_moh') }}
        union all
        select branch_id, upper(reason) as reason_upper, moh_code from {{ ref('stg_oasis__admission_reason_moh') }}
    )
    where reason_upper is not null
    group by branch_id, reason_upper
)

select
    c.branch_id          as branch_id,
    c.code               as code,
    c.code_type          as code_type,
    c.description        as description,
    upper(c.description) as description_upper,
    c.description_ar     as description_ar,
    c.user_code          as user_code,
    c.prog_code          as prog_code,
    m.moh_code           as moh_code
from codes as c
left join moh as m
    on m.branch_id = c.branch_id and m.reason_upper = upper(c.description)
{{ hnh_settings() }}
```

- [ ] **Step 6: Build and test**

Run: `python scripts/run_dbt.py build --select stg_oasis__codes_data stg_oasis__work_entities stg_oasis__service_departments stg_oasis__cost_centres stg_oasis__purchasers stg_oasis__external_accounts stg_oasis__eligibility_types stg_oasis__discharge_mode_moh stg_oasis__admission_reason_moh stg_oasis__er_priorities int_code_decode`
Expected: 10 views and 1 table created, all tests pass.

- [ ] **Step 7: Spot-check the decode**

Run: `python scripts/run_dbt.py show --inline "select code, any(description_upper) as d, uniqExact(branch_id) as branches from {{ ref('int_code_decode') }} where code in (93, 94, 107, 108, 106) group by code order by code"`
Expected: 93, 94, 107 and 108 are cancellation or rescheduling descriptions present in 8 branches; 106 is `OPD CLINIC TEAM`.

Run: `python scripts/run_dbt.py show --inline "select countIf(moh_code = '') as empty_strings, countIf(moh_code is null) as nulls, countIf(moh_code is not null) as mapped from {{ ref('int_code_decode') }}"`
Expected: `empty_strings` = 0, `nulls` is large and `mapped` is small. A non-zero `empty_strings` means `{{ hnh_settings() }}` is not taking effect in table models: stop and report, because every later model depends on it.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis hnh_dwh/models/hnh/intermediate/core
git commit -m "Add Oasis master staging and code decode

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Oasis patient, staff and bed staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__models.yml` (append)
- Create in `hnh_dwh/models/hnh/staging/oasis/`: `stg_oasis__patients.sql`, `stg_oasis__patient_files.sql`, `stg_oasis__patient_ids.sql`, `stg_oasis__staff.sql`, `stg_oasis__staff_posts.sql`, `stg_oasis__positions.sql`, `stg_oasis__staff_types.sql`, `stg_oasis__staff_type_classifications.sql`, `stg_oasis__staff_contracts.sql`, `stg_oasis__doctor_departments.sql`, `stg_oasis__personnel_documents.sql`, `stg_oasis__bed_slots.sql`, `stg_oasis__rooms.sql`, `stg_oasis__bed_classes.sql`, `stg_oasis__bed_details.sql`

**Interfaces:**
- Consumes: core macros (Task 1).
- Produces:
  - `stg_oasis__patients(branch_id, patient_id, name_1, name_2, name_3, family_name, name_ar_1, name_ar_2, name_ar_3, family_name_ar, birth_date, sex, nationality_code, marital_code, occupation_code, registered_date, registered_dept, status, patient_category_code, is_chronic, is_at_risk, merged_into_patient_id, mobile_no, email_address)`
  - `stg_oasis__patient_files(branch_id, pat_file_id, patient_id, user_file_id)`
  - `stg_oasis__patient_ids(branch_id, patient_id_seq, patient_id, id_type_code, id_number)`
  - `stg_oasis__staff(branch_id, staff_id, staff_type, name_1, name_2, name_3, family_name, name_ar_1, name_ar_2, name_ar_3, family_name_ar, birth_date, sex, nationality_code, religion_code, service_start_date, doctor_code, national_id, is_employee_dependant)`
  - `stg_oasis__staff_posts(branch_id, post_number, staff_id, work_entity, position_type, started_at, ended_at, posts_id)`
  - `stg_oasis__positions(branch_id, position_type, description)`
  - `stg_oasis__staff_types(branch_id, staff_type, description, is_consultant)`
  - `stg_oasis__staff_type_classifications(branch_id, staff_type, type_desc, classification, category, med_nonmed)`
  - `stg_oasis__staff_contracts(branch_id, staff_contract_no, staff_id, started_at, ended_at, terminated_at, termination_reason_code)`
  - `stg_oasis__doctor_departments(branch_id, staff_id, department, created_at)`
  - `stg_oasis__personnel_documents(branch_id, document_id, staff_id, doc_type, doc_number, valid_from)`
  - `stg_oasis__bed_slots(branch_id, bed_location, work_entity, room_no, slot_status)`
  - `stg_oasis__rooms(branch_id, room_no, work_entity, description, room_class, room_sex)`
  - `stg_oasis__bed_classes(branch_id, bed_class, description)`
  - `stg_oasis__bed_details(branch_id, bed_detail_id, is_current, work_entity, room_no, bed_location, bed_status, bed_class, started_at, ended_at, patient_id, admission_no, episode_no, bed_sex, transferred_from_work_entity)`

- [ ] **Step 1: Append the tests**

Append to `hnh_dwh/models/hnh/staging/oasis/_oasis__models.yml` under `models:`:

```yaml
  - name: stg_oasis__patients
    tests:
      - hnh_unique_combination:
          columns: [branch_id, patient_id]
  - name: stg_oasis__patient_files
    tests:
      - hnh_unique_combination:
          columns: [branch_id, pat_file_id]
  - name: stg_oasis__patient_ids
    tests:
      - hnh_unique_combination:
          columns: [branch_id, patient_id_seq]
  - name: stg_oasis__staff
    tests:
      - hnh_unique_combination:
          columns: [branch_id, staff_id]
    columns:
      - name: staff_id
        tests: [not_null]
  - name: stg_oasis__staff_posts
    tests:
      - hnh_unique_combination:
          columns: [branch_id, post_number, started_at]
  - name: stg_oasis__positions
    tests:
      - hnh_unique_combination:
          columns: [branch_id, position_type]
  - name: stg_oasis__staff_types
    tests:
      - hnh_unique_combination:
          columns: [branch_id, staff_type]
  - name: stg_oasis__staff_contracts
    tests:
      - hnh_unique_combination:
          columns: [branch_id, staff_contract_no]
  - name: stg_oasis__personnel_documents
    tests:
      - hnh_unique_combination:
          columns: [branch_id, document_id]
  - name: stg_oasis__bed_slots
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bed_location]
  - name: stg_oasis__bed_classes
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bed_class]
  - name: stg_oasis__bed_details
    tests:
      - hnh_unique_combination:
          columns: [branch_id, bed_detail_id]
```

- [ ] **Step 2: Run to verify nothing is tested yet**

Run: `python scripts/run_dbt.py test --select stg_oasis__patients stg_oasis__staff stg_oasis__bed_details`
Expected: `Did not find matching node for patch` warnings and `Nothing to do`.

- [ ] **Step 3: Write the patient models**

`stg_oasis__patients.sql`:

```sql
select
    toUInt8(branch_id)                        as branch_id,
    toInt64(patient_id)                       as patient_id,
    {{ hnh_str('pat_name_1') }}               as name_1,
    {{ hnh_str('pat_name_2') }}               as name_2,
    {{ hnh_str('pat_name_3') }}               as name_3,
    {{ hnh_str('pat_name_family') }}          as family_name,
    {{ hnh_str('scnd_pat_name_1') }}          as name_ar_1,
    {{ hnh_str('scnd_pat_name_2') }}          as name_ar_2,
    {{ hnh_str('scnd_pat_name_3') }}          as name_ar_3,
    {{ hnh_str('scnd_pat_name_family') }}     as family_name_ar,
    toDate32(date_of_birth)                   as birth_date,
    {{ hnh_code('sex') }}                     as sex,
    {{ hnh_id('nationality_code') }}          as nationality_code,
    {{ hnh_id('marital_code') }}              as marital_code,
    {{ hnh_id('occupation_code') }}           as occupation_code,
    toDate32(date_registered)                 as registered_date,
    {{ hnh_str('dept_registered') }}          as registered_dept,
    {{ hnh_code('status') }}                  as status,
    {{ hnh_id('patient_category') }}          as patient_category_code,
    {{ hnh_flag('chronic_flag') }}            as is_chronic,
    {{ hnh_flag('at_risk_flag') }}            as is_at_risk,
    {{ hnh_id('new_patient_id') }}            as merged_into_patient_id,
    {{ hnh_str('mobile_no') }}                as mobile_no,
    {{ hnh_str('email_address') }}            as email_address
from {{ source('oasis', 'patient_master_data') }} final
```

`stg_oasis__patient_files.sql`:

```sql
select
    toUInt8(branch_id)                as branch_id,
    toInt64(pat_file_id)              as pat_file_id,
    {{ hnh_id('patient_id') }}        as patient_id,
    {{ hnh_str('user_file_id') }}     as user_file_id
from {{ source('oasis', 'patient_file_master') }} final
```

`stg_oasis__patient_ids.sql`:

```sql
select
    toUInt8(branch_id)              as branch_id,
    toInt64(patient_id_seq)         as patient_id_seq,
    {{ hnh_id('patient_id') }}      as patient_id,
    {{ hnh_id('id_type_code') }}    as id_type_code,
    {{ hnh_str('id_number') }}      as id_number
from {{ source('oasis', 'patient_ids') }} final
```

- [ ] **Step 4: Write the staff models**

`stg_oasis__staff.sql`:

```sql
select
    toUInt8(branch_id)                        as branch_id,
    {{ hnh_code('staff_id') }}                as staff_id,
    {{ hnh_id('staff_type') }}                as staff_type,
    {{ hnh_str('staff_name_1') }}             as name_1,
    {{ hnh_str('staff_name_2') }}             as name_2,
    {{ hnh_str('staff_name_3') }}             as name_3,
    {{ hnh_str('staff_name_family') }}        as family_name,
    {{ hnh_str('staff_name_1_b') }}           as name_ar_1,
    {{ hnh_str('staff_name_2_b') }}           as name_ar_2,
    {{ hnh_str('staff_name_3_b') }}           as name_ar_3,
    {{ hnh_str('staff_name_familyb') }}       as family_name_ar,
    toDate32(date_of_birth)                   as birth_date,
    {{ hnh_code('sex') }}                     as sex,
    {{ hnh_id('nationality_code') }}          as nationality_code,
    {{ hnh_id('religion_code') }}             as religion_code,
    toDate32(start_of_service)                as service_start_date,
    {{ hnh_code('doctor_code') }}             as doctor_code,
    {{ hnh_str('ni_number') }}                as national_id,
    {{ hnh_flag('employee_dependant_flag') }} as is_employee_dependant
from {{ source('oasis', 'staff_master_data') }} final
```

`stg_oasis__staff_posts.sql`:

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(post_number)                     as post_number,
    {{ hnh_code('staff_id') }}               as staff_id,
    {{ hnh_id('work_entity') }}              as work_entity,
    {{ hnh_id('position_type') }}            as position_type,
    {{ hnh_ksa_wall_clock('date_started') }} as started_at,
    {{ hnh_ksa_wall_clock('date_ended') }}   as ended_at,
    {{ hnh_id('posts_id') }}                 as posts_id
from {{ source('oasis', 'staff_posts') }} final
```

`stg_oasis__positions.sql`:

```sql
select
    toUInt8(branch_id)             as branch_id,
    toInt64(position_type)         as position_type,
    {{ hnh_str('description') }}   as description
from {{ source('oasis', 'positions_data') }} final
```

`stg_oasis__staff_types.sql`:

```sql
select
    toUInt8(branch_id)                        as branch_id,
    toInt64(staff_type)                       as staff_type,
    {{ hnh_str('staff_type_description') }}   as description,
    {{ hnh_flag('consultant') }}              as is_consultant
from {{ source('oasis', 'staff_types_data') }} final
```

`stg_oasis__staff_type_classifications.sql`:

```sql
select
    toUInt8(branch_id)               as branch_id,
    toInt64(staff_type)              as staff_type,
    {{ hnh_str('type_desc') }}       as type_desc,
    {{ hnh_str('classificaton') }}   as classification,
    {{ hnh_str('categorynew') }}     as category,
    {{ hnh_str('med_nonmed') }}      as med_nonmed
from {{ source('oasis', 'staff_type_classification') }} final
```

`stg_oasis__staff_contracts.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    toInt64(staff_contract_no)         as staff_contract_no,
    {{ hnh_code('staff_id') }}         as staff_id,
    toDate32(start_date)               as started_at,
    toDate32(end_date)                 as ended_at,
    toDate32(termination_date)         as terminated_at,
    {{ hnh_id('termination_reason_code') }} as termination_reason_code
from {{ source('oasis', 'staff_contracts') }} final
```

`stg_oasis__doctor_departments.sql`:

```sql
select
    toUInt8(branch_id)                        as branch_id,
    {{ hnh_code('staff_id') }}                as staff_id,
    {{ hnh_code('department') }}              as department,
    {{ hnh_ksa_wall_clock('creation_date') }} as created_at
from {{ source('oasis', 'hnh_internal_doctor_list') }} final
```

`stg_oasis__personnel_documents.sql`:

```sql
select
    toUInt8(branch_id)             as branch_id,
    toInt64(document_id)           as document_id,
    {{ hnh_code('staff_id') }}     as staff_id,
    {{ hnh_id('doc_type') }}       as doc_type,
    {{ hnh_str('doc_number') }}    as doc_number,
    toDate32(date_from)            as valid_from
from {{ source('oasis', 'personnel_documents') }} final
```

- [ ] **Step 5: Write the bed models**

`stg_oasis__bed_slots.sql`:

```sql
select
    toUInt8(branch_id)                as branch_id,
    {{ hnh_code('bed_location') }}    as bed_location,
    {{ hnh_id('work_entity') }}       as work_entity,
    {{ hnh_id('room_no') }}           as room_no,
    {{ hnh_id('slot_status') }}       as slot_status
from {{ source('oasis', 'bed_slots_master') }} final
```

`stg_oasis__rooms.sql`:

```sql
select
    toUInt8(branch_id)              as branch_id,
    toInt64(room_no)                as room_no,
    {{ hnh_id('work_entity') }}     as work_entity,
    {{ hnh_str('description') }}    as description,
    {{ hnh_id('room_class') }}      as room_class,
    {{ hnh_code('room_sex') }}      as room_sex
from {{ source('oasis', 'room_master') }} final
```

`stg_oasis__bed_classes.sql`:

```sql
select
    toUInt8(branch_id)             as branch_id,
    toInt64(bed_class)             as bed_class,
    {{ hnh_str('description') }}   as description
from {{ source('oasis', 'bed_class_master_data') }} final
```

`stg_oasis__bed_details.sql`:

```sql
select
    toUInt8(branch_id)                         as branch_id,
    toInt64(bed_detail_id)                     as bed_detail_id,
    {{ hnh_code('current_record') }}           as is_current,
    {{ hnh_id('work_entity') }}                as work_entity,
    {{ hnh_id('room_no') }}                    as room_no,
    {{ hnh_code('bed_location') }}             as bed_location,
    {{ hnh_id('bed_status') }}                 as bed_status,
    {{ hnh_id('bed_class') }}                  as bed_class,
    {{ hnh_ksa_wall_clock('start_date') }}     as started_at,
    {{ hnh_ksa_wall_clock('end_date') }}       as ended_at,
    {{ hnh_id('patient_id') }}                 as patient_id,
    {{ hnh_id('admission_no') }}               as admission_no,
    {{ hnh_id('episode_no') }}                 as episode_no,
    {{ hnh_code('bed_sex') }}                  as bed_sex,
    {{ hnh_id('trans_from_work_entity') }}     as transferred_from_work_entity
from {{ source('oasis', 'bed_details') }} final
```

`is_current` keeps the source letter (`Y`, `N`, `D`) because `D` is a distinct state.

- [ ] **Step 6: Build and test**

Run: `python scripts/run_dbt.py build --select stg_oasis__patients stg_oasis__patient_files stg_oasis__patient_ids stg_oasis__staff stg_oasis__staff_posts stg_oasis__positions stg_oasis__staff_types stg_oasis__staff_type_classifications stg_oasis__staff_contracts stg_oasis__doctor_departments stg_oasis__personnel_documents stg_oasis__bed_slots stg_oasis__rooms stg_oasis__bed_classes stg_oasis__bed_details`
Expected: 15 views created, all tests pass.

If `stg_oasis__staff` fails `not_null` on `staff_id`, a staff row has a blank id in the source. Do not filter in staging; report the count and leave the test at `severity: warn` with a comment naming the count.

- [ ] **Step 7: Spot-check de-duplication**

Run: `python scripts/run_dbt.py show --inline "select (select count() from {{ ref('stg_oasis__patients') }}) as patients, (select count() from {{ ref('stg_oasis__staff') }}) as staff, (select count() from {{ ref('stg_oasis__bed_details') }}) as bed_rows"`
Expected: about 3,543,516 patients, 23,506 staff and 1,770,059 bed rows (the de-duplicated counts measured on 2026-10-01; later runs are slightly higher).

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis
git commit -m "Add Oasis patient, staff and bed staging

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Branch, date, time and care-type dimensions

**Files:**
- Create: `scripts/load_hijri_calendar.py`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__hijri_calendar.sql`, `stg_ref__public_holiday.sql`
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__models.yml` (append)
- Create: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_branch.sql`, `dim_date.sql`, `dim_time.sql`, `dim_care_type.sql`, `dim_admission_source.sql`, `dim_procedure_type.sql`

**Interfaces:**
- Consumes: `scripts/ch_env.py` (Task 1), `stg_ref__branch`, `stg_ref__clinic_count` (Task 3), `hnh_shift` (Task 2).
- Produces:
  - `default.map_hijri_calendar(gregorian_date Date, hijri_year UInt16, hijri_month UInt8, hijri_day UInt8, hijri_month_name String)`
  - `default.map_public_holiday(holiday_date Date, holiday_name String)`
  - `dim_branch(branch_key UInt8, branch_name, city, licensed_beds, clinics_count, fusion_branch_code, fusion_ledger_id, pg_branch_code)` — row `0` is Group
  - `dim_date(date_key Int32, date_day Date, …)` — no Unknown row; optional date keys in facts are nullable
  - `dim_time(time_key Int16, …)` — 1,440 rows
  - `dim_care_type(care_type_key Int8, care_type, care_type_name)` — keys `1` OP, `2` ER, `3` IP, `4` DAYCASE, `-1` Unknown
  - `dim_admission_source(admission_source_key Int8, admission_source)` — `1` OP, `2` ER, `3` Direct, `-1` Unknown
  - `dim_procedure_type(procedure_type_key Int8, procedure_type)` — `1` Surgery, `2` Cesarean, `3` Cath Lab, `4` Endoscopy, `5` L&D, `-1` Unknown

- [ ] **Step 1: Write the calendar loader**

`scripts/load_hijri_calendar.py`:

```python
"""Load the Umm al-Qura calendar and Saudi public holidays into ClickHouse.

Creates default.map_hijri_calendar and default.map_public_holiday. Both are
rebuilt from scratch on every run: they are derived, never hand-edited.

Requires: pip install hijridate
"""
from datetime import date, timedelta

from hijridate import Gregorian

from ch_env import client

START = date(2008, 1, 1)
END = date(date.today().year + 2, 12, 31)

HIJRI_MONTHS = [
    "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani", "Jumada al-Awwal", "Jumada al-Thani",
    "Rajab", "Shaban", "Ramadan", "Shawwal", "Dhu al-Qadah", "Dhu al-Hijjah",
]


def build():
    calendar, holidays = [], []
    day = START
    while day <= END:
        h = Gregorian(day.year, day.month, day.day).to_hijri()
        calendar.append([day, h.year, h.month, h.day, HIJRI_MONTHS[h.month - 1]])
        if h.month == 10 and 1 <= h.day <= 4:
            holidays.append([day, "Eid al-Fitr"])
        elif h.month == 12 and 9 <= h.day <= 12:
            holidays.append([day, "Eid al-Adha"])
        elif day.month == 9 and day.day == 23:
            holidays.append([day, "National Day"])
        elif day.month == 2 and day.day == 22 and day.year >= 2022:
            holidays.append([day, "Founding Day"])
        day += timedelta(days=1)
    return calendar, holidays


def main():
    ch = client()
    calendar, holidays = build()
    ch.command(
        "CREATE OR REPLACE TABLE default.map_hijri_calendar (gregorian_date Date, hijri_year UInt16, "
        "hijri_month UInt8, hijri_day UInt8, hijri_month_name String) ENGINE = MergeTree ORDER BY gregorian_date"
    )
    ch.insert("default.map_hijri_calendar", calendar,
              column_names=["gregorian_date", "hijri_year", "hijri_month", "hijri_day", "hijri_month_name"])
    ch.command(
        "CREATE OR REPLACE TABLE default.map_public_holiday (holiday_date Date, holiday_name String) "
        "ENGINE = MergeTree ORDER BY holiday_date"
    )
    ch.insert("default.map_public_holiday", holidays, column_names=["holiday_date", "holiday_name"])
    print(f"map_hijri_calendar: {len(calendar):,} rows; map_public_holiday: {len(holidays):,} rows")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the loader**

Run:

```bash
pip install hijridate
python scripts/load_hijri_calendar.py
```

Expected: `map_hijri_calendar: N rows` where N is the number of days from 2008-01-01 to the end of the year after next (the same range as `dim_date`, which runs two years ahead because appointments are booked that far out), and `map_public_holiday` with roughly 9–10 rows per year.

Then verify one known date: `python scripts/run_dbt.py show --inline "select * from default.map_hijri_calendar where gregorian_date = '2026-03-20'"`
Expected: `hijri_month` = 10 and `hijri_day` = 1 (1 Shawwal 1447, Eid al-Fitr 2026). If the library gives 19 or 21 March instead, the Umm al-Qura table is the authority: keep the library's value and note the date in the commit message.

- [ ] **Step 3: Write the tests**

Append to `hnh_dwh/models/hnh/staging/reference/_reference__models.yml`:

```yaml
  - name: stg_ref__hijri_calendar
    columns:
      - name: date_day
        tests: [unique, not_null]
  - name: stg_ref__public_holiday
    columns:
      - name: date_day
        tests: [unique, not_null]
```

`hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`:

```yaml
version: 2

models:
  - name: dim_branch
    columns:
      - name: branch_key
        tests: [unique, not_null]
  - name: dim_date
    columns:
      - name: date_key
        tests: [unique, not_null]
      - name: date_day
        tests: [unique, not_null]
      - name: hijri_year
        tests: [not_null]
  - name: dim_time
    columns:
      - name: time_key
        tests: [unique, not_null]
      - name: shift
        tests:
          - accepted_values:
              values: ["00:00-08:00", "08:00-12:00", "12:00-16:30", "16:30-24:00"]
  - name: dim_care_type
    columns:
      - name: care_type_key
        tests: [unique, not_null]
      - name: care_type
        tests:
          - accepted_values:
              values: ["OP", "ER", "IP", "DAYCASE", "Unknown"]
  - name: dim_admission_source
    columns:
      - name: admission_source_key
        tests: [unique, not_null]
  - name: dim_procedure_type
    columns:
      - name: procedure_type_key
        tests: [unique, not_null]
```

- [ ] **Step 4: Run to verify nothing is tested yet**

Run: `python scripts/run_dbt.py test --select dim_branch dim_date dim_time dim_care_type`
Expected: `Did not find matching node for patch` warnings and `Nothing to do`.

- [ ] **Step 5: Write the calendar staging models**

`stg_ref__hijri_calendar.sql`:

```sql
select
    toDate(gregorian_date)   as date_day,
    toUInt16(hijri_year)     as hijri_year,
    toUInt8(hijri_month)     as hijri_month,
    toUInt8(hijri_day)       as hijri_day,
    hijri_month_name         as hijri_month_name
from {{ source('reference', 'map_hijri_calendar') }}
```

`stg_ref__public_holiday.sql`:

```sql
select
    toDate(holiday_date)   as date_day,
    any(holiday_name)      as holiday_name
from {{ source('reference', 'map_public_holiday') }}
group by date_day
```

- [ ] **Step 6: Write the dimensions**

`dim_branch.sql`:

```sql
{{ config(order_by='branch_key') }}

select * from (

select
    b.branch_id                          as branch_key,
    b.branch_name                        as branch_name,
    b.city                               as city,
    b.licensed_beds                      as licensed_beds,
    c.clinics_count                      as clinics_count,
    toNullable(b.fusion_branch_code)     as fusion_branch_code,
    toNullable(b.fusion_ledger_id)       as fusion_ledger_id,
    b.pg_branch_code                     as pg_branch_code
from {{ ref('stg_ref__branch') }} as b
left join {{ ref('stg_ref__clinic_count') }} as c on c.branch_id = b.branch_id

union all

select
    toUInt8(0), 'Group', 'Group',
    toInt32((select sum(licensed_beds) from {{ ref('stg_ref__branch') }})),
    toInt32((select sum(clinics_count) from {{ ref('stg_ref__clinic_count') }})),
    null, null, null

)
{{ hnh_settings() }}
```

`dim_date.sql`:

```sql
{{ config(order_by='date_key') }}

with days as (
    select toDate('2008-01-01') + number as date_day
    from numbers(dateDiff('day', toDate('2008-01-01'), toDate(concat(toString(toYear(today()) + 2), '-12-31'))) + 1)
)

select
    toInt32(toYYYYMMDD(d.date_day))                 as date_key,
    d.date_day                                      as date_day,
    toYear(d.date_day)                              as year,
    toQuarter(d.date_day)                           as quarter,
    concat('Q', toString(toQuarter(d.date_day)))    as quarter_name,
    toYear(d.date_day) * 10 + toQuarter(d.date_day) as year_quarter,
    toMonth(d.date_day)                             as month,
    dateName('month', d.date_day)                   as month_name,
    formatDateTime(d.date_day, '%b')                as month_short,
    toYear(d.date_day) * 100 + toMonth(d.date_day)  as year_month,
    formatDateTime(d.date_day, '%Y-%b')             as year_month_name,
    toDayOfMonth(d.date_day)                        as day_of_month,
    toDayOfWeek(d.date_day)                         as day_of_week,
    dateName('weekday', d.date_day)                 as day_name,
    toISOWeek(d.date_day)                           as iso_week,
    toStartOfMonth(d.date_day)                      as start_of_month,
    toLastDayOfMonth(d.date_day)                    as end_of_month,
    toStartOfQuarter(d.date_day)                    as start_of_quarter,
    toStartOfYear(d.date_day)                       as start_of_year,
    toYear(d.date_day)                              as fiscal_year,
    toUInt8(toDayOfWeek(d.date_day) in (5, 6))      as is_weekend,
    toUInt8(toDayOfWeek(d.date_day) != 5)           as is_clinic_working_day,
    h.hijri_year                                    as hijri_year,
    h.hijri_month                                   as hijri_month,
    h.hijri_day                                     as hijri_day,
    h.hijri_month_name                              as hijri_month_name,
    toUInt8(p.holiday_name is not null)             as is_public_holiday,
    p.holiday_name                                  as holiday_name,
    dateDiff('day', d.date_day, today())            as day_offset,
    dateDiff('month', d.date_day, today())          as month_offset,
    dateDiff('quarter', d.date_day, today())        as quarter_offset,
    dateDiff('year', d.date_day, today())           as year_offset,
    toUInt8(d.date_day < today())                   as is_past
from days as d
left join {{ ref('stg_ref__hijri_calendar') }} as h on h.date_day = d.date_day
left join {{ ref('stg_ref__public_holiday') }} as p on p.date_day = d.date_day
{{ hnh_settings() }}
```

`toDayOfWeek` returns 1 for Monday, so 5 is Friday and 6 is Saturday.

`dim_time.sql`:

```sql
{{ config(order_by='time_key') }}

with minutes as (
    select toInt16(number) as time_key, toDateTime('2000-01-01 00:00:00') + toIntervalMinute(number) as t
    from numbers(1440)
)

select
    time_key                                             as time_key,
    formatDateTime(t, '%H:%i')                           as time_label,
    toUInt8(toHour(t))                                   as hour,
    toUInt8(toMinute(t))                                 as minute,
    formatDateTime(toStartOfFifteenMinutes(t), '%H:%i')  as quarter_hour,
    {{ hnh_shift('t') }}                                 as shift
from minutes
```

`dim_care_type.sql`:

```sql
{{ config(order_by='care_type_key') }}

select toInt8(1) as care_type_key, 'OP' as care_type, 'Outpatient' as care_type_name
union all select toInt8(2), 'ER', 'Emergency'
union all select toInt8(3), 'IP', 'Inpatient'
union all select toInt8(4), 'DAYCASE', 'Day case'
union all select toInt8(-1), 'Unknown', 'Unknown'
```

`dim_admission_source.sql`:

```sql
{{ config(order_by='admission_source_key') }}

select toInt8(1) as admission_source_key, 'OP' as admission_source
union all select toInt8(2), 'ER'
union all select toInt8(3), 'Direct'
union all select toInt8(-1), 'Unknown'
```

`dim_procedure_type.sql`:

```sql
{{ config(order_by='procedure_type_key') }}

select toInt8(1) as procedure_type_key, 'Surgery' as procedure_type
union all select toInt8(2), 'Cesarean'
union all select toInt8(3), 'Cath Lab'
union all select toInt8(4), 'Endoscopy'
union all select toInt8(5), 'L&D'
union all select toInt8(-1), 'Unknown'
```

- [ ] **Step 7: Build and test**

Run: `python scripts/run_dbt.py build --select stg_ref__hijri_calendar stg_ref__public_holiday dim_branch dim_date dim_time dim_care_type dim_admission_source dim_procedure_type`
Expected: 2 views and 6 tables created, all tests pass. `dim_date.hijri_year not_null` passing proves the Hijri table covers the whole date range.

- [ ] **Step 8: Spot-check**

Run: `python scripts/run_dbt.py show --inline "select (select count() from {{ ref('dim_branch') }}) as branches, (select count() from {{ ref('dim_time') }}) as minutes, (select countIf(is_public_holiday = 1) from {{ ref('dim_date') }} where year = 2026) as holidays_2026, (select countIf(is_clinic_working_day = 0) from {{ ref('dim_date') }} where year = 2026) as fridays_2026"`
Expected: 9 branches (8 plus Group), 1,440 minutes, 10 holidays in 2026 (4 Eid al-Fitr, 4 Eid al-Adha, National Day, Founding Day), 52 Fridays.

- [ ] **Step 9: Commit**

```bash
git add scripts/load_hijri_calendar.py hnh_dwh/models/hnh/staging/reference hnh_dwh/models/hnh/marts/conformed
git commit -m "Add branch, date, time and static dimensions with Umm al-Qura calendar

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Department and payer dimensions

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/core/int_department_conformed.sql`
- Modify: `hnh_dwh/models/hnh/intermediate/core/_core__models.yml` (append)
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_department.sql`, `dim_payer.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_dim_payer_synthetic_members.sql`

**Interfaces:**
- Consumes: `stg_oasis__work_entities`, `stg_oasis__service_departments`, `stg_oasis__cost_centres`, `stg_oasis__purchasers`, `stg_oasis__external_accounts`, `int_code_decode` (Task 4); `stg_ref__unified_department`, `stg_ref__ward_tower`, `stg_ref__home_care_entity`, `stg_ref__purchaser_mapping`, `stg_ref__branch` (Task 3); `hnh_care_setting` (Task 2).
- Produces:
  - `int_department_conformed(branch_id, work_entity, department_name, short_name, entity_type, entity_type_name, care_setting, service_dept, service_department_name, service_department_type, unified_department, is_non_admitting_specialty, is_high_value_specialty, cost_centre_id, cost_centre_name, tower, max_beds_in_ward, is_excluded_ward, is_home_care, is_virtual_clinic)`
  - `dim_department(department_key = hnh_surrogate_key([branch_id, work_entity]), branch_key, work_entity, …same attributes…)`
  - `dim_payer(payer_key = hnh_surrogate_key([branch_id, purchaser_code]), branch_key, purchaser_code, purchaser_name, account_code, company, creditor, category, billing_type, manual_submission, purchaser_type, is_tpa, is_moh, is_active, cchi_no, nphies_license)` — includes purchaser codes `9999` (Cash) and `8888` (Deductible) for every branch

- [ ] **Step 1: Write the tests**

Append to `_core__models.yml`:

```yaml
  - name: int_department_conformed
    tests:
      - hnh_unique_combination:
          columns: [branch_id, work_entity]
    columns:
      - name: care_setting
        tests:
          - accepted_values:
              values: ["OP", "IP", "ER", "Theatre", "Ancillary", "Support"]
      - name: tower
        tests: [not_null]
```

Append to `_conformed__models.yml`:

```yaml
  - name: dim_department
    columns:
      - name: department_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships:
              to: ref('dim_branch')
              field: branch_key
      - name: unified_department
        tests: [not_null]
  - name: dim_payer
    columns:
      - name: payer_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships:
              to: ref('dim_branch')
              field: branch_key
      - name: creditor
        tests: [not_null]
```

`hnh_dwh/tests/hnh/assert_dim_payer_synthetic_members.sql`:

```sql
-- Every branch must have the Cash (9999) and Deductible (8888) members,
-- and the Unknown member must exist exactly once.
select branch_key, countIf(purchaser_code = 9999) as cash, countIf(purchaser_code = 8888) as deductible
from {{ ref('dim_payer') }}
where branch_key between 1 and 8
group by branch_key
having cash != 1 or deductible != 1

union all

select toUInt8(0), toUInt64(count()), toUInt64(0)
from {{ ref('dim_payer') }}
where payer_key = -1
having count() != 1
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_dim_payer_synthetic_members`
Expected: a compilation error: `depends on a node named 'dim_payer' which was not found`.

- [ ] **Step 3: Write `int_department_conformed`**

```sql
{{ config(order_by='(branch_id, work_entity)') }}

with we as (
    select * from {{ ref('stg_oasis__work_entities') }}
),

entity_types as (
    select branch_id, user_code as entity_type, any(description) as entity_type_name
    from {{ ref('int_code_decode') }}
    where code_type = 256 and user_code is not null
    group by branch_id, user_code
)

select
    we.branch_id                                           as branch_id,
    we.work_entity                                         as work_entity,
    ifNull(we.description, 'Not named')                    as department_name,
    we.short_name                                          as short_name,
    we.entity_type                                         as entity_type,
    ifNull(initcap(et.entity_type_name), 'Unknown')        as entity_type_name,
    {{ hnh_care_setting('we.entity_type') }}               as care_setting,
    we.service_dept                                        as service_dept,
    sd.description                                         as service_department_name,
    sd.dept_type                                           as service_department_type,
    ifNull(ud.unified_department, 'Not Mapped')            as unified_department,
    toUInt8(ifNull(ud.not_admitting, 0))                   as is_non_admitting_specialty,
    toUInt8(ifNull(ud.high_value, 0))                      as is_high_value_specialty,
    we.cost_centre_id                                      as cost_centre_id,
    cc.heading                                             as cost_centre_name,
    multiIf(ifNull(tw.tower, '') != '', tw.tower,
            we.branch_id = 1 and ifNull(we.entity_type, '') = 'W', 'NEW',
            'Main')                                        as tower,
    we.max_beds_in_ward                                    as max_beds_in_ward,
    toUInt8(multiSearchAny(upper(ifNull(we.description, '')), ['NURS', 'BOOKING', 'PRE OP'])) as is_excluded_ward,
    toUInt8(hc.work_entity is not null)                    as is_home_care,
    we.is_virtual_clinic                                   as is_virtual_clinic
from we
left join {{ ref('stg_oasis__service_departments') }} as sd
    on sd.branch_id = we.branch_id and sd.service_dept = we.service_dept
left join {{ ref('stg_ref__unified_department') }} as ud
    on ud.department = upper(sd.description)
left join {{ ref('stg_oasis__cost_centres') }} as cc
    on cc.branch_id = we.branch_id and cc.cost_centre_id = we.cost_centre_id
left join {{ ref('stg_ref__ward_tower') }} as tw
    on tw.branch_id = we.branch_id and tw.work_entity = we.work_entity
left join {{ ref('stg_ref__home_care_entity') }} as hc
    on hc.branch_id = we.branch_id and hc.work_entity = we.work_entity
left join entity_types as et
    on et.branch_id = we.branch_id and et.entity_type = we.entity_type
{{ hnh_settings() }}
```

- [ ] **Step 4: Write `dim_department`**

```sql
{{ config(order_by='department_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'work_entity']) }} as department_key,
    branch_id                    as branch_key,
    toNullable(work_entity)      as work_entity,
    department_name              as department_name,
    short_name                   as short_name,
    entity_type                  as entity_type,
    entity_type_name             as entity_type_name,
    care_setting                 as care_setting,
    service_dept                 as service_dept,
    service_department_name      as service_department_name,
    service_department_type      as service_department_type,
    unified_department           as unified_department,
    is_non_admitting_specialty   as is_non_admitting_specialty,
    is_high_value_specialty      as is_high_value_specialty,
    cost_centre_id               as cost_centre_id,
    cost_centre_name             as cost_centre_name,
    tower                        as tower,
    max_beds_in_ward             as max_beds_in_ward,
    is_excluded_ward             as is_excluded_ward,
    is_home_care                 as is_home_care,
    is_virtual_clinic            as is_virtual_clinic
from {{ ref('int_department_conformed') }}

union all

select
    toInt64(-1), toUInt8(0), null, 'Unknown', null, null, 'Unknown', 'Support', null, null, null,
    'Unknown', toUInt8(0), toUInt8(0), null, null, 'Main', null, toUInt8(0), toUInt8(0), toUInt8(0)
```

- [ ] **Step 5: Write `dim_payer`**

```sql
{{ config(order_by='payer_key') }}

with purchasers as (
    select
        p.branch_id        as branch_id,
        p.purchaser_code   as purchaser_code,
        ifNull(p.description, ea.account_name) as purchaser_name,
        p.account_code     as account_code,
        initcap(coalesce(pm.insurer, ea.account_name, p.description, 'Not Mapped')) as company,
        if(pm.creditor = 'TPA', 'TPA', initcap(ifNull(pm.creditor, 'Not Mapped')))  as creditor,
        initcap(ifNull(pm.category, 'Not Mapped'))      as category,
        initcap(ifNull(pm.billing_type, 'Not Mapped'))  as billing_type,
        pm.manual_submission                            as manual_submission,
        if(startsWith(ifNull(p.account_code, ''), 'INS') or ifNull(upper(p.description), '') like '%GOSI%',
           'Insurance', 'Not insurance')                as purchaser_type,
        p.is_tpa           as is_tpa,
        p.is_active        as is_active,
        p.cchi_no          as cchi_no,
        p.nphies_license   as nphies_license
    from {{ ref('stg_oasis__purchasers') }} as p
    left join {{ ref('stg_oasis__external_accounts') }} as ea
        on ea.branch_id = p.branch_id and ea.account_code = p.account_code
       and ea.account_type = p.account_type and ea.c_id = p.account_c_id
    left join {{ ref('stg_ref__purchaser_mapping') }} as pm
        on pm.branch_id = p.branch_id and pm.purchaser_code = p.purchaser_code
    where p.purchaser_code not in (9999, 8888)
),

synthetic as (
    select branch_id, toInt64(9999) as purchaser_code, 'Cash' as purchaser_name, 'Cash' as creditor
    from {{ ref('stg_ref__branch') }}
    union all
    select branch_id, toInt64(8888), 'Cash', 'Deductible'
    from {{ ref('stg_ref__branch') }}
)

select * from (

select
    {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }} as payer_key,
    branch_id                              as branch_key,
    toNullable(purchaser_code)             as purchaser_code,
    purchaser_name                         as purchaser_name,
    account_code                           as account_code,
    company                                as company,
    creditor                               as creditor,
    category                               as category,
    billing_type                           as billing_type,
    manual_submission                      as manual_submission,
    purchaser_type                         as purchaser_type,
    is_tpa                                 as is_tpa,
    toUInt8(creditor = 'Government')       as is_moh,
    is_active                              as is_active,
    cchi_no                                as cchi_no,
    nphies_license                         as nphies_license
from purchasers

union all

select
    {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }},
    branch_id, toNullable(purchaser_code), purchaser_name, 'Cash', 'Cash', creditor, 'Cash', 'Cash', 'N',
    'Cash', toUInt8(0), toUInt8(0), toUInt8(1), null, null
from synthetic

union all

select
    toInt64(-1), toUInt8(0), null, 'Unknown', null, 'Unknown', 'Unknown', 'Unknown', 'Unknown', null,
    'Unknown', toUInt8(0), toUInt8(0), toUInt8(1), null, null

)
{{ hnh_settings() }}
```

The `where p.purchaser_code not in (9999, 8888)` clause guards against a real purchaser row colliding with the synthetic members.

- [ ] **Step 6: Build and test**

Run: `python scripts/run_dbt.py build --select int_department_conformed dim_department dim_payer assert_dim_payer_synthetic_members`
Expected: 3 tables created, all tests pass.

- [ ] **Step 7: Spot-check mapping coverage**

Run: `python scripts/run_dbt.py show --inline "select care_setting, count() as n, countIf(unified_department = 'Not Mapped') as unmapped from {{ ref('dim_department') }} group by care_setting order by n desc"`
Expected: `OP` is the largest group (about 1,270 clinics); most `OP` and `IP` rows are mapped. Record the unmapped counts in the commit message — they are a known data gap, not a failure.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/core hnh_dwh/models/hnh/marts/conformed hnh_dwh/tests/hnh/assert_dim_payer_synthetic_members.sql
git commit -m "Add department and payer dimensions

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Patient dimensions

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_patient.sql`, `dim_patient_pii.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_dim_patient_keeps_all_patients.sql`, `hnh_dwh/tests/hnh/assert_dim_patient_has_no_pii.sql`

**Interfaces:**
- Consumes: `stg_oasis__patients`, `stg_oasis__patient_files`, `stg_oasis__patient_ids` (Task 5); `int_code_decode` (Task 4); `hnh_person_identifier`, `hnh_person_identifier_source` (Task 2).
- Produces:
  - `dim_patient(patient_key = hnh_surrogate_key([branch_id, patient_id]), branch_key, patient_id, mrn, gender, birth_date, nationality, is_saudi, marital_status, occupation, registered_date, registered_dept, status, is_chronic, is_at_risk, is_merged, person_key, person_key_source)`
  - `dim_patient_pii(patient_key, branch_key, patient_id, mrn, full_name, full_name_ar, national_id, passport_no, border_no, mobile_no, email_address)`

- [ ] **Step 1: Write the tests**

Append to `_conformed__models.yml`:

```yaml
  - name: dim_patient
    columns:
      - name: patient_key
        tests: [unique, not_null]
      - name: person_key
        tests: [not_null]
      - name: gender
        tests:
          - accepted_values:
              values: ["Male", "Female", "Unknown"]
      - name: person_key_source
        tests:
          - accepted_values:
              values: ["National id or iqama", "Passport", "Border number", "Local", "Unknown"]
  - name: dim_patient_pii
    columns:
      - name: patient_key
        tests:
          - unique
          - not_null
          - relationships:
              to: ref('dim_patient')
              field: patient_key
```

`hnh_dwh/tests/hnh/assert_dim_patient_keeps_all_patients.sql`:

```sql
-- Review focus 3: a patient whose nationality, marital or occupation code is
-- missing from codes_data must still be in the dimension.
select 'patient count differs from staging' as failure, s.n as staged, d.n as in_dimension
from (select count() as n from {{ ref('stg_oasis__patients') }}) as s
cross join (select count() as n from {{ ref('dim_patient') }} where patient_key != -1) as d
where s.n != d.n
```

`hnh_dwh/tests/hnh/assert_dim_patient_has_no_pii.sql`:

```sql
-- dim_patient must never carry a name, identifier or contact column.
select name
from system.columns
where database = '{{ ref("dim_patient").schema }}'
  and table = '{{ ref("dim_patient").identifier }}'
  and (name like '%name%' or name like '%national_id%' or name like '%passport%'
       or name like '%border%' or name like '%mobile%' or name like '%email%')
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_dim_patient_keeps_all_patients`
Expected: a compilation error: `depends on a node named 'dim_patient' which was not found`.

- [ ] **Step 3: Write `dim_patient`**

```sql
{{ config(order_by='patient_key') }}

with mrn as (
    select branch_id, patient_id, min(user_file_id) as mrn
    from {{ ref('stg_oasis__patient_files') }}
    where patient_id is not null and user_file_id is not null
    group by branch_id, patient_id
),

ids as (
    select
        i.branch_id   as branch_id,
        i.patient_id  as patient_id,
        minIf(i.id_number, d.description_upper in ('NATIONAL NUMBER', 'IQAMA')) as national_id,
        minIf(i.id_number, d.description_upper = 'PASSPORT')                    as passport_no,
        minIf(i.id_number, d.description_upper = 'BOARDER NUMBER')              as border_no
    from {{ ref('stg_oasis__patient_ids') }} as i
    inner join {{ ref('int_code_decode') }} as d
        on d.branch_id = i.branch_id and d.code = i.id_type_code
    where i.patient_id is not null and i.id_number is not null
    group by i.branch_id, i.patient_id
)

select * from (

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.patient_id']) }} as patient_key,
    p.branch_id                                              as branch_key,
    toNullable(p.patient_id)                                 as patient_id,
    mrn.mrn                                                  as mrn,
    multiIf(p.sex = 'M', 'Male', p.sex = 'F', 'Female', 'Unknown') as gender,
    p.birth_date                                             as birth_date,
    ifNull(initcap(nat.description), 'Unknown')              as nationality,
    toUInt8(ifNull(nat.description_upper, '') = 'SAUDI ARABIA') as is_saudi,
    ifNull(initcap(mar.description), 'Unknown')              as marital_status,
    ifNull(initcap(occ.description), 'Unknown')              as occupation,
    p.registered_date                                        as registered_date,
    p.registered_dept                                        as registered_dept,
    p.status                                                 as status,
    p.is_chronic                                             as is_chronic,
    p.is_at_risk                                             as is_at_risk,
    toUInt8(p.merged_into_patient_id is not null)            as is_merged,
    toInt64(bitShiftRight(cityHash64(
        {{ hnh_person_identifier('ids.national_id', 'ids.passport_no', 'ids.border_no', 'p.branch_id', 'p.patient_id') }}
    ), 1))                                                   as person_key,
    {{ hnh_person_identifier_source('ids.national_id', 'ids.passport_no', 'ids.border_no') }} as person_key_source
from {{ ref('stg_oasis__patients') }} as p
left join mrn on mrn.branch_id = p.branch_id and mrn.patient_id = p.patient_id
left join ids on ids.branch_id = p.branch_id and ids.patient_id = p.patient_id
left join {{ ref('int_code_decode') }} as nat on nat.branch_id = p.branch_id and nat.code = p.nationality_code
left join {{ ref('int_code_decode') }} as mar on mar.branch_id = p.branch_id and mar.code = p.marital_code
left join {{ ref('int_code_decode') }} as occ on occ.branch_id = p.branch_id and occ.code = p.occupation_code

union all

select
    toInt64(-1), toUInt8(0), null, null, 'Unknown', null, 'Unknown', toUInt8(0), 'Unknown', 'Unknown',
    null, null, null, toUInt8(0), toUInt8(0), toUInt8(0), toInt64(-1), 'Unknown'

)
{{ hnh_settings() }}
```

- [ ] **Step 4: Write `dim_patient_pii`**

```sql
{{ config(order_by='patient_key') }}

with mrn as (
    select branch_id, patient_id, min(user_file_id) as mrn
    from {{ ref('stg_oasis__patient_files') }}
    where patient_id is not null and user_file_id is not null
    group by branch_id, patient_id
),

ids as (
    select
        i.branch_id   as branch_id,
        i.patient_id  as patient_id,
        minIf(i.id_number, d.description_upper in ('NATIONAL NUMBER', 'IQAMA')) as national_id,
        minIf(i.id_number, d.description_upper = 'PASSPORT')                    as passport_no,
        minIf(i.id_number, d.description_upper = 'BOARDER NUMBER')              as border_no
    from {{ ref('stg_oasis__patient_ids') }} as i
    inner join {{ ref('int_code_decode') }} as d
        on d.branch_id = i.branch_id and d.code = i.id_type_code
    where i.patient_id is not null and i.id_number is not null
    group by i.branch_id, i.patient_id
)

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.patient_id']) }} as patient_key,
    p.branch_id                as branch_key,
    p.patient_id               as patient_id,
    mrn.mrn                    as mrn,
    nullIf(replaceRegexpAll(trimBoth(concat(
        ifNull(p.name_1, ''), ' ', ifNull(p.name_2, ''), ' ', ifNull(p.name_3, ''), ' ', ifNull(p.family_name, '')
    )), '\\s+', ' '), '')      as full_name,
    nullIf(replaceRegexpAll(trimBoth(concat(
        ifNull(p.name_ar_1, ''), ' ', ifNull(p.name_ar_2, ''), ' ', ifNull(p.name_ar_3, ''), ' ', ifNull(p.family_name_ar, '')
    )), '\\s+', ' '), '')      as full_name_ar,
    ids.national_id            as national_id,
    ids.passport_no            as passport_no,
    ids.border_no              as border_no,
    p.mobile_no                as mobile_no,
    p.email_address            as email_address
from {{ ref('stg_oasis__patients') }} as p
left join mrn on mrn.branch_id = p.branch_id and mrn.patient_id = p.patient_id
left join ids on ids.branch_id = p.branch_id and ids.patient_id = p.patient_id
{{ hnh_settings() }}
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select dim_patient dim_patient_pii assert_dim_patient_keeps_all_patients assert_dim_patient_has_no_pii`
Expected: 2 tables created, all tests pass.

- [ ] **Step 6: Profile the person key**

Run: `python scripts/run_dbt.py show --inline "select person_key_source, count() as patients, uniqExact(person_key) as persons from {{ ref('dim_patient') }} where patient_key != -1 group by person_key_source order by patients desc"`
Expected: `National id or iqama` is by far the largest source, and its `persons` is lower than `patients` (the same person registered in more than one branch). Record the four counts in the commit message.

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed hnh_dwh/tests/hnh/assert_dim_patient_keeps_all_patients.sql hnh_dwh/tests/hnh/assert_dim_patient_has_no_pii.sql
git commit -m "Add patient dimension with group-wide person key and separate PII table

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Staff dimension

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_staff.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_dim_staff_row_count.sql`

**Interfaces:**
- Consumes: `stg_oasis__staff`, `stg_oasis__staff_posts`, `stg_oasis__positions`, `stg_oasis__staff_types`, `stg_oasis__staff_type_classifications`, `stg_oasis__staff_contracts`, `stg_oasis__doctor_departments`, `stg_oasis__personnel_documents` (Task 5); `int_code_decode` (Task 4); `int_department_conformed` (Task 7); `stg_ref__unified_department`, `stg_ref__clinic_duration`, `stg_ref__termination_reason` (Task 3).
- Produces: `dim_staff(staff_key = hnh_surrogate_key([branch_id, staff_id]), branch_key, staff_id, staff_name, staff_name_ar, gender, nationality, is_saudi, staff_grade, classification, category, med_nonmed, is_consultant, position_name, home_department_key, specialty, unified_specialty, is_non_admitting_specialty, is_high_value_specialty, clinic_duration_hours, slots_per_hour, scfhs_licence_no, contract_status, termination_date, termination_reason, service_start_date, national_id_hash)`

- [ ] **Step 1: Write the tests**

Append to `_conformed__models.yml`:

```yaml
  - name: dim_staff
    columns:
      - name: staff_key
        tests: [unique, not_null]
      - name: unified_specialty
        tests: [not_null]
      - name: contract_status
        tests:
          - accepted_values:
              values: ["Active", "Terminated", "No contract", "Unknown"]
      - name: home_department_key
        tests:
          - relationships:
              to: ref('dim_department')
              field: department_key
```

`hnh_dwh/tests/hnh/assert_dim_staff_row_count.sql`:

```sql
-- Review focus 4: tied posts, several licence documents or several contracts
-- must not multiply staff rows.
select 'staff count differs from staging' as failure, s.n as staged, d.n as in_dimension
from (select count() as n from {{ ref('stg_oasis__staff') }} where staff_id is not null) as s
cross join (select count() as n from {{ ref('dim_staff') }} where staff_key != -1) as d
where s.n != d.n
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_dim_staff_row_count`
Expected: a compilation error: `depends on a node named 'dim_staff' which was not found`.

- [ ] **Step 3: Write `dim_staff`**

```sql
{{ config(order_by='staff_key') }}

with latest_post as (
    -- Latest post by start; ties broken by the highest posts_id.
    select
        branch_id, staff_id,
        argMax(work_entity, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), ifNull(posts_id, 0)))   as work_entity,
        argMax(position_type, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), ifNull(posts_id, 0))) as position_type
    from {{ ref('stg_oasis__staff_posts') }}
    where staff_id is not null
    group by branch_id, staff_id
),

latest_contract as (
    select
        branch_id, staff_id,
        argMax(terminated_at, tuple(ifNull(started_at, toDate32('1970-01-01')), staff_contract_no))           as terminated_at,
        argMax(termination_reason_code, tuple(ifNull(started_at, toDate32('1970-01-01')), staff_contract_no)) as termination_reason_code
    from {{ ref('stg_oasis__staff_contracts') }}
    where staff_id is not null
    group by branch_id, staff_id
),

doctor_department as (
    select branch_id, staff_id,
           argMax(department, ifNull(created_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh'))) as department
    from {{ ref('stg_oasis__doctor_departments') }}
    where staff_id is not null and department is not null
    group by branch_id, staff_id
),

classification as (
    select branch_id, staff_type,
           any(classification) as classification, any(category) as category, any(med_nonmed) as med_nonmed
    from {{ ref('stg_oasis__staff_type_classifications') }}
    group by branch_id, staff_type
),

licence as (
    select pd.branch_id as branch_id, pd.staff_id as staff_id,
           argMax(pd.doc_number, tuple(ifNull(pd.valid_from, toDate32('1970-01-01')), pd.document_id)) as licence_no
    from {{ ref('stg_oasis__personnel_documents') }} as pd
    inner join {{ ref('int_code_decode') }} as d
        on d.branch_id = pd.branch_id and d.code = pd.doc_type
    where pd.staff_id is not null
      and pd.doc_number is not null
      and d.description_upper = 'SAUDI COMMISSION FOR HEALTH SPECIALISTS'
    group by pd.branch_id, pd.staff_id
),

base as (
    select
        s.branch_id                as branch_id,
        s.staff_id                 as staff_id,
        s.name_1 as name_1, s.name_2 as name_2, s.name_3 as name_3, s.family_name as family_name,
        s.name_ar_1 as name_ar_1, s.name_ar_2 as name_ar_2, s.name_ar_3 as name_ar_3, s.family_name_ar as family_name_ar,
        s.sex                      as sex,
        s.staff_type               as staff_type,
        s.nationality_code         as nationality_code,
        s.service_start_date       as service_start_date,
        s.national_id              as national_id,
        lp.work_entity             as home_work_entity,
        lp.position_type           as position_type,
        hd.work_entity is not null as has_home_department,
        lc.staff_id is not null    as has_contract,
        lc.terminated_at           as terminated_at,
        lc.termination_reason_code as termination_reason_code,
        upper(coalesce(dd.department, hd.service_department_name, hd.department_name)) as specialty_upper,
        lic.licence_no             as licence_no
    from {{ ref('stg_oasis__staff') }} as s
    left join latest_post as lp on lp.branch_id = s.branch_id and lp.staff_id = s.staff_id
    left join latest_contract as lc on lc.branch_id = s.branch_id and lc.staff_id = s.staff_id
    left join doctor_department as dd on dd.branch_id = s.branch_id and dd.staff_id = s.staff_id
    left join {{ ref('int_department_conformed') }} as hd
        on hd.branch_id = s.branch_id and hd.work_entity = lp.work_entity
    left join licence as lic on lic.branch_id = s.branch_id and lic.staff_id = s.staff_id
    where s.staff_id is not null
)

select * from (

select
    {{ hnh_surrogate_key(['b.branch_id', 'b.staff_id']) }}   as staff_key,
    b.branch_id                                              as branch_key,
    toNullable(b.staff_id)                                   as staff_id,
    nullIf(replaceRegexpAll(trimBoth(concat(
        initcap(concat(ifNull(b.name_1, ''), ' ', ifNull(b.name_2, ''), ' ', ifNull(b.name_3, ''))), ' ', upper(ifNull(b.family_name, ''))
    )), '\\s+', ' '), '')                                    as staff_name,
    nullIf(replaceRegexpAll(trimBoth(concat(
        ifNull(b.name_ar_1, ''), ' ', ifNull(b.name_ar_2, ''), ' ', ifNull(b.name_ar_3, ''), ' ', ifNull(b.family_name_ar, '')
    )), '\\s+', ' '), '')                                    as staff_name_ar,
    multiIf(b.sex = 'M', 'Male', b.sex = 'F', 'Female', 'Unknown') as gender,
    ifNull(initcap(nat.description), 'Unknown')              as nationality,
    toUInt8(ifNull(nat.description_upper, '') = 'SAUDI ARABIA') as is_saudi,
    st.description                                           as staff_grade,
    cl.classification                                        as classification,
    cl.category                                              as category,
    cl.med_nonmed                                            as med_nonmed,
    toUInt8(ifNull(st.is_consultant, 0))                     as is_consultant,
    pos.description                                          as position_name,
    if(b.has_home_department, {{ hnh_surrogate_key(['b.branch_id', 'b.home_work_entity']) }}, toInt64(-1)) as home_department_key,
    ifNull(initcap(b.specialty_upper), 'Unknown')            as specialty,
    ifNull(ud.unified_department, 'Not Mapped')              as unified_specialty,
    toUInt8(ifNull(ud.not_admitting, 0))                     as is_non_admitting_specialty,
    toUInt8(ifNull(ud.high_value, 0))                        as is_high_value_specialty,
    cd.clinic_duration_hours                                 as clinic_duration_hours,
    cd.slots_per_hour                                        as slots_per_hour,
    b.licence_no                                             as scfhs_licence_no,
    multiIf(not b.has_contract, 'No contract', b.terminated_at is null, 'Active', 'Terminated') as contract_status,
    b.terminated_at                                          as termination_date,
    tr.unified_reason                                        as termination_reason,
    b.service_start_date                                     as service_start_date,
    if(b.national_id is null, null,
       toInt64(bitShiftRight(cityHash64(concat('N:', {{ hnh_normalise_identifier('b.national_id') }})), 1))) as national_id_hash
from base as b
left join {{ ref('int_code_decode') }} as nat on nat.branch_id = b.branch_id and nat.code = b.nationality_code
left join {{ ref('stg_oasis__staff_types') }} as st on st.branch_id = b.branch_id and st.staff_type = b.staff_type
left join classification as cl on cl.branch_id = b.branch_id and cl.staff_type = b.staff_type
left join {{ ref('stg_oasis__positions') }} as pos on pos.branch_id = b.branch_id and pos.position_type = b.position_type
left join {{ ref('stg_ref__unified_department') }} as ud on ud.department = b.specialty_upper
left join {{ ref('stg_ref__clinic_duration') }} as cd on cd.specialty = b.specialty_upper
left join {{ ref('stg_ref__termination_reason') }} as tr
    on tr.branch_id = b.branch_id and tr.termination_reason_code = b.termination_reason_code

union all

select
    toInt64(-1), toUInt8(0), null, 'Unknown', null, 'Unknown', 'Unknown', toUInt8(0), null, null, null, null,
    toUInt8(0), null, toInt64(-1), 'Unknown', 'Unknown', toUInt8(0), toUInt8(0), null, null, null,
    'Unknown', null, null, null, null

)
{{ hnh_settings() }}
```

`national_id_hash` uses the same normalisation and `N:` prefix as `dim_patient.person_key`, and is the hook for linking to the Fusion employee dimension in Phase 4. The raw national id is not stored.

`home_department_key` is `-1` when the staff member has no post, or when the post points to a work entity that is missing from `work_entities_data`.

- [ ] **Step 4: Build and test**

Run: `python scripts/run_dbt.py build --select dim_staff assert_dim_staff_row_count`
Expected: 1 table created, all tests pass.

- [ ] **Step 5: Spot-check**

Run: `python scripts/run_dbt.py show --inline "select contract_status, count() as n, countIf(unified_specialty = 'Not Mapped') as unmapped, countIf(scfhs_licence_no is not null) as licensed from {{ ref('dim_staff') }} group by contract_status order by n desc"`
Expected: four or fewer statuses; a non-zero `licensed` count for `Active`. Record the unmapped count in the commit message.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed hnh_dwh/tests/hnh/assert_dim_staff_row_count.sql
git commit -m "Add staff dimension

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Bed, eligibility and decode dimensions

**Files:**
- Create in `hnh_dwh/models/hnh/marts/conformed/`: `dim_bed.sql`, `dim_eligibility_type.sql`, `dim_appointment_outcome.sql`, `dim_discharge_outcome.sql`, `dim_er_priority.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/warn_unmapped_bed_classification.sql`

**Interfaces:**
- Consumes: `stg_oasis__bed_slots`, `stg_oasis__bed_details`, `stg_oasis__bed_classes` (Task 5); `stg_oasis__eligibility_types`, `stg_oasis__er_priorities`, `int_code_decode` (Task 4); `stg_ref__bed_classification` (Task 3); `int_department_conformed` (Task 7); `hnh_outcome_group`, `hnh_discharge_outcome_group`, `hnh_care_type` (Task 2).
- Produces:
  - `dim_bed(bed_key = hnh_surrogate_key([branch_id, bed_location]), branch_key, bed_location, current_department_key, current_ward, bed_class, bed_gender, classification, is_critical, current_slot_status, is_currently_available)`
  - `dim_eligibility_type(eligibility_type_key = hnh_surrogate_key([branch_id, eligibility_type]), branch_key, eligibility_type, description, care_type, free_follow_up_days)`
  - `dim_appointment_outcome(outcome_key = hnh_surrogate_key([branch_id, code]), branch_key, outcome_code, outcome, outcome_group, is_cancelled)`
  - `dim_discharge_outcome(discharge_outcome_key = hnh_surrogate_key([branch_id, code]), branch_key, outcome_code, outcome, outcome_group, moh_code)`
  - `dim_er_priority(er_priority_key = hnh_surrogate_key([branch_id, priority]), branch_key, priority, description, ctas_level, colour, target_minutes)`

- [ ] **Step 1: Write the tests**

Append to `_conformed__models.yml`:

```yaml
  - name: dim_bed
    columns:
      - name: bed_key
        tests: [unique, not_null]
      - name: classification
        tests:
          - accepted_values:
              values: ["Critical", "Intermediate Care", "Non Critical", "Non-Admitting Unit", "Not Mapped", "Unknown"]
      - name: current_department_key
        tests:
          - relationships:
              to: ref('dim_department')
              field: department_key
  - name: dim_eligibility_type
    columns:
      - name: eligibility_type_key
        tests: [unique, not_null]
  - name: dim_appointment_outcome
    columns:
      - name: outcome_key
        tests: [unique, not_null]
      - name: outcome_group
        tests:
          - accepted_values:
              values: ["Attended", "Cancelled", "Rescheduled", "No-show recorded", "Left without being seen", "Admitted", "Referred", "Left against advice", "Died", "Other", "Unknown"]
  - name: dim_discharge_outcome
    columns:
      - name: discharge_outcome_key
        tests: [unique, not_null]
      - name: outcome_group
        tests:
          - accepted_values:
              values: ["Normal discharge", "Left against advice", "Died", "Transferred out", "Transferred to another episode", "Wrong admission", "Absconded", "Other", "Unknown"]
  - name: dim_er_priority
    columns:
      - name: er_priority_key
        tests: [unique, not_null]
```

`hnh_dwh/tests/hnh/warn_unmapped_bed_classification.sql`:

```sql
{{ config(severity='warn') }}
-- Beds with no classification are never counted as Critical. Review the mapping when this grows.
select branch_key, count() as unmapped_beds
from {{ ref('dim_bed') }}
where classification = 'Not Mapped'
group by branch_key
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select warn_unmapped_bed_classification`
Expected: a compilation error: `depends on a node named 'dim_bed' which was not found`.

- [ ] **Step 3: Write `dim_bed`**

```sql
{{ config(order_by='bed_key') }}

with from_details as (
    -- Latest known ward, class and gender for every bed location that ever held a row.
    select
        branch_id, bed_location,
        argMax(work_entity, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), bed_detail_id)) as work_entity,
        argMax(bed_class, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), bed_detail_id))   as bed_class,
        argMax(bed_sex, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), bed_detail_id))     as bed_sex
    from {{ ref('stg_oasis__bed_details') }}
    where bed_location is not null
    group by branch_id, bed_location
),

locations as (
    select branch_id, bed_location from from_details
    union distinct
    select branch_id, bed_location from {{ ref('stg_oasis__bed_slots') }} where bed_location is not null
)

select * from (

select
    {{ hnh_surrogate_key(['l.branch_id', 'l.bed_location']) }} as bed_key,
    l.branch_id                                                as branch_key,
    toNullable(l.bed_location)                                 as bed_location,
    ifNull(dep.department_key_value, toInt64(-1))              as current_department_key,
    dep.department_name                                        as current_ward,
    bc.description                                             as bed_class,
    multiIf(fd.bed_sex = 'M', 'Male', fd.bed_sex = 'F', 'Female', 'Any') as bed_gender,
    ifNull(cls.classification, 'Not Mapped')                   as classification,
    toUInt8(ifNull(cls.classification, '') = 'Critical')       as is_critical,
    st.description_upper                                       as current_slot_status,
    toUInt8(s.bed_location is not null
            and ifNull(st.description_upper, '') not in ('NO BED IN SLOT', 'NOT AVAILABLE')) as is_currently_available
from locations as l
left join from_details as fd on fd.branch_id = l.branch_id and fd.bed_location = l.bed_location
left join {{ ref('stg_oasis__bed_slots') }} as s on s.branch_id = l.branch_id and s.bed_location = l.bed_location
left join (
    select branch_id, work_entity, department_name,
           {{ hnh_surrogate_key(['branch_id', 'work_entity']) }} as department_key_value
    from {{ ref('int_department_conformed') }}
) as dep
    on dep.branch_id = l.branch_id and dep.work_entity = coalesce(s.work_entity, fd.work_entity)
left join {{ ref('stg_oasis__bed_classes') }} as bc on bc.branch_id = l.branch_id and bc.bed_class = fd.bed_class
left join {{ ref('stg_ref__bed_classification') }} as cls on cls.branch_id = l.branch_id and cls.bed_location = l.bed_location
left join {{ ref('int_code_decode') }} as st on st.branch_id = l.branch_id and st.code = s.slot_status

union all

select toInt64(-1), toUInt8(0), null, toInt64(-1), null, null, 'Any', 'Unknown', toUInt8(0), null, toUInt8(0)

)
{{ hnh_settings() }}
```

A bed location can move between wards over time, so the key is `(branch_id, bed_location)` and the ward here is the current one. Facts carry their own ward key from the stay segment.

- [ ] **Step 4: Write `dim_eligibility_type`**

```sql
{{ config(order_by='eligibility_type_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'eligibility_type']) }} as eligibility_type_key,
    branch_id                              as branch_key,
    toNullable(eligibility_type)           as eligibility_type,
    ifNull(description, 'Not named')       as description,
    {{ hnh_care_type('attendance_type') }} as care_type,
    free_follow_up_days                    as free_follow_up_days
from {{ ref('stg_oasis__eligibility_types') }}

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', null
```

- [ ] **Step 5: Write the decode dimensions**

`dim_appointment_outcome.sql`:

```sql
{{ config(order_by='outcome_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'code']) }}   as outcome_key,
    branch_id                                        as branch_key,
    toNullable(code)                                 as outcome_code,
    ifNull(initcap(description), 'Not named')        as outcome,
    {{ hnh_outcome_group('description_upper') }}     as outcome_group,
    toUInt8({{ hnh_outcome_group('description_upper') }} in ('Cancelled', 'Rescheduled')) as is_cancelled
from {{ ref('int_code_decode') }}
where code_type = 21

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', toUInt8(0)
```

`dim_discharge_outcome.sql`:

```sql
{{ config(order_by='discharge_outcome_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'code']) }}            as discharge_outcome_key,
    branch_id                                                 as branch_key,
    toNullable(code)                                          as outcome_code,
    ifNull(initcap(description), 'Not named')                 as outcome,
    {{ hnh_discharge_outcome_group('description_upper') }}    as outcome_group,
    moh_code                                                  as moh_code
from {{ ref('int_code_decode') }}
where code_type = 10

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', null
```

`dim_er_priority.sql`:

```sql
{{ config(order_by='er_priority_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'priority']) }}  as er_priority_key,
    branch_id                                           as branch_key,
    toNullable(priority)                                as priority,
    ifNull(description, 'Not named')                    as description,
    toUInt8OrNull(extract(ifNull(description, ''), '(?i)level\\s*([1-5])')) as ctas_level,
    colour                                              as colour,
    target_minutes                                      as target_minutes
from {{ ref('stg_oasis__er_priorities') }}

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', null, null, null
```

- [ ] **Step 6: Build and test**

Run: `python scripts/run_dbt.py build --select dim_bed dim_eligibility_type dim_appointment_outcome dim_discharge_outcome dim_er_priority warn_unmapped_bed_classification`
Expected: 5 tables created, no errors. `warn_unmapped_bed_classification` reports a warning with up to 8 rows (about 284 beds in total).

- [ ] **Step 7: Spot-check the outcome grouping**

Run: `python scripts/run_dbt.py show --inline "select outcome_group, count() as codes, groupUniqArray(5)(outcome) as examples from {{ ref('dim_appointment_outcome') }} group by outcome_group order by codes desc" --limit 20`
Expected: `Cancelled` and `Rescheduled` contain only cancellation and rescheduling descriptions. Read the `Other` examples: anything that is clearly an attendance, cancellation or referral means a rule is missing from `hnh_outcome_group` — add it there, add a line to `assert_hnh_rule_macros.sql`, and rebuild.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed hnh_dwh/tests/hnh/warn_unmapped_bed_classification.sql
git commit -m "Add bed, eligibility and decode dimensions

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Security bridge and handoff documentation

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/sec_user_access.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml` (append)
- Test: `hnh_dwh/tests/hnh/assert_sec_no_access_without_branch.sql`, `hnh_dwh/tests/hnh/warn_sec_users_without_access.sql`
- Create: `docs/receiving_project_config.md`

**Interfaces:**
- Consumes: `stg_ref__bi_users`, `stg_ref__branch` (Task 3); `dim_branch` (Task 6).
- Produces: `sec_user_access(user_name, login_name, branch_key, unified_specialty, is_admin)` — one row per user, permitted branch and optional specialty.

- [ ] **Step 1: Write the tests**

Append to `_conformed__models.yml`:

```yaml
  - name: sec_user_access
    tests:
      - hnh_unique_combination:
          columns: [login_name, branch_key, unified_specialty]
    columns:
      - name: login_name
        tests: [not_null]
      - name: branch_key
        tests:
          - not_null
          - relationships:
              to: ref('dim_branch')
              field: branch_key
```

`hnh_dwh/tests/hnh/assert_sec_no_access_without_branch.sql`:

```sql
-- Review focus 5: fail closed. A non-admin user gets access only to branches
-- named on their own source rows.
select a.user_name, a.branch_key
from {{ ref('sec_user_access') }} as a
left join {{ ref('stg_ref__bi_users') }} as u
    on u.user_name = a.user_name and u.branch_id = a.branch_key
where a.is_admin = 0 and u.user_name is null
{{ hnh_settings() }}
```

`hnh_dwh/tests/hnh/warn_sec_users_without_access.sql`:

```sql
{{ config(severity='warn') }}
-- Users in the source who end up with no access at all. Each needs a branch assigned.
select u.user_name
from (select distinct user_name from {{ ref('stg_ref__bi_users') }}) as u
left join (select distinct user_name from {{ ref('sec_user_access') }}) as a on a.user_name = u.user_name
where a.user_name is null
{{ hnh_settings() }}
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `python scripts/run_dbt.py test --select assert_sec_no_access_without_branch`
Expected: a compilation error: `depends on a node named 'sec_user_access' which was not found`.

- [ ] **Step 3: Write `sec_user_access`**

```sql
{{ config(order_by='(login_name, branch_key)') }}

with users as (
    select user_name, branch_id, unified_specialty, max(is_admin) over (partition by user_name) as is_admin
    from {{ ref('stg_ref__bi_users') }}
    where user_name != ''
),

admins as (
    -- An administrator sees every branch and has no specialty restriction.
    select distinct u.user_name as user_name, b.branch_id as branch_key,
           cast(null as Nullable(String)) as unified_specialty, toUInt8(1) as is_admin
    from users as u
    cross join {{ ref('stg_ref__branch') }} as b
    where u.is_admin = 1
),

restricted as (
    select distinct user_name, assumeNotNull(branch_id) as branch_key, unified_specialty, toUInt8(0) as is_admin
    from users
    where is_admin = 0 and branch_id is not null
)

select
    user_name                                                       as user_name,
    concat('{{ var("hnh_ssas_machine_name") }}', '\\', user_name)   as login_name,
    branch_key                                                      as branch_key,
    unified_specialty                                               as unified_specialty,
    is_admin                                                        as is_admin
from (
    select * from admins
    union all
    select * from restricted
)
```

`login_name` is the value SSAS `USERNAME()` returns for a local account: machine name, a backslash, the user name. The machine name comes from the dbt variable `hnh_ssas_machine_name`.

- [ ] **Step 4: Build and test**

Run: `python scripts/run_dbt.py build --select sec_user_access assert_sec_no_access_without_branch warn_sec_users_without_access`
Expected: 1 table created, no errors. `warn_sec_users_without_access` reports a warning listing the users who have neither a branch nor the admin flag.

- [ ] **Step 5: Spot-check**

Run: `python scripts/run_dbt.py show --inline "select is_admin, uniqExact(user_name) as users, count() as access_rows, countIf(unified_specialty is not null) as specialty_rows, any(login_name) as example_login from {{ ref('sec_user_access') }} group by is_admin"`
Expected: about 79 admin users with 8 rows each (632 rows); the non-admin row count equals the number of distinct user and branch pairs in the source; `example_login` has the form `SSAS-SERVER\name`.

- [ ] **Step 6: Write the receiving-project notes**

`docs/receiving_project_config.md`:

````markdown
# Moving the hnh models into the existing dbt project

## What to copy

| From this repository | To the receiving project |
|---|---|
| `hnh_dwh/models/hnh/` | `models/hnh/` |
| `hnh_dwh/macros/hnh/` | `macros/hnh/` |
| `hnh_dwh/tests/hnh/` | `tests/hnh/` |

Nothing else is needed. There are no packages and no seeds.

## Add to the receiving `dbt_project.yml`

Replace `<project_name>` with the receiving project's `name`.

```yaml
vars:
  hnh_history_start_date: "2022-01-01"
  hnh_ssas_machine_name: "SSAS-SERVER"   # machine name of the SSAS server

models:
  <project_name>:
    hnh:
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
```

## Schema names

The models must land in the ClickHouse databases `stg`, `int` and `gold`. dbt's default behaviour prefixes a custom schema with the target schema (`default_stg`). If the receiving project does not already override `generate_schema_name`, add this macro. It changes naming for every model in the project that sets `+schema`, so check existing models first.

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

## Source tables already modelled in the receiving project

Every source table is referenced through `source()` and declared in two files:

- `models/hnh/staging/oasis/_oasis__sources.yml`
- `models/hnh/staging/reference/_reference__sources.yml`

If the receiving project already declares a source named `oasis` or `reference`, rename the source in these two files and in the staging models' `source('oasis', …)` calls.

## Reference tables that must exist in `default`

Loaded once by `scripts/load_reference_data.py` and `scripts/load_hijri_calendar.py`: `budget_data`, `bi_users`, `map_unified_department_v2`, `map_bed_classification`, `map_ward_tower`, `map_clinic_duration`, `map_clinic_count`, `map_home_care_entity`, `map_termination_reason`, `map_hijri_calendar`, `map_public_holiday`. Re-run `load_hijri_calendar.py` once a year to extend the calendar.

## Running

```bash
dbt build --select tag:hnh          # everything, in dependency order, with tests
dbt build --select tag:hnh_gold+    # marts only
dbt source freshness --select source:oasis
```

Tests named `warn_*` report data gaps and never fail a run. Every other test failing means the SSAS model must not be processed.

## Profile setting

The one incremental model (`agg_clinic_capacity_daily`) uses the `delete+insert` strategy, which needs `use_lw_deletes: true` in the ClickHouse profile.

## Version notes

Developed on dbt-core 1.11.12 and dbt-clickhouse 1.9.8. YAML uses the `tests:` key, which every dbt version accepts. Rule logic is tested through macros with literal inputs (`tests/hnh/assert_hnh_*_macros.sql`), so those tests run on any version.
````

- [ ] **Step 7: Run the whole of Phase 1A once**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: every model builds, `ERROR=0`. Warnings come only from tests named `warn_*`.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed hnh_dwh/tests/hnh docs/receiving_project_config.md
git commit -m "Add security bridge and receiving-project notes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```
