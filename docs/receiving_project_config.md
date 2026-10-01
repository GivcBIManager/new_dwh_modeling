# Moving the hnh models into the receiving dbt project

Receiving project: GitHub `GivcBIManager/dlt`, folder `dbt/` (dbt project `oasis`, profile `oasis`, `dbt-clickhouse>=1.9,<1.10`).

## What to copy

| From this repository | To `dbt/` |
|---|---|
| `hnh_dwh/models/hnh/` | `models/hnh/` |
| `hnh_dwh/macros/hnh/` | `macros/hnh/` |
| `hnh_dwh/tests/hnh/` | `tests/hnh/` |

Do not copy our `generate_schema_name.sql`: `dbt/macros/generate_schema_name.sql` is already identical, so `+schema: stg|int|gold` lands in the databases `stg`, `int` and `gold`. There are no packages and no seeds.

## Add to `dbt/dbt_project.yml`

```yaml
vars:
  hnh_oasis_as_ref: true                 # staging reads the oasis_lake models via ref(), so dbt orders the DAG
  hnh_oasis_source_only: ['operating_diary_slots', 'operating_slot_details']   # no oasis_lake model yet; read as sources
  hnh_history_start_date: "2022-01-01"
  hnh_ssas_machine_name: "SSAS-SERVER"   # machine name of the SSAS server

models:
  oasis:
    hnh:                                 # new block, next to fusion: and oasis_lake:
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

data_tests:                              # top level; makes --select tag:hnh run the singular tests too
  oasis:
    hnh:
      +tags: ["hnh"]
```

Merge into the existing `vars:`, `models: oasis:` and `data_tests:` keys if they exist. The project default is `+materialized: table`; the `hnh` block overrides it for staging (views).

## How the models read Oasis

With `hnh_oasis_as_ref: true`, staging models call `ref('<raw_table>')` on the `oasis_lake` incremental models (`appointments`, `codes_data`, ...; the names match the raw tables), so a `dbt build --select tag:hnh+` builds upstream first. With `false` they use `source('oasis', ...)`. Two used tables have no `oasis_lake` model yet: `operating_diary_slots` and `operating_slot_details`. They are listed in var `hnh_oasis_source_only` and are always read with `source('oasis', ...)`, whatever `hnh_oasis_as_ref` says. Remove a table from that list once an upstream model for it exists. The `hnh` YAML declares a source named `oasis` and one named `reference`; the project's own sources are `oasis_lake` and `ofusion_conformed`, so there is no clash.

## Aliased models

`hnh_dim_branch` and `hnh_dim_department` are built into `gold.dim_branch` and `gold.dim_department` (`alias`). The model names carry the `hnh_` prefix because `dim_branch` and `dim_department` already exist in `models/fusion/staging/conformed/`; dbt model names must be unique per project. Always `ref('hnh_dim_branch')` / `ref('hnh_dim_department')` in dbt code.

## Reference tables that must exist in `default`

Loaded once by `scripts/load_reference_data.py` and `scripts/load_hijri_calendar.py` (outside dbt): `branch_dict_source`, `map_purchasers`, `map_referral_policies`, `budget_data`, `bi_users`, `map_unified_department_v2`, `map_bed_classification`, `map_ward_tower`, `map_clinic_duration`, `map_clinic_count`, `map_home_care_entity`, `map_termination_reason`, `map_hijri_calendar`, `map_public_holiday`. Re-run `load_hijri_calendar.py` once a year to extend the calendar.

## Security table and dim_date

`gold.sec_user_access.login_name` is `<SSAS machine>\<user name>`. The source `UserName` already has an old domain prefix (for example `HNHRIYADH
ame`, `INMA-BINTELLIGE
ame`) in mixed case. The model keeps the part after the last backslash, lower-cased, as `user_name`, and puts the SSAS machine name in front of it. The original text is kept in `source_user_name`. The DAX comparison against `USERNAME()` must be case-insensitive (DAX `=` on text is case-insensitive). Administrators get every real branch (never branch 0) and keep the specialty of their own source rows.

`dim_date` offset columns: a positive value means the date is in the past (for example a day offset of 1 is yesterday).

## Running

```bash
dbt build --select tag:hnh          # all hnh models and tests, in dependency order
dbt build --select tag:hnh_gold+    # marts only
```

Tests named `warn_*` report data gaps and never fail a run. Any other failing test means the SSAS model must not be processed.

## Profile setting

Phase 1B adds an incremental model (`agg_clinic_capacity_daily`) with the `delete+insert` strategy. It needs `use_lw_deletes: true` in the ClickHouse profile. Not needed for Phase 1A.

## Version notes

Developed on dbt-core 1.11.12 and dbt-clickhouse 1.9.8. This repository's YAML uses the `tests:` key with top-level test arguments; the receiving project uses `data_tests:` with `arguments:`. dbt 1.11 accepts both and prints a deprecation warning (`MissingArgumentsPropertyInGenericTestDeprecation`) for the old style; move `columns:` under `arguments:` for `hnh_unique_combination` if you want it quiet. Rule logic is tested through macros with literal inputs (`tests/hnh/assert_hnh_*_macros.sql`).
