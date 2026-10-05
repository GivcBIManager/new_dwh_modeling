{{ config(order_by='(branch_key, month_start, budget_line_code, scenario)') }}

with unpivoted as (
    select
        b.branch_id as branch_id, b.fiscal_year as fiscal_year, b.scenario as scenario, b.line_item_code as line_item_code,
        toUInt8(tupleElement(m_t, 1)) as month_no, tupleElement(m_t, 2) as amount
    from {{ ref('stg_ref__income_statement_budget') }} as b
    array join arrayMap(i -> tuple(i, [b.month_1, b.month_2, b.month_3, b.month_4, b.month_5, b.month_6, b.month_7, b.month_8,
                                       b.month_9, b.month_10, b.month_11, b.month_12][i]), range(1, 13)) as m_t
    where b.is_latest = 1
)

select
    {{ hnh_surrogate_key(['u.branch_id', 'u.line_item_code', 'u.scenario', 'u.fiscal_year', 'u.month_no']) }} as budget_month_key,
    u.branch_id                                         as branch_key,
    {{ hnh_surrogate_key(['u.line_item_code']) }}       as budget_line_key,
    u.line_item_code                                    as budget_line_code,
    ifNull(l.is_subtotal, toUInt8(0))                   as is_subtotal,
    u.scenario                                          as scenario,
    makeDate(u.fiscal_year, u.month_no, 1)              as month_start,
    {{ hnh_date_key('makeDate(u.fiscal_year, u.month_no, 1)') }} as month_date_key,
    u.amount                                            as budget_amount,
    now()                                               as _loaded_at
from unpivoted as u
left join (select budget_line_code, is_subtotal from {{ ref('dim_budget_line') }}) as l on l.budget_line_code = u.line_item_code
{{ hnh_settings() }}
