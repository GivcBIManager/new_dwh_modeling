{{ config(order_by='(branch_key, accrual_period_date_key, leave_balance_key)') }}

-- Leave balances with liability for annual-leave plans (spec 6.6): daily rate = monthly salary / 30, monthly salary =
-- recurring pay (Basic, Housing, Transport, Food, Clinical and Other allowances) of the latest payroll month on or before
-- the accrual period.
with balances as (
    select b.accrual_entry_id as accrual_entry_id, b.absence_plan_id as absence_plan_id, b.accrual_period_date as accrual_period_date,
           b.begin_balance as begin_balance, b.accrued as accrued, b.used as used, b.end_balance as end_balance,
           e.employee_key as employee_key, e.branch_key as branch_key,
           p.absence_plan_name as absence_plan_name,
           toUInt8(lower(ifNull(p.absence_plan_name, '')) like '%annual leave%') as is_annual_plan,
           toInt32(toYYYYMM(b.accrual_period_date)) as accrual_month
    from {{ ref('stg_fusion__absence_balances') }} as b
    inner join (select employee_key, person_id, branch_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = b.person_id
    left join {{ ref('stg_fusion__absence_plans') }} as p on p.absence_plan_id = b.absence_plan_id
    {{ hnh_settings() }}
),

salary as (
    select employee_key, payroll_month, sum(amount) as monthly_salary
    from {{ ref('fact_payroll_monthly') }}
    where is_parallel_run = 0 and employee_key != -1
      and pay_category in ('Basic', 'Housing', 'Transport', 'Food', 'Clinical allowances', 'Other allowances')
    group by employee_key, payroll_month
)

select
    {{ hnh_surrogate_key(['b.accrual_entry_id']) }}                     as leave_balance_key,
    b.branch_key                                                        as branch_key,
    b.employee_key                                                      as employee_key,
    b.absence_plan_id                                                   as absence_plan_id,
    b.absence_plan_name                                                 as absence_plan_name,
    b.is_annual_plan                                                    as is_annual_plan,
    ifNull({{ hnh_date_key_in_range('b.accrual_period_date') }}, 0)     as accrual_period_date_key,
    b.begin_balance, b.accrued, b.used, b.end_balance,
    if(b.is_annual_plan = 1 and s.payroll_month is not null, toNullable(s.monthly_salary), cast(null as Nullable(Float64))) as monthly_salary,
    monthly_salary / 30                                                 as daily_rate,
    b.end_balance * daily_rate                                          as leave_liability_amount,
    now()                                                               as _loaded_at
from balances as b
asof left join salary as s on s.employee_key = b.employee_key and s.payroll_month <= b.accrual_month
{{ hnh_settings() }}
