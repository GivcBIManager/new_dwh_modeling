# HR dashboard settings

Every HR dashboard setting is a row in a ClickHouse table in database `default` on `172.22.25.214`:
- the KPI list and the metric definitions shown in the user guide;
- targets and watch values;
- the data quality issue catalogue (owner, severity, where to fix, how to fix).

The KPI formulas are measures in the SSAS model and are not edited here. Design: `docs/superpowers/specs/2026-11-02-hr-dashboard-design.md`.

## How a change works

Each table is a change log, as for the balanced scorecard (`docs/bsc_config.md`). To change something, **insert a new row** with the same key and the new values. The newest row for a key wins. To remove a key, insert a row with `is_deleted = 1`. Never update or delete rows: the old rows are the history.

Every row ends with the same four columns:

| Column | Value |
|---|---|
| `changed_at` | `now64(3)` |
| `changed_by` | your name |
| `change_note` | why, in a few words |
| `is_deleted` | `0`, or `1` to remove the key |

**First load.** `scripts\hr_config\apply_hr_config.ps1` creates the three tables and seeds `map_hr_kpi` and `map_hr_dq_issue` (`map_hr_target` starts empty). `-DryRun` shows what it would do and writes nothing. A table that already has rows is not seeded again. `-Update <file>` adds every INSERT of an update file. The first run writes to production ClickHouse: ask first.

**When it shows in the report.** The next morning, after the nightly build and SSAS refresh.

**See the history of a key:**

```sql
SELECT * FROM default.map_hr_target WHERE kpi_code = 'HR_TURNOVER' ORDER BY changed_at;
```

**Undo a change.** Insert the previous values again.

## Tables

### `map_hr_kpi`: the KPI and metric list

Key: `kpi_code`. One row per KPI (scored) or metric (defined in the guide, not scored).

| Column | Allowed values |
|---|---|
| `kind` | `kpi` (has a target and a status), `metric` (defined in the guide, not scored) |
| `kpi_name`, `short_label`, `definition`, `formula`, `source_system`, `grain`, `caveats` | text (they show in the user guide and on the KPI detail page) |
| `area` | `Size`, `Mix`, `Flow`, `Cost`, `Absence`, `Leave`, `Hiring`, `Productivity` |
| `direction` | `higher`, `lower`, `ceiling` (reads like `lower`), `on_target` (closer is better) |
| `value_format` | `num`, `pct`, `sar`, `days` |
| `display_order` | number |
| `measure_name` | the SSAS measure that gives the actual |
| `bsc_kpi_code` | the `map_bsc_kpi` code when the KPI is a balanced scorecard KPI, otherwise empty |
| `target_source` | `fixed` (from `map_hr_target`), `bsc` (the scorecard target), `none` |
| `needs_pay` | `1` when the actual needs pay access, otherwise `0` |
| `is_home_tile` | `1` for a tile on the home page, otherwise `0` |
| `status` | `active`, `parked` (shown as Parked, not scored) |

**Park a KPI.** Copy its current row with the latest values, set `status = 'parked'`, and insert it:

```sql
INSERT INTO default.map_hr_kpi
SELECT kpi_code, kind, kpi_name, short_label, area, definition, formula, source_system, grain, caveats, direction,
       value_format, display_order, measure_name, bsc_kpi_code, target_source, needs_pay, is_home_tile, 'parked',
       now64(3), 'bi_manager', 'waiting for HR to confirm the definition', 0
FROM default.map_hr_kpi WHERE kpi_code = 'HR_FEMALE_SHARE' ORDER BY changed_at DESC LIMIT 1;
```

A new KPI also needs its measure in the SSAS model. Add the row with `status = 'parked'` until the measure is deployed.

### `map_hr_target`: targets and watch values

Key: `kpi_code`, `branch_id`, `year`, `month`.
- `branch_id`: 0 = every hospital, 1–8 = one hospital (wins over 0).
- `month`: 0 = the whole year, 1–12 = one month (wins over 0).
- `target_value`: the value that is On track.
- `watch_value`: the value beyond which the KPI is At risk. Between the target and `watch_value` it is Watch. For `on_target` KPIs the distance from the target is compared with the distance from `watch_value` to the target.
- `scale_with_months`: 1 when an annual target is pro-rated by the months selected (turnover).
- `source_basis`: where the number comes from. A text that starts with `Placeholder` shows the target with a "P" mark and the word "placeholder" in the tooltip; any other text removes the mark.

The table starts empty. Placeholder targets are added by an update file and are listed with their numbers in the section below. KPIs with `target_source = 'bsc'` take the scorecard target and need no row here. A KPI with no target row shows No target yet.

**Replace a placeholder with a real target.** Insert a row with the same key. The new row wins and carries a `source_basis` that does not start with `Placeholder`:

```sql
INSERT INTO default.map_hr_target
  (kpi_code, branch_id, year, month, target_value, watch_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted)
VALUES ('HR_TURNOVER', 0, 2027, 0, 0.08, 0.10, 1, 'HR Director, FY2027 plan', now64(3), 'bi_manager', 'FY2027 target approved by HR', 0);
```

A hospital with its own target gets a second row with its `branch_id`; the network target is the average of the hospital targets.

**Placeholder targets inserted at launch:** none yet.

### `map_hr_dq_issue`: the data quality issue catalogue

Key: `issue_code`. One row per issue shown on the Data quality page. The records behind each issue come from the dbt models, not from this table.

| Column | Allowed values |
|---|---|
| `issue_name`, `how_to_fix` | text (shown on the Data quality page) |
| `area` | text (a grouping, for example `Linkage`, `Employee`, `Leave`, `Absence`, `Payroll`) |
| `fix_in` | `Fusion`, `Oasis`, `Oasis or Fusion`, `Fusion payroll`, `BI` |
| `owner` | the team that fixes it, for example `HR` or `BI` |
| `severity` | `High`, `Medium`, `Low` |
| `display_order` | number |
| `status` | `active`, `parked` (hidden from the page) |

The seed gives every issue owner `HR` (`BI` for unmapped pay codes) and severity `Medium`: they are placeholders for the HR team to confirm. To change one:

```sql
INSERT INTO default.map_hr_dq_issue
SELECT issue_code, issue_name, area, fix_in, 'HR Operations', 'High', how_to_fix, display_order, status,
       now64(3), 'bi_manager', 'owner and severity confirmed by HR', 0
FROM default.map_hr_dq_issue WHERE issue_code = 'DQ_FTE_ZERO' ORDER BY changed_at DESC LIMIT 1;
```

Parking an issue (`status = 'parked'`) also silences its dbt warn test, because the warn tests read `fact_hr_dq_record`, which keeps active issues only.

A new issue also needs a dbt check that finds its records. Add the catalogue row with `status = 'parked'` until the check is built.
