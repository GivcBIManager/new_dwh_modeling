{{ config(alias='vw_work_force') }}

-- Old bsc.vw_work_force (bsc spec 7.5) for closed months from January of last year. Heads: Fusion month-end
-- headcount (employees, not contingent) from hnh_hr_snapshot_start, paid people (gross pay > 0, no parallel run)
-- before it. Part-time doctors are doctors with revenue in the month who are neither in that month's headcount nor
-- paid; they are added to headcount, doctors and medical, and count 0.5 FTE, as in the old view. Resignations: Fusion
-- voluntary leavers for branches 6-8 from hnh_hr_snapshot_start, where Fusion leaver reasons are kept (F10); Oasis
-- staff termination otherwise (branches 1-5, and every branch before Fusion HR started).
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_,
    subtractYears(toStartOfYear(today_ - 1), 1) as from_date_,
    toDate('{{ var('hnh_hr_snapshot_start') }}') as fusion_start_,
months as (
    select distinct toDate(start_of_month) as period
    from {{ ref('dim_date') }}
    where date_day >= from_date_ and date_day < toStartOfMonth(today_)
),
spine as (
    select b.branch_key as branch_key, m.period as period
    from {{ ref('hnh_dim_branch') }} as b
    cross join months as m
    where b.branch_key between 1 and 8
),
staff as (
    select staff_key, branch_key, ifNull(classification, '') as classification, ifNull(category, '') as category,
           termination_date, ifNull(termination_reason, '') as termination_reason
    from {{ ref('dim_staff') }}
),
paid as (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(month_date_key))) as period, paid_person_key,
           any(staff_key) as paid_staff_key
    from {{ ref('fact_payroll_monthly') }}
    where ifNull(is_parallel_run, 0) = 0
    group by branch_key, period, paid_person_key
    having sum(gross_pay) > 0
),
people as (
    select h.branch_key as branch_key, toStartOfMonth(h.month_end) as period, toString(h.employee_key) as person_id,
           h.staff_key as staff_key, h.fte as fte
    from {{ ref('fact_headcount_monthly') }} as h
    where h.is_contingent = 0 and h.headcount > 0 and toStartOfMonth(h.month_end) >= fusion_start_
    union all
    select branch_key, period, concat('paid-', toString(paid_person_key)), paid_staff_key, toFloat64(1)
    from paid
    where period < fusion_start_
),
heads as (
    select p.branch_key as branch_key, p.period as period,
           uniqExact(p.person_id)                                              as hc,
           uniqExactIf(p.person_id, s.classification in ('NURSE', 'DOC'))     as hc_medical,
           uniqExactIf(p.person_id, s.category = 'DOCTORS')                   as hc_doctors,
           sum(p.fte)                                                         as fte_total
    from people as p
    left join staff as s on s.staff_key = p.staff_key
    group by branch_key, period
),
covered as (
    select staff_key, period from people where staff_key != -1
    union distinct
    select paid_staff_key as staff_key, period from paid where paid_staff_key != -1
),
revenue_doctors as (
    select c.branch_key as branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(c.delivery_date_key))) as period,
           c.staff_key as staff_key
    from {{ ref('fact_charge_line') }} as c
    where c.staff_key != -1 and c.branch_key between 1 and 8 and c.delivery_date_key >= toInt32(toYYYYMMDD(from_date_))
    group by branch_key, period, staff_key
    having sum(c.revenue_amount) > 0
),
part_time as (
    select r.branch_key as branch_key, r.period as period, uniqExact(r.staff_key) as pt_doctors
    from revenue_doctors as r
    inner join staff as s on s.staff_key = r.staff_key
    left anti join covered as v on v.staff_key = r.staff_key and v.period = r.period
    where s.category = 'DOCTORS'
    group by branch_key, period
),
resignations as (
    select branch_key, toDate(toStartOfMonth(termination_date)) as period, count() as resigned
    from staff
    where termination_reason = 'Resignation' and termination_date is not null
      and (branch_key between 1 and 5 or toDate(toStartOfMonth(termination_date)) < fusion_start_)
    group by branch_key, period
    union all
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(action_date_key))) as period, countIf(is_voluntary_leaver = 1)
    from {{ ref('hnh_fact_worker_movement') }}
    where branch_key between 6 and 8 and toStartOfMonth(YYYYMMDDToDate(toUInt32(action_date_key))) >= fusion_start_
    group by branch_key, period
)
select
    toDate32(sp.period)                                      as period,
    toUInt64(sp.branch_key)                                  as branch_id,
    toUInt64(h.hc + pt.pt_doctors)                           as headcount,
    toUInt64(r.resigned)                                     as resignations,
    toUInt64(h.hc_medical + pt.pt_doctors)                   as medical_headcount,
    toUInt64(h.hc_doctors + pt.pt_doctors)                   as doctors_headcount,
    toUInt64(pt.pt_doctors)                                  as pt_doctors_headcount,
    toFloat64(h.fte_total + 0.5 * pt.pt_doctors)             as FTE
from spine as sp
left join heads as h on h.branch_key = sp.branch_key and h.period = sp.period
left join part_time as pt on pt.branch_key = sp.branch_key and pt.period = sp.period
left join resignations as r on r.branch_key = sp.branch_key and r.period = sp.period
settings join_use_nulls = 0
