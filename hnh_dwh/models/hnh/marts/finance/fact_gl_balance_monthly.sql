{{ config(order_by='(branch_key, gl_account_key, period_key, balance_view)') }}

with lines as (
    select branch_key, gl_account_key, period_key, is_posted, is_opening_balance_journal, debit, credit
    from {{ ref('hnh_fact_gl_journal_line') }}
),

viewed as (
    select 'posted' as balance_view, branch_key, gl_account_key, period_key, is_opening_balance_journal, debit, credit
    from lines where is_posted = 1
    union all
    select 'including_unposted' as balance_view, branch_key, gl_account_key, period_key, is_opening_balance_journal, debit, credit
    from lines
),

movement as (
    select balance_view, branch_key, gl_account_key, period_key,
           sum(debit)                                           as m_debit,
           sum(credit)                                          as m_credit,
           sum(debit - credit)                                  as m_movement,
           sumIf(debit - credit, is_opening_balance_journal = 0) as m_movement_excl_opening
    from viewed
    group by balance_view, branch_key, gl_account_key, period_key
),

periods as (
    -- up to the latest period that has a posting or has already started
    select period_key, fiscal_year
    from {{ ref('hnh_dim_gl_period') }}
    where period_key <= greatest(
        (select max(period_key) from movement),
        (select max(period_key) from {{ ref('hnh_dim_gl_period') }} where start_date <= today()))
),

first_seen as (
    select balance_view, branch_key, gl_account_key, min(period_key) as first_period_key
    from movement
    group by balance_view, branch_key, gl_account_key
),

grid as (
    select f.balance_view as balance_view, f.branch_key as branch_key, f.gl_account_key as gl_account_key,
           p.period_key as period_key, p.fiscal_year as fiscal_year
    from first_seen as f
    cross join periods as p
    where p.period_key >= f.first_period_key
),

filled as (
    select g.balance_view as balance_view, g.branch_key as branch_key, g.gl_account_key as gl_account_key,
           g.period_key as period_key, g.fiscal_year as fiscal_year, ifNull(a.balance_side, 'IS') as balance_side,
           ifNull(m.m_debit, 0) as period_debit, ifNull(m.m_credit, 0) as period_credit,
           ifNull(m.m_movement, 0) as period_movement, ifNull(m.m_movement_excl_opening, 0) as period_movement_excl_opening
    from grid as g
    left join movement as m
        on m.balance_view = g.balance_view and m.branch_key = g.branch_key and m.gl_account_key = g.gl_account_key and m.period_key = g.period_key
    left join (select gl_account_key, balance_side from {{ ref('hnh_dim_gl_account') }}) as a on a.gl_account_key = g.gl_account_key
    -- a SETTINGS clause binds to its own select only, so the left joins above carry it here, not at the end of the union
    {{ hnh_settings() }}
),

balances as (
    select *,
           sum(period_movement) over (
               partition by balance_view, branch_key, gl_account_key, if(balance_side = 'IS', fiscal_year, 0)
               order by period_key rows between unbounded preceding and current row) as closing_balance
    from filled
),

branch_years as (
    select balance_view, branch_key, fiscal_year,
           sumIf(period_movement, balance_side = 'IS') as year_result
    from filled
    group by balance_view, branch_key, fiscal_year
),

prior_results as (
    select balance_view, branch_key, fiscal_year,
           sum(year_result) over (partition by balance_view, branch_key order by fiscal_year
                                  rows between unbounded preceding and 1 preceding) as prior_result
    from branch_years
),

roll as (
    -- the income-statement result of earlier years, carried on the branch's prior-year roll account
    select bp.balance_view as balance_view, bp.branch_key as branch_key, bp.period_key as period_key,
           bp.fiscal_year as fiscal_year, r.prior_result as prior_result
    from (select distinct balance_view, branch_key, period_key, fiscal_year from grid) as bp
    inner join prior_results as r
        on r.balance_view = bp.balance_view and r.branch_key = bp.branch_key and r.fiscal_year = bp.fiscal_year
    where abs(r.prior_result) > 0.000001
)

select balance_view, branch_key, gl_account_key, period_key, fiscal_year, toUInt8(0) as is_prior_year_roll,
       closing_balance - period_movement as opening_balance, period_debit, period_credit, period_movement,
       period_movement_excl_opening, closing_balance, now() as _loaded_at
from balances

union all

select balance_view, branch_key, {{ hnh_prior_year_results_key('branch_key') }} as gl_account_key, period_key, fiscal_year,
       toUInt8(1), prior_result, toFloat64(0), toFloat64(0), toFloat64(0), toFloat64(0), prior_result, now()
from roll
{{ hnh_settings() }}
