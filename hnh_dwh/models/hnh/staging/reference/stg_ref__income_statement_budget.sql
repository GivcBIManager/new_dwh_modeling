-- The budget app's income statement budget, read live from its Postgres through default.income_statement_budget_app
-- (PostgreSQL engine, named collection budget_app; scripts/finance_config/create_budget_app_table.py). Its month and
-- is_latest columns are Nullable: an empty month reads 0 and an empty is_latest 0, as in the copy it replaces.
select
    toUInt32(id)                    as id,
    toUInt8(branch_id)              as branch_id,
    toUInt16(fiscal_year)           as fiscal_year,
    toString(scenario)              as scenario,
    upper(toString(line_item_code)) as line_item_code,
    {% for m in range(1, 13) %}ifNull(toFloat64(month_{{ m }}), 0) as month_{{ m }},
    {% endfor %}ifNull(toUInt8(is_latest), 0) as is_latest
from {{ source('reference', 'income_statement_budget') }}
