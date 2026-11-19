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
SELECT * FROM default.map_finance_target WHERE kpi_code = 'FR_AR_DAYS' ORDER BY changed_at;
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
| `line_code` | `IS`: a `pl_line_code` of a detail line of `dim_pl_report_line` (full list below); subtotals and `Not mapped` lines take no amount. `BS`: the lower-case FS caption as shown in `GL FS Monthly` |
| `amount` | SAR, **entered as a positive number** for revenue and costs alike. The model applies the line's sign (revenue positive, discounts and costs negative in the P&L Report) |

**Detail lines (every `pl_line_code` that takes an amount), by section.** Subtotal lines (for example `NET_REVENUE`, `GROSS_PROFIT`, `EBITDA`, `NET_PROFIT`) and `Not mapped` lines are never entered: subtotals roll up from the detail lines.

- Revenue: `REV_CASH` (Revenue Cash), `REV_CREDIT` (Revenue Credit)
- Revenue - Contractual Discounts: `DIS_CASH` (Cash Discount), `DIS_CREDIT` (Credit Discount), `DIS_PACKAGE` (Package Discount)
- Revenue - Settlement Discount: `DIS_REJECTION` (Rejection), `DIS_VOLUME` (Volume Discount), `DIS_EARLY_PAYMENT` (Early Payment Discount), `DIS_UNCLAIMED` (Unclaimed Discount), `DIS_PATIENT_REFERRAL` (Patient Referral Discount)
- Direct Cost: `DC_CONSUMABLES` (Consumables), `DC_MEDICINES` (Cost of Medicines), `DC_DOCTORS_FEE` (Doctors Fee and Commission), `DC_EMPLOYEE` (Employee Costs), `DC_GOVT_FEES` (Employee Govt Fees), `DC_INSURANCE` (Insurance Expenses), `DC_KITCHEN` (Kitchen Expenses), `DC_MAINTENANCE` (Maintenance Expense), `DC_OTHER` (Other Direct expenses), `DC_REFERRAL` (Referral Cost), `DC_RENTAL` (Rental Cost), `DC_TRAINING` (Staff training and recruitments), `DC_TRAVEL` (Travelling Expenses), `DC_UTILITIES` (Utilities)
- General and administrative expenses: `GA_GOVT_FEE` (Government Fee), `GA_AUDIT` (Audit Fees), `GA_BOARD` (Board Of Directors Expenses), `GA_COMMUNICATION` (Communication Expense), `GA_MGMT_REWARD` (Corporate Management Reward), `GA_ECL` (Expected credit loss), `GA_OTHER` (Other indirect Expenses), `GA_POSTAGE` (Postage printing and stationary), `GA_PROFESSIONAL` (Professional Fee and subscription), `GA_SECURITY` (Security and cleaning Expenses), `GA_TRAINING` (Staff training and recruitment), `GA_EMPLOYEE` (Employee Cost), `GA_MAINTENANCE` (Maintenance Expense), `GA_UTILITIES` (Utilities Expenses), `GA_TRAVEL` (Travelling Expenses), `GA_INSURANCE` (Insurance Expenses), `GA_KITCHEN` (Kitchen Expenses)
- Selling and Marketing expenses: `SM` (Selling and Marketing expenses)
- Charges from head office: `HO_CHARGES` (Charges from head office)
- Other Income: `OTHER_INCOME` (Other Income)
- Finance Cost: `FINANCE_COST` (Finance Cost)
- Depreciation and Amortization: `DEPRECIATION` (Depreciation and Amortization)
- Zakat: `ZAKAT` (Zakat)
- OCI: `OCI` (OCI)

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
| `target_value` | the target, in the KPI's own unit: days for a `d` KPI, times for an `x` KPI, and a **fraction** for a `%` KPI (`0.21` = 21%, never `21`) |
| `watch_pct` | how far below the target still counts as Watch, as a fraction (`0.05` = 5%). `0` means the default `0.05` |

```sql
INSERT INTO default.map_finance_target (kpi_code, branch_id, year, target_value, watch_pct, changed_at, changed_by, change_note, is_deleted) VALUES
    ('FR_AR_DAYS', 0, 2026, 60, 0, now64(3), 'Your Name', 'target 2026', 0),
    ('FR_EBITDA_MARGIN', 0, 2026, 0.21, 0, now64(3), 'Your Name', 'target 2026: 21%', 0);
```

## Placeholders and the budget app (2026-11-19)

- **Placeholder rows.** `scripts/finance_config/finance_targets_2026_placeholder.sql` (167 KPI targets: 2025 actual, vs-budget KPIs 100%) and `finance_bs_budget_2026_placeholder.sql` (1,728 balance-sheet budget rows: the best hospital in Q1 and Q2 2026 by EBITDA margin, Jazan, its captions as a share of net revenue, applied to each hospital's 2026 net revenue budget) were loaded with `changed_by = 'BI placeholder'`. Replace a placeholder by inserting a new row with the same key; list them with `WHERE changed_by = 'BI placeholder'`.
- **Income statement budget from the budget app.** `scripts/finance_config/create_budget_app_table.py` creates `default.income_statement_budget_app`, a PostgreSQL-engine table on the budget app (`172.22.24.7`, schema `budget`) through the ClickHouse named collection `budget_app`; the password is read from `C:\HNH\secrets\budget_pg.env` (`PG_PASSWORD=...`) and never written anywhere else. Once it exists and reads, the dbt source `reference.income_statement_budget` takes `identifier: income_statement_budget_app`, so the nightly build reads the latest published budget instead of the 1 October copy in `default.income_statement_budget`.
