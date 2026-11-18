{{ config(severity='warn') }}

-- Finance budget config rows (default.map_finance_budget) that fact_finance_budget_monthly ignores: a month outside 1..12,
-- a hospital that is not 1..8 or 100 (Head Office), or a statement that is not IS or BS. One row per such key.
select
    branch_id,
    year,
    month,
    statement,
    line_code,
    amount
from {{ ref('stg_ref__finance_budget') }}
where month not between 1 and 12
   or not (branch_id between 1 and 8 or branch_id = 100)
   or statement not in ('IS', 'BS')
