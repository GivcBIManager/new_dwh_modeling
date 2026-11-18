# Finance report settings

Two ClickHouse tables in database `default` on `172.22.25.214` hold what the finance report cannot get from Fusion:
- `map_finance_budget`: budget amounts per hospital, month and statement line;
- `map_finance_target`: finance KPI targets and their watch margin.

Design: `docs/superpowers/specs/2026-11-18-finance-report-design.md`.

## How a change works

Each table is a change log, as for the HR dashboard (`docs/hr_config.md`). To change something, **insert a new row** with the same key and the new values. The newest row for a key wins. To remove a key, insert a row with `is_deleted = 1`. Never update or delete rows: the old rows are the history.

Every row ends with the same four columns:

| Column | Value |
|---|---|
| `changed_at` | `now64(3)` |
| `changed_by` | your name |
| `change_note` | why, in a few words |
| `is_deleted` | `0`, or `1` to remove the key |

**First load.** `scripts\finance_config\apply_finance_config.ps1` creates the two tables (both start empty; `finance_config_seed.sql` holds only a comment). `-DryRun` shows what it would do and writes nothing. The first run writes to production ClickHouse: ask first.

**When it shows in the report.** After the nightly dbt build (`stg_ref__finance_*` and the models that read them) and `process.ps1 -Mode Daily`. Until then a change shows only after a dbt build and an SSAS process run by hand, both of which need the user's go-ahead.

**See the history of a key:**

```sql
SELECT * FROM default.map_finance_target WHERE kpi_code = 'FIN_NET_MARGIN' ORDER BY changed_at;
```

**Undo a change.** Insert the previous values again.

**Delete a key.** Insert its row again with `is_deleted = 1` (same key columns, any amount):

```sql
INSERT INTO default.map_finance_budget (branch_id, year, month, statement, line_code, amount, changed_at, changed_by, change_note, is_deleted)
VALUES (1, 2026, 1, 'IS', 'DC_EMPLOYEE', 0, now64(3), 'Your Name', 'wrong line', 1);
```

## Tables

### `map_finance_budget`: budget amounts

Key: `branch_id`, `year`, `month`, `statement`, `line_code`.

| Column | Meaning |
|---|---|
| `branch_id` | hospital 1-8 |
| `year`, `month` | calendar month, `month` 1-12 |
| `statement` | `IS` (income statement) or `BS` (balance sheet); upper-cased and trimmed by the staging model |
| `line_code` | `IS`: a `pl_line_code` of a detail line of `dim_pl_report_line` (for example `REV_CASH`, `DIS_CASH`, `DC_CONSUMABLES`, `DC_EMPLOYEE`); subtotals and `Not mapped` lines take no amount. `BS`: the lower-case FS caption as shown in `GL FS Monthly` |
| `amount` | SAR, **entered as a positive number** for revenue and costs alike. The model applies the line's sign (revenue positive, discounts and costs negative in the P&L Report) |

Sign convention: never type a minus sign to mean a cost. A negative `amount` is taken literally and reverses the line.

```sql
INSERT INTO default.map_finance_budget (branch_id, year, month, statement, line_code, amount, changed_at, changed_by, change_note, is_deleted) VALUES
    (1, 2026, 1, 'IS', 'DC_EMPLOYEE', 2500000, now64(3), 'Your Name', 'budget 2026 v1', 0),
    (1, 2026, 1, 'IS', 'REV_CASH', 9000000, now64(3), 'Your Name', 'budget 2026 v1', 0);
```

### `map_finance_target`: finance KPI targets

Key: `kpi_code`, `branch_id`, `year`.

| Column | Meaning |
|---|---|
| `kpi_code` | the finance KPI code |
| `branch_id` | `0` = all hospitals, 1-8 = one hospital (a hospital row beats the `0` row) |
| `year` | calendar year |
| `target_value` | the target, in the KPI's own unit |
| `watch_pct` | how far below the target still counts as Watch, as a fraction (`0.05` = 5%). `0` means the default `0.05` |

```sql
INSERT INTO default.map_finance_target (kpi_code, branch_id, year, target_value, watch_pct, changed_at, changed_by, change_note, is_deleted) VALUES
    ('FIN_NET_MARGIN', 0, 2026, 0.12, 0, now64(3), 'Your Name', 'target 2026', 0);
```
