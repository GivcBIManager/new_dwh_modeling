{{ config(order_by='(branch_key, month_start, statement, pl_line_key, bs_caption)') }}

-- Finance budget by hospital, month and report line, in the P&L sign (revenue and profit positive, costs negative);
-- balance sheet rows as entered (display sign). Every month is kept: the "today" cutoff is applied in the SSAS measures.
--   linked line  = budget_most_likely of its budget line x budget_sign (GA_TOTAL = TOTAL_GA - GA_MARKETING - GA_HO_CHARGES);
--   override     = a stg_ref__finance_budget IS row on a detail line replaces the amount; entered positive, signed by the
--                  line's budget_sign, or by its section for an unlinked line (Revenue, Other Income, OCI +1, the rest -1);
--   subtotal     = linked amount + the override differences of its sections, or the sum of its sections' lines when it has
--                  no linked amount (a hospital without a budget). Subtotal and not_mapped overrides are ignored.
with fim as (
    select branch_key, month_start, budget_line_code, sum(budget_most_likely) as amount
    from {{ ref('fact_income_statement_monthly') }}
    group by branch_key, month_start, budget_line_code
),

-- a branch-month whose budget lines net to nothing has no budget
budgeted as (
    select branch_key, month_start
    from fim
    group by branch_key, month_start
    having sum(abs(amount)) != 0
),

budget_codes as (
    select f.branch_key as branch_key, f.month_start as month_start, f.budget_line_code as code, f.amount as amount
    from fim as f
    inner join budgeted as b on b.branch_key = f.branch_key and b.month_start = f.month_start
    where f.amount != 0
    union all
    select f.branch_key, f.month_start, 'GA_TOTAL_NET',
           sumIf(f.amount, f.budget_line_code = 'TOTAL_GA') - sumIf(f.amount, f.budget_line_code = 'GA_MARKETING')
           - sumIf(f.amount, f.budget_line_code = 'GA_HO_CHARGES')
    from fim as f
    inner join budgeted as b on b.branch_key = f.branch_key and b.month_start = f.month_start
    group by f.branch_key, f.month_start
    having sumIf(f.amount, f.budget_line_code = 'TOTAL_GA') - sumIf(f.amount, f.budget_line_code = 'GA_MARKETING')
           - sumIf(f.amount, f.budget_line_code = 'GA_HO_CHARGES') != 0
),

lines as (
    select pl_line_key, pl_line_code, section_name, line_kind, subtotal_sections, budget_line_code, budget_sign,
           -- natural sign of an entered amount: the line's budget_sign, else its section's
           if(budget_sign != 0, toInt8(budget_sign), if(section_name in ('Revenue', 'Other Income', 'OCI'), toInt8(1), toInt8(-1))) as natural_sign
    from {{ ref('dim_pl_report_line') }}
),

overrides as (
    select toUInt8(o.branch_id) as branch_key, makeDate(o.year, o.month, 1) as month_start, l.pl_line_key as pl_line_key,
           l.pl_line_code as pl_line_code, l.section_name as section_name, toFloat64(o.amount) * l.natural_sign as amount
    from {{ ref('stg_ref__finance_budget') }} as o
    inner join lines as l on l.pl_line_code = o.line_code
    where o.statement = 'IS' and l.line_kind = 'detail'
),

detail_parts as (
    select c.branch_key as branch_key, c.month_start as month_start, l.pl_line_key as pl_line_key, l.pl_line_code as pl_line_code,
           l.section_name as section_name, c.amount * l.budget_sign as budget_amount, toFloat64(0) as override_amount, toUInt8(0) as has_override
    from budget_codes as c
    inner join lines as l on l.budget_line_code = c.code
    where l.line_kind = 'detail' and l.budget_sign != 0
    union all
    select branch_key, month_start, pl_line_key, pl_line_code, section_name, toFloat64(0), amount, toUInt8(1)
    from overrides
),

