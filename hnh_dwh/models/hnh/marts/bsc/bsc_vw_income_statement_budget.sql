{{ config(alias='vw_income_statement_budget') }}

-- Old bsc.vw_income_statement_budget (bsc spec 6.4): the latest most-likely budget file (the same table the old view
-- read; 576 rows, identical on both servers) as one row per branch, line and month, with the old line names and
-- categories (default.map_budget_line_item).
with budget as (
    select branch_id, fiscal_year, line_item_code, assumption_percentage, month_number, month_value
    from {{ source('reference', 'income_statement_budget') }}
    array join [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as month_number,
               [month_1, month_2, month_3, month_4, month_5, month_6, month_7, month_8, month_9, month_10, month_11, month_12] as month_value
    where is_latest = 1 and scenario = 'most_likely'
)
select
    toUInt32(b.branch_id)                                                   as branch_id,
    toInt32(b.fiscal_year)                                                  as fiscal_year,
    toLowCardinality(toString(b.line_item_code))                            as line_item_code,
    toLowCardinality(li.name)                                               as line_name,
    toLowCardinality(li.category)                                           as category,
    CAST(round(b.assumption_percentage, 4) AS Nullable(Decimal(10, 4)))     as assumption_percentage,
    makeDate(b.fiscal_year, b.month_number, 1)                              as month_date,
    CAST(round(b.month_value, 2) AS Nullable(Decimal(18, 2)))               as month_value
from budget as b
inner join {{ ref('stg_ref__budget_line_item') }} as li on li.code = b.line_item_code
