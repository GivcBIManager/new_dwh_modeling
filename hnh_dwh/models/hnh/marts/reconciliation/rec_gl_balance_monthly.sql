{{ config(order_by='(branch_key, period_key)') }}

-- Posted journal activity and closing balances against Fusion's own balance table, per branch and period.
with gold_activity as (
    select branch_key, period_key, sum(debit) as gold_debit, sum(credit) as gold_credit
    from {{ ref('hnh_fact_gl_journal_line') }}
    where is_posted = 1
    group by branch_key, period_key
),

fusion_rows as (
    select b.branch_key as branch_key, p.period_key as period_key, a.gl_account_key as gl_account_key,
           f.period_debit as period_debit, f.period_credit as period_credit,
           f.begin_debit - f.begin_credit + f.period_debit - f.period_credit as fusion_closing
    from {{ ref('stg_fusion__gl_balances') }} as f
    inner join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
        on b.fusion_ledger_id = f.ledger_id
    inner join (select period_key, period_name from {{ ref('hnh_dim_gl_period') }}) as p on p.period_name = f.period_name
    left join (select gl_account_key, code_combination_id from {{ ref('hnh_dim_gl_account') }} where code_combination_id is not null) as a
        on a.code_combination_id = f.code_combination_id
    where f.actual_flag = 'A' and f.currency_balance_type = 'TOTAL'
    {{ hnh_settings() }} -- CTE-level setting: the account left join must yield NULLs, not defaults, for unmatched rows
),

fusion_activity as (
    select branch_key, period_key, sum(period_debit) as fusion_debit, sum(period_credit) as fusion_credit
    from fusion_rows
    group by branch_key, period_key
),

closings as (
    select f.branch_key as branch_key, f.period_key as period_key, count() as accounts_compared,
           countIf(abs(ifNull(g.closing_balance, 0) - f.fusion_closing) > 0.01) as accounts_with_closing_difference
    from fusion_rows as f
    left join (
        select gl_account_key, period_key, closing_balance from {{ ref('fact_gl_balance_monthly') }}
        where balance_view = 'posted' and is_prior_year_roll = 0
    ) as g on g.gl_account_key = f.gl_account_key and g.period_key = f.period_key
    group by f.branch_key, f.period_key
    {{ hnh_settings() }} -- CTE-level setting: unmatched balances must be NULL so ifNull counts them as differences
),

spine as (
    select branch_key, period_key from gold_activity
    union distinct
    select branch_key, period_key from fusion_activity
)

select
    s.branch_key                                            as branch_key,
    s.period_key                                            as period_key,
    ifNull(g.gold_debit, 0)                                 as gold_debit,
    ifNull(g.gold_credit, 0)                                as gold_credit,
    ifNull(fa.fusion_debit, 0)                              as fusion_debit,
    ifNull(fa.fusion_credit, 0)                             as fusion_credit,
    ifNull(g.gold_debit, 0) - ifNull(fa.fusion_debit, 0)    as debit_difference,
    ifNull(g.gold_credit, 0) - ifNull(fa.fusion_credit, 0)  as credit_difference,
    ifNull(c.accounts_compared, 0)                          as accounts_compared,
    ifNull(c.accounts_with_closing_difference, 0)           as accounts_with_closing_difference
from spine as s
left join gold_activity as g on g.branch_key = s.branch_key and g.period_key = s.period_key
left join fusion_activity as fa on fa.branch_key = s.branch_key and fa.period_key = s.period_key
left join closings as c on c.branch_key = s.branch_key and c.period_key = s.period_key
{{ hnh_settings() }}
