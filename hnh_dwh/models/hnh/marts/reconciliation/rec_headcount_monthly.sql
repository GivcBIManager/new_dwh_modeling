{{ config(order_by='(branch_key, month_end)') }}

-- Fusion month-end headcount beside paid headcount from each payroll source, from the snapshot start.
with hc as (
    select branch_key, month_end, sumIf(headcount, is_contingent = 0) as fusion_headcount, sumIf(fte, is_contingent = 0) as fusion_fte
    from {{ ref('fact_headcount_monthly') }}
    group by branch_key, month_end
),

paid as (
    select branch_key, toLastDayOfMonth(makeDate(intDiv(payroll_month, 100), payroll_month % 100, 1)) as month_end,
           uniqExactIf(payee_key, source = 'oasis' and amount > 0 and pay_category = 'Basic') as oasis_paid_headcount,
           uniqExactIf(payee_key, source = 'fusion' and amount > 0 and pay_category = 'Basic') as fusion_paid_headcount
    from {{ ref('fact_payroll_monthly') }}
    where payroll_month >= toInt32(toYYYYMM(toDate('{{ var("hnh_hr_snapshot_start") }}')))
    group by branch_key, month_end
),

spine as (
    select branch_key, month_end from hc
    union distinct select branch_key, month_end from paid
)

select
    s.branch_key                            as branch_key,
    s.month_end                             as month_end,
    ifNull(h.fusion_headcount, 0)           as fusion_headcount,
    ifNull(h.fusion_fte, 0)                 as fusion_fte,
    ifNull(p.oasis_paid_headcount, 0)       as oasis_paid_headcount,
    ifNull(p.fusion_paid_headcount, 0)      as fusion_paid_headcount
from spine as s
left join hc as h on h.branch_key = s.branch_key and h.month_end = s.month_end
left join paid as p on p.branch_key = s.branch_key and p.month_end = s.month_end
{{ hnh_settings() }}
