{{ config(order_by='(branch_key, month_start, source_system, account_code)') }}

-- Monthly GL balances per branch and account for the bsc finance views (bsc spec section 5). Each branch-month takes
-- one source: the Oasis GL before the branch's first Fusion GL month (default.map_gl_cutover; no row = Oasis), the
-- Fusion GL from it, because after go-live the Oasis feed keeps posting revenue that Fusion also has. Branches 1-8.
-- Amounts are debit positive. Oasis: posted lines; opening = this fiscal year's brought-forward rows + earlier months
-- of the year, so income-statement accounts restart each year. Fusion: including unposted (Oasis-feed batches stay
-- unposted), go-live opening-balance journals kept apart in opening_journal_amount.
with cutover as (
    select branch_id, first_fusion_gl_month_start
    from {{ ref('stg_ref__gl_cutover') }}
),

oasis_month as (
    select
        l.branch_key                               as branch_key,
        l.oasis_gl_account_key                     as oasis_gl_account_key,
        assumeNotNull(l.month_start)               as month_start,
        sumIf(l.amount, l.is_brought_forward = 1)  as bf_amount,
        sumIf(l.amount, l.is_brought_forward = 0)  as mv_amount
    from {{ ref('stg_bsc__oasis_gl_line') }} as l
    where l.is_posted = 1
      and l.branch_key between 1 and 8
      and l.month_start >= toDate('{{ var('hnh_history_start_date') }}')
    group by branch_key, oasis_gl_account_key, month_start
),

oasis_last as (
    select branch_key, max(month_start) as last_month
    from oasis_month
    group by branch_key
),

-- every month from an account's first row in a year to December (or the branch's last month), so a balance carries
-- through months without postings
oasis_account_year as (
    select
        m.branch_key              as branch_key,
        m.oasis_gl_account_key    as oasis_gl_account_key,
        toYear(m.month_start)     as fiscal_year,
        min(m.month_start)        as first_month,
        any(t.last_month)         as last_month
    from oasis_month as m
    inner join oasis_last as t on t.branch_key = m.branch_key
    group by branch_key, oasis_gl_account_key, fiscal_year
),

oasis_grid as (
    select branch_key, oasis_gl_account_key, addMonths(first_month, toInt32(n)) as month_start
    from oasis_account_year
    array join range(toUInt32(dateDiff('month', first_month, least(makeDate(fiscal_year, 12, 1), last_month)) + 1)) as n
),

oasis_rolled as (
    select
        g.branch_key                      as branch_key,
        g.oasis_gl_account_key            as oasis_gl_account_key,
        g.month_start                     as month_start,
        ifNull(m.bf_amount, 0)            as oj_amount,
        ifNull(m.mv_amount, 0)            as mv,
        sum(ifNull(m.bf_amount, 0) + ifNull(m.mv_amount, 0)) over (
            partition by g.branch_key, g.oasis_gl_account_key, toYear(g.month_start)
            order by g.month_start rows between unbounded preceding and 1 preceding) as open_amount
    from oasis_grid as g
    left join oasis_month as m
      on m.branch_key = g.branch_key and m.oasis_gl_account_key = g.oasis_gl_account_key and m.month_start = g.month_start
),

oasis as (
    select
        r.branch_key                                               as branch_key,
        r.month_start                                              as month_start,
        'oasis'                                                    as source_system,
        -- a GL code without main/sub account (some unmapped Jazan codes) keeps its own key
        if(ifNull(a.account_code, '') = '', toString(r.oasis_gl_account_key), a.account_code) as account_code,
        ifNull(a.fs_type, '')                                      as fs_type,
        ifNull(a.fs_element, '')                                   as fs_element,
        ifNull(a.fs_category, '')                                  as fs_category,
        ifNull(a.fs_caption, '')                                   as fs_caption,
        ifNull(a.fs_line, '')                                      as fs_line,
        sum(r.open_amount)                                         as opening_amount,
        sum(r.oj_amount)                                           as opening_journal,
        sum(r.mv)                                                  as movement_amount
    from oasis_rolled as r
    left join {{ ref('stg_bsc__oasis_gl_account') }} as a on a.oasis_gl_account_key = r.oasis_gl_account_key
    group by branch_key, month_start, account_code, fs_type, fs_element, fs_category, fs_caption, fs_line
),

fusion as (
    select
        f.branch_key                                                as branch_key,
        p.month_start                                               as month_start,
        'fusion'                                                    as source_system,
        -- the natural account (segment 2), so combinations of one account in a branch add up; a combination
        -- without one (the unknown account) keeps its own key
        ifNull(toString(a.natural_account), toString(f.gl_account_key)) as account_code,
        lower(d.fs_type)                                            as fs_type,
        lower(d.fs_element)                                         as fs_element,
        lower(d.fs_category)                                        as fs_category,
        lower(d.fs_caption)                                         as fs_caption,
        lower(d.fs_line)                                            as fs_line,
        -- an adjustment period folds into its quarter's last month: its movement counts, its opening does not
        sumIf(f.opening_balance, p.is_adjustment = 0)               as opening_amount,
        sum(f.period_movement - f.period_movement_excl_opening)     as opening_journal,
        sum(f.period_movement_excl_opening)                         as movement_amount
    from {{ ref('fact_gl_balance_monthly') }} as f
    inner join {{ ref('hnh_dim_gl_period') }} as p on p.period_key = f.period_key
    inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = f.gl_account_key
    inner join {{ ref('dim_fs_line') }} as d on d.fs_line_key = a.fs_line_key
    where f.balance_view = 'including_unposted'
      and f.branch_key between 1 and 8
    group by branch_key, month_start, account_code, fs_type, fs_element, fs_category, fs_caption, fs_line
),

selected as (
    select o.branch_key as branch_key, o.month_start as month_start, o.source_system as source_system,
           o.account_code as account_code, o.fs_type as fs_type, o.fs_element as fs_element,
           o.fs_category as fs_category, o.fs_caption as fs_caption, o.fs_line as fs_line,
           o.opening_amount as opening_amount, o.opening_journal as opening_journal, o.movement_amount as movement_amount
    from oasis as o
    left join cutover as c on c.branch_id = o.branch_key
    where c.first_fusion_gl_month_start is null or o.month_start < c.first_fusion_gl_month_start
    union all
    select fu.branch_key, fu.month_start, fu.source_system, fu.account_code, fu.fs_type, fu.fs_element,
           fu.fs_category, fu.fs_caption, fu.fs_line, fu.opening_amount, fu.opening_journal, fu.movement_amount
    from fusion as fu
    inner join cutover as c on c.branch_id = fu.branch_key
    where fu.month_start >= c.first_fusion_gl_month_start
)

select
    toUInt8(branch_key)                                    as branch_key,
    month_start,
    toLowCardinality(source_system)                        as source_system,
    account_code,
    toLowCardinality(fs_type)                              as fs_type,
    toLowCardinality(fs_element)                           as fs_element,
    toLowCardinality(fs_category)                          as fs_category,
    toLowCardinality(fs_caption)                           as fs_caption,
    toLowCardinality(fs_line)                              as fs_line,
    opening_amount                                         as opening_balance,
    opening_journal                                        as opening_journal_amount,
    movement_amount                                        as movement,
    opening_amount + opening_journal + movement_amount     as closing_balance,
    now()                                                  as _loaded_at
from selected
where abs(opening_amount) >= 0.005 or abs(opening_journal) >= 0.005 or abs(movement_amount) >= 0.005
{{ hnh_settings() }}
