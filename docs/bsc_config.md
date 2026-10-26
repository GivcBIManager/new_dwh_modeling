# Balanced scorecard settings

Every scorecard setting is a row in a ClickHouse table in database `default` on `172.22.25.214`:
- the KPI list, targets and weights;
- thresholds, owners and hospital categories;
- manual monthly values, code lists and budgeted FTE.

The KPI formulas are measures in the SSAS model and are not edited here.

## How a change works

Each table is a change log. To change something, **insert a new row** with the same key and the new values. The newest row for a key wins. To remove a key, insert a row with `is_deleted = 1`. Never update or delete rows: the old rows are the history.

Every row ends with the same four columns:

| Column | Value |
|---|---|
| `changed_at` | `now64(3)` |
| `changed_by` | your name |
| `change_note` | why, in a few words |
| `is_deleted` | `0`, or `1` to remove the key |

**The settings page.** `scripts/bsc_settings/` has a local page that does these inserts for you, with checks and history: see its [README](../scripts/bsc_settings/README.md).

**When it shows in the report.** The next morning, after the nightly build and SSAS refresh. To see it sooner, run `dbt build --select stg_ref__bsc_*+` in the receiving project and then `ssas\scripts\process.ps1 -Mode Daily -Force`. The `-Force` run changes the production SSAS database.

**Check an edit straight away.** Run `dbt test --select stg_ref__bsc_*`. A row that breaks a rule shows as a warning. The nightly build still runs: the scorecard ignores that row (an unknown KPI code, category or list), or shows its value as entered, until you insert a corrected row. No other report is held up by a scorecard edit.

**See the history of a key:**

```sql
SELECT * FROM default.map_bsc_target WHERE kpi_code = 'FIN_DAYS_IN_AR' ORDER BY changed_at;
```

**Undo a change.** Insert the previous values again.

## Tables

### `map_bsc_kpi`: the KPI list

Key: `kpi_code`.

| Column | Allowed values |
|---|---|
| `kpi_num`, `display_order` | numbers |
| `kpi_name`, `short_label`, `definition` | text (the definition shows on the KPI detail page) |
| `objective_code` | a code in `map_bsc_objective` (F1–F5, C1–C3, P1–P6, L1–L3) |
| `kpi_type` | `Primary`, `Supporting` |
| `direction` | `higher`, `lower`, `ceiling` (at or under target scores full), `on_target` (closer is better) |
| `value_format` | `sar`, `pct`, `days`, `mins`, `num` |
| `chart_hint` | `line`, `bullet`, `bulletN`, `gauge`, `hbar`, `stat`, `signed` |
| `status` | `active`, `parked` (shown as Parked, not scored) |
| `target_source` | `fixed` (from `map_bsc_target`), `budget`, `prior_year`, `none` |
| `value_source` | `measure`, `manual` (read from `map_bsc_manual_value`) |
| `detail_page` | `revenue`, `finance`, `volume`, `beds`, `revenue_cycle`, `workforce`, `experience` |

**Park a KPI.** Copy its current row with the latest values, set `status = 'parked'`, and insert it:

```sql
INSERT INTO default.map_bsc_kpi
SELECT kpi_code, kpi_num, kpi_name, short_label, objective_code, kpi_type, direction, value_format, chart_hint,
       display_order, definition, 'parked', target_source, value_source, detail_page,
       now64(3), 'bi_manager', 'waiting for finance mapping', 0
FROM default.map_bsc_kpi WHERE kpi_code = 'FIN_CONSUMABLES_RATIO' ORDER BY changed_at DESC LIMIT 1;
```

A new KPI also needs its measure in the SSAS model. Add the row with `status = 'parked'` until the measure is deployed.

### `map_bsc_target`: fixed targets

Key: `kpi_code`, `branch_id`, `year`, `month`.
- `branch_id`: 0 = every hospital, 1–8 = one hospital (wins over 0).
- `month`: 0 = the whole year, 1–12 = one month (wins over 0).
- `scale_with_months`: 1 when an annual target is pro-rated by the months selected (turnover).

```sql
INSERT INTO default.map_bsc_target
  (kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted)
VALUES ('FIN_DAYS_IN_AR', 0, 2027, 0, 170, 0, 'Board 2027', now64(3), 'bi_manager', 'FY2027 target approved', 0);
```

Rates are fractions: 0.70 for 70%.

An annual target stays in force in the following years until you enter a newer one. For a new year, insert a row for that year only where the target changes.

### `map_bsc_weight`: KPI weights

