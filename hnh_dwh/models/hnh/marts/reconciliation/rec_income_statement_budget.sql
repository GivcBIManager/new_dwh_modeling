{{ config(order_by='(branch_key, fiscal_year, scenario, budget_line_code)') }}

-- Budget subtotals computed by the model against the subtotal rows of the budget file, per branch, year and scenario.
with computed as (
    select branch_key, toUInt16(toYear(month_start)) as fiscal_year, 'most_likely' as scenario, budget_line_code,
           sum(budget_most_likely) as computed_amount
    from {{ ref('fact_income_statement_monthly') }}
    group by branch_key, fiscal_year, budget_line_code
    union all
    select branch_key, toUInt16(toYear(month_start)), 'worst_case', budget_line_code, sum(budget_worst_case)
    from {{ ref('fact_income_statement_monthly') }}
    group by branch_key, toUInt16(toYear(month_start)), budget_line_code
),

delivered as (
    select branch_key, toUInt16(toYear(month_start)) as fiscal_year, scenario, budget_line_code, sum(budget_amount) as file_amount
    from {{ ref('fact_budget_monthly') }}
    where is_subtotal = 1
    group by branch_key, fiscal_year, scenario, budget_line_code
)

select
    d.branch_key                                    as branch_key,
    d.fiscal_year                                   as fiscal_year,
    d.scenario                                      as scenario,
    d.budget_line_code                              as budget_line_code,
    ifNull(c.computed_amount, 0)                    as computed_amount,
    d.file_amount                                   as file_amount,
    ifNull(c.computed_amount, 0) - d.file_amount    as difference
from delivered as d
left join computed as c
    on c.branch_key = d.branch_key and c.fiscal_year = d.fiscal_year and c.scenario = d.scenario and c.budget_line_code = d.budget_line_code
{{ hnh_settings() }}