details as (
    select branch_key, month_start, pl_line_key, pl_line_code, section_name,
           sum(budget_amount) as budget_total, max(has_override) as any_override,
           if(max(has_override) = 1, sum(override_amount), sum(budget_amount)) as amount
    from detail_parts
    group by branch_key, month_start, pl_line_key, pl_line_code, section_name
),

subtotal_lines as (
    select pl_line_key, pl_line_code, budget_line_code, budget_sign, section as section_name
    from {{ ref('dim_pl_report_line') }}
    array join subtotal_sections as section
    where line_kind = 'subtotal'
),

-- per branch-month and subtotal: sum of the sections' lines, override differences, and any override
subtotal_sums as (
    select d.branch_key as branch_key, d.month_start as month_start, s.pl_line_key as pl_line_key, s.pl_line_code as pl_line_code,
           s.budget_line_code as budget_line_code, s.budget_sign as budget_sign,
           sum(d.amount) as section_sum, sum(d.amount - d.budget_total) as delta, max(d.any_override) as any_override
    from details as d
    inner join subtotal_lines as s on s.section_name = d.section_name
    group by d.branch_key, d.month_start, s.pl_line_key, s.pl_line_code, s.budget_line_code, s.budget_sign
),

-- a subtotal with a linked amount but no detail line in the month keeps its linked amount
subtotal_keys as (
    select branch_key, month_start, pl_line_key, pl_line_code, budget_line_code, budget_sign from subtotal_sums
    union distinct
    select c.branch_key, c.month_start, l.pl_line_key, l.pl_line_code, l.budget_line_code, l.budget_sign
    from budget_codes as c
    inner join lines as l on if(l.pl_line_code = 'GA_TOTAL', 'GA_TOTAL_NET', l.budget_line_code) = c.code
    where l.line_kind = 'subtotal' and l.budget_sign != 0
),

subtotals as (
    select k.branch_key as branch_key, k.month_start as month_start, k.pl_line_key as pl_line_key, k.pl_line_code as pl_line_code,
           c.amount * k.budget_sign as linked_amount, isNotNull(c.code) as has_linked,
           ifNull(s.section_sum, 0) as section_sum, ifNull(s.delta, 0) as delta, ifNull(s.any_override, 0) as any_override
    from subtotal_keys as k
    left join budget_codes as c on c.branch_key = k.branch_key and c.month_start = k.month_start
         and c.code = if(k.pl_line_code = 'GA_TOTAL', 'GA_TOTAL_NET', k.budget_line_code)
    left join subtotal_sums as s on s.branch_key = k.branch_key and s.month_start = k.month_start and s.pl_line_key = k.pl_line_key
),

is_rows as (
    select branch_key, month_start, pl_line_key, pl_line_code, amount, if(any_override = 1, 'override', 'budget') as source
    from details
    union all
    select branch_key, month_start, pl_line_key, pl_line_code,
           if(has_linked, ifNull(linked_amount, 0) + delta, section_sum),
           if(not has_linked, 'rollup', if(any_override = 1, 'override', 'budget'))
    from subtotals
),

bs_rows as (
    select toUInt8(branch_id) as branch_key, makeDate(year, month, 1) as month_start, line_code as bs_caption, toFloat64(amount) as amount
    from {{ ref('stg_ref__finance_budget') }}
    where statement = 'BS'
),

all_rows as (
    select branch_key, month_start, 'IS' as statement, pl_line_key, pl_line_code, '' as bs_caption, amount, source
    from is_rows
    union all
    select branch_key, month_start, 'BS', toUInt16(0), '', bs_caption, amount, 'override'
    from bs_rows
)

select
    toUInt8(branch_key)                         as branch_key,
    month_start,
    toInt64({{ hnh_date_key('month_start') }})  as month_date_key,
    statement,
    toUInt16(pl_line_key)                       as pl_line_key,
    pl_line_code,
    bs_caption,
    toFloat64(amount)                           as amount,
    source,
    now()                                       as _loaded_at
from all_rows
{{ hnh_settings() }}