Key: `profile`, `kpi_code`.
- `profile` is `corporate` or `branch:<id>`.
- A hospital with any `branch:<id>` rows uses only them; a KPI missing from its profile weighs 0 there.
- The weights of a profile should add up to 1.

### `map_bsc_objective`: objectives and pillars

Key: `objective_code`.
- `pillar` is `Financial`, `Customer`, `Internal Process` or `Learning & Growth`.
- `pillar_weight` is the pillar's share of the overall score (0.30, 0.20, 0.35, 0.15).
- `pillar_question` and `objective_question` are the questions shown on the cards.

### `map_bsc_threshold`: score thresholds

Key: `kpi_code`, where `*` is the default for every KPI.
- A KPI scores `score_base` at target and moves `score_slope` points per 1% above or below it.
- It is on track from `good_from` and on watch from `watch_from`.

### `map_bsc_owner`: owners

Key: `kpi_code`, `branch_id` (0 = Corporate).
- `co_owners` are separated by `|` (`COO|CMO`).
- Owners are information only: access to the report is managed on the report server.

### `map_bsc_hospital_category`: hospital category

Key: `branch_id` (1–8). `category` is `Scale & Optimize`, `Anchor & Protect` or `Ramp-Up & Prove`.

### `map_bsc_manual_value`: monthly values with no source system

Key: `kpi_code`, `branch_id` (1–8), `year`, `month` (1–12).
- Enter `numerator` and `denominator`. For a rate already worked out, put the rate in `numerator` and 1 in `denominator`.
- For complaints, enter the count in `numerator` and 0 in `denominator`: the measure divides by OP and ER visits.

```sql
INSERT INTO default.map_bsc_manual_value
  (kpi_code, branch_id, year, month, numerator, denominator, note, changed_at, changed_by, change_note, is_deleted)
VALUES ('INT_HAI_RATE', 6, 2026, 9, 4, 1250, 'Infection control report Sep', now64(3), 'bi_manager', 'monthly entry', 0);
```

Manual KPIs:

| Code | KPI |
|---|---|
| `CUS_PREMS` | PREMs |
| `CUS_PROMS` | PROMs |
| `CUS_COMPLAINT_RATE` | Patient complaint rate |
| `INT_HAI_RATE` | HAI rate |
| `INT_FALL_RATE` | Fall rate with harm |
| `LRN_STAFF_SATISFACTION` | Staff satisfaction |
| `LRN_DIGITAL_ON_TIME` | Timely completion of digital initiatives |
| `LRN_TRAINING_COVERAGE` | Training coverage |
| `LRN_MANDATORY_TRAINING` | Mandatory training completion |
| `LRN_COST_PER_LEARNER` | Cost per learner |
| `LRN_DOA_COMPLIANCE` | DOA compliance |
| `LRN_AUDIT_CLOSURE` | Audit finding closure |

### `map_bsc_code_list`: codes the measures filter on

Key: `list_name`, `code`.

| `list_name` | Codes | Used by |
|---|---|---|
| `ancillary_category` | product category codes | KPI 28, ancillary service utilisation |
| `satisfaction_nps_role` | survey question roles (Hospital NPS, Physician NPS) | KPI 13, patient satisfaction |

### `map_bsc_budgeted_fte`: budgeted FTE

Key: `branch_id` (1–8), `year`. It is the job vacancy rate denominator (KPI 47); the KPI shows "No data yet" for a hospital without a row.

```sql
INSERT INTO default.map_bsc_budgeted_fte (branch_id, year, budgeted_fte, changed_at, changed_by, change_note, is_deleted)
VALUES (6, 2026, 820, now64(3), 'bi_manager', 'HR establishment 2026', 0);
```

### `map_bsc_parameter`: scorecard parameters

Key: `name`. Values used by the measures:
- `clinic_hours_per_day` (8) and `clinic_patients_per_hour` (4): the clinic capacity behind KPI 22, Clinic Utilization;
- `ancillary_target_share` (0.6): the ancillary target as a share of the OP revenue target, KPI 28.

```sql
INSERT INTO default.map_bsc_parameter (name, value, changed_at, changed_by, change_note, is_deleted)
VALUES ('clinic_hours_per_day', 9, now64(3), 'bi_manager', 'clinics open 9 hours from 2027', 0);
```

### `map_bsc_licensed_beds`: licensed beds

Key: `branch_id` (1–8), `year`. It is the Activated Bed Rate denominator (KPI 60). A year without a row keeps the latest earlier figure.

## Who can write

Inserting needs a ClickHouse login with `INSERT` on these tables. Reading them needs `SELECT`. The report and SSAS read them only through the gold models.
