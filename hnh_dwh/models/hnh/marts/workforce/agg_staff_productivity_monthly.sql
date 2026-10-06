{{ config(order_by='(branch_key, month_date_key, staff_key)') }}

-- Linked doctors and nurses per month from the snapshot start (spec 6.7): one row per staff and month with activity
-- or pay. Ratios are sums over this table in SSAS. Months after the current month (planned leave, future month-ends) are dropped.
{% set start_key = "toInt32(toYYYYMMDD(toDate('" ~ var('hnh_hr_snapshot_start') ~ "')))" %}

with linked as (
    -- bridge_employee_staff is one row per employee and 3 staff records are shared by 2 employees each: one row per staff here
    select b.staff_key as staff_key, any(b.branch_key) as branch_key, any(s.category) as staff_category
    from {{ ref('bridge_employee_staff') }} as b
    inner join (select staff_key, category from {{ ref('dim_staff') }}) as s on s.staff_key = b.staff_key
    where ifNull(s.category, '') in ('DOCTORS', 'NURSE')
    group by b.staff_key
),

measures as (
    select treating_staff_key as staff_key, toStartOfMonth(toDate(toString(encounter_date_key))) as month_start,
           toUInt64(count()) as encounters_seen, toFloat64(0) as revenue_amount, toFloat64(0) as payroll_cost,
           toFloat64(0) as gross_pay, toFloat64(0) as fte, toFloat64(0) as absence_days
    from {{ ref('fact_encounter') }}
    where is_arrived = 1 and is_cancelled = 0 and encounter_date_key >= {{ start_key }}
      and treating_staff_key in (select staff_key from linked)
    group by staff_key, month_start
    union all
    select staff_key, toStartOfMonth(toDate(toString(delivery_date_key))), toUInt64(0), toFloat64(sum(revenue_amount)), toFloat64(0), toFloat64(0), toFloat64(0), toFloat64(0)
    from {{ ref('fact_charge_line') }}
    where delivery_date_key >= {{ start_key }} and staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(toDate(toString(delivery_date_key)))
    union all
    select staff_key, toStartOfMonth(toDate(toString(month_date_key))), toUInt64(0), toFloat64(0), toFloat64(sum(cost_amount)), toFloat64(sum(gross_pay)), toFloat64(0), toFloat64(0)
    from {{ ref('fact_payroll_monthly') }}
    where month_date_key >= {{ start_key }} and staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(toDate(toString(month_date_key)))
    union all
    select staff_key, toStartOfMonth(month_end), toUInt64(0), toFloat64(0), toFloat64(0), toFloat64(0), toFloat64(max(fte)), toFloat64(0)
    -- max per staff and month over non-contingent rows: 3 staff records are shared by 2 employees each
    from {{ ref('fact_headcount_monthly') }}
    where is_contingent = 0 and month_end >= toDate('{{ var("hnh_hr_snapshot_start") }}') and staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(month_end)
    union all
    select staff_key, toStartOfMonth(toDate(toString(date_key))), toUInt64(0), toFloat64(0), toFloat64(0), toFloat64(0), toFloat64(0), toFloat64(sum(absence_days))
    from {{ ref('fact_absence_daily') }}
    where date_key >= {{ start_key }} and staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(toDate(toString(date_key)))
)

select
    m.staff_key                                 as staff_key,
    l.branch_key                                as branch_key,
    {{ hnh_date_key('m.month_start') }}         as month_date_key,
    m.month_start                               as month_start,
    any(l.staff_category)                       as staff_category,
    sum(m.encounters_seen)                      as encounters_seen,
    sum(m.revenue_amount)                       as revenue_amount,
    sum(m.payroll_cost)                         as payroll_cost,
    sum(m.gross_pay)                            as gross_pay,
    sum(m.fte)                                  as fte,
    sum(m.absence_days)                         as absence_days,
    now()                                       as _loaded_at
from measures as m
inner join linked as l on l.staff_key = m.staff_key
where m.month_start <= toStartOfMonth(today())
group by m.staff_key, l.branch_key, m.month_start
