{{ config(order_by='(branch_key, month_start, budget_line_code, revenue_care_type, statement_group)') }}

with actual_lines as (
    select
        j.branch_key                                                        as branch_key,
        toStartOfMonth(p.end_date)                                          as month_start,
        ifNull(a.budget_line_code, 'UNBUDGETED')                            as budget_line_code,
        if(ifNull(a.budget_line_code, '') in ('REV_OP', 'REV_IP', 'REV_ER', 'REV_UNALLOCATED'), a.revenue_care_type, 'All') as revenue_care_type,
        if(ifNull(a.budget_line_code, 'UNBUDGETED') = 'UNBUDGETED', ifNull(f.statement_group, 'Not mapped expenses'), '') as statement_group,
        j.is_posted                                                         as is_posted,
        j.is_opening_balance_journal                                        as is_opening_balance_journal,
        j.amount                                                            as amount
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join (
        select gl_account_key, balance_side, budget_line_code, revenue_care_type, fs_line_key
        from {{ ref('hnh_dim_gl_account') }} where balance_side = 'IS'
    ) as a on a.gl_account_key = j.gl_account_key
    left join (select fs_line_key, statement_group from {{ ref('dim_fs_line') }}) as f on f.fs_line_key = a.fs_line_key
    inner join (select period_key, end_date from {{ ref('hnh_dim_gl_period') }}) as p on p.period_key = j.period_key
    -- own setting so unmatched dim_fs_line rows are NULL (not the default empty string) inside this CTE
    {{ hnh_settings() }}
),

actuals as (
    select branch_key, month_start, budget_line_code, revenue_care_type, statement_group,
           -- natural side: credit codes are credit - debit, debit codes debit - credit
           sumIf(if({{ hnh_budget_natural_side('budget_line_code', 'statement_group') }} = 'credit', -amount, amount), is_posted = 1) as actual_posted,
           sum(if({{ hnh_budget_natural_side('budget_line_code', 'statement_group') }} = 'credit', -amount, amount))                  as actual_including_unposted,
           sumIf(if({{ hnh_budget_natural_side('budget_line_code', 'statement_group') }} = 'credit', -amount, amount), is_opening_balance_journal = 0) as actual_excl_opening,
           toFloat64(0) as budget_most_likely, toFloat64(0) as budget_worst_case
    from actual_lines
    group by branch_key, month_start, budget_line_code, revenue_care_type, statement_group
),

budget_months as (
    select
        b.branch_id as branch_key, b.scenario as scenario, b.line_item_code as budget_line_code,
        makeDate(b.fiscal_year, toUInt8(tupleElement(m_t, 1)), 1) as month_start, tupleElement(m_t, 2) as amount
    from {{ ref('stg_ref__income_statement_budget') }} as b
    array join arrayMap(i -> tuple(i, [b.month_1, b.month_2, b.month_3, b.month_4, b.month_5, b.month_6, b.month_7, b.month_8,
                                       b.month_9, b.month_10, b.month_11, b.month_12][i]), range(1, 13)) as m_t
    where b.is_latest = 1
      and b.line_item_code in (select budget_line_code from {{ ref('dim_budget_line') }} where is_subtotal = 0)
),

budgets as (
    select branch_key, month_start, budget_line_code,
           if(budget_line_code in ('REV_OP', 'REV_IP', 'REV_ER'), replaceOne(budget_line_code, 'REV_', ''), 'All') as revenue_care_type,
           '' as statement_group,
           toFloat64(0) as actual_posted, toFloat64(0) as actual_including_unposted, toFloat64(0) as actual_excl_opening,
           sumIf(amount, scenario = 'most_likely') as budget_most_likely,
           sumIf(amount, scenario = 'worst_case')  as budget_worst_case
    from budget_months
    where amount != 0
    group by branch_key, month_start, budget_line_code
),

detail as (
    select branch_key, month_start, budget_line_code, revenue_care_type, statement_group,
           sum(actual_posted) as actual_posted, sum(actual_including_unposted) as actual_including_unposted,
           sum(actual_excl_opening) as actual_excl_opening, sum(budget_most_likely) as budget_most_likely,
           sum(budget_worst_case) as budget_worst_case
    from (select * from actuals union all select * from budgets)
    group by branch_key, month_start, budget_line_code, revenue_care_type, statement_group
),

weights as ({{ hnh_budget_subtotal_weights() }}),

subtotals as (
    select d.branch_key as branch_key, d.month_start as month_start, w.subtotal_code as budget_line_code,
           'All' as revenue_care_type, '' as statement_group,
           sum(d.actual_posted * w.weight)             as actual_posted,
           sum(d.actual_including_unposted * w.weight) as actual_including_unposted,
           sum(d.actual_excl_opening * w.weight)       as actual_excl_opening,
           sum(d.budget_most_likely * w.weight)        as budget_most_likely,
           sum(d.budget_worst_case * w.weight)         as budget_worst_case
    from detail as d
    inner join weights as w on w.component_code = d.budget_line_code
    where w.component_group = '' or w.component_group = d.statement_group
    group by d.branch_key, d.month_start, w.subtotal_code
),

all_rows as (
    select * from detail
    union all
    select * from subtotals
)

select
    {{ hnh_surrogate_key(['branch_key', 'month_start', 'budget_line_code', 'revenue_care_type', 'statement_group']) }} as income_statement_key,
    branch_key,
    month_start,
    {{ hnh_date_key('month_start') }}               as month_date_key,
    {{ hnh_surrogate_key(['budget_line_code']) }}   as budget_line_key,
    budget_line_code,
    revenue_care_type,
    statement_group,
    actual_posted,
    actual_including_unposted,
    actual_excl_opening,
    budget_most_likely,
    budget_worst_case,
    now()                                           as _loaded_at
from all_rows
{{ hnh_settings() }}
