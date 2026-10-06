{{ config(order_by='(branch_key, payroll_month)') }}

-- Payroll cost against the GL (employee-cost budget lines and Payroll-source journal debits) and Oasis against Fusion
-- in parallel-run months, per branch and month.
with pay as (
    select branch_key, payroll_month,
           sum(cost_amount) as payroll_cost_sum, sum(gross_pay) as gross_pay_sum,
           sumIf(amount, source = 'oasis' and is_parallel_run = 1 and pay_category in (select pay_category from {{ ref('dim_pay_category') }} where is_gross_pay = 1)) as oasis_parallel_gross_pay,
           sumIf(gross_pay, source = 'fusion') as fusion_gross_pay_sum
    from {{ ref('fact_payroll_monthly') }}
    group by branch_key, payroll_month
),

gl_cost as (
    select branch_key, toInt32(toYYYYMM(month_start)) as payroll_month, sum(actual_excl_opening) as gl_employee_cost
    from {{ ref('fact_income_statement_monthly') }}
    where budget_line_code in ('DC_EMPLOYEE', 'GA_EMPLOYEE')
    group by branch_key, payroll_month
),

gl_journal as (
    select j.branch_key as branch_key, toInt32(toYYYYMM(p.end_date)) as payroll_month, sum(j.debit) as gl_payroll_journal_debit, sum(j.credit) as gl_payroll_journal_credit
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join (select gl_account_key from {{ ref('hnh_dim_gl_account') }} where balance_side = 'IS') as a on a.gl_account_key = j.gl_account_key
    inner join (select period_key, end_date from {{ ref('hnh_dim_gl_period') }}) as p on p.period_key = j.period_key
    where j.je_source_label = 'Payroll'
    group by branch_key, payroll_month
),

spine as (
    select branch_key, payroll_month from pay
    union distinct select branch_key, payroll_month from gl_cost
    union distinct select branch_key, payroll_month from gl_journal
)

select
    s.branch_key                                    as branch_key,
    s.payroll_month                                 as payroll_month,
    ifNull(p.payroll_cost_sum, 0)                       as payroll_cost,
    ifNull(p.gross_pay_sum, 0)                          as gross_pay,
    ifNull(p.oasis_parallel_gross_pay, 0)           as oasis_parallel_gross_pay,
    ifNull(p.fusion_gross_pay_sum, 0)                   as fusion_gross_pay,
    ifNull(c.gl_employee_cost, 0)                   as gl_employee_cost,
    ifNull(g.gl_payroll_journal_debit, 0)           as gl_payroll_journal_debit,
    ifNull(g.gl_payroll_journal_credit, 0)          as gl_payroll_journal_credit
from spine as s
left join pay as p on p.branch_key = s.branch_key and p.payroll_month = s.payroll_month
left join gl_cost as c on c.branch_key = s.branch_key and c.payroll_month = s.payroll_month
left join gl_journal as g on g.branch_key = s.branch_key and g.payroll_month = s.payroll_month
where s.payroll_month <= toYYYYMM(today())
{{ hnh_settings() }}
