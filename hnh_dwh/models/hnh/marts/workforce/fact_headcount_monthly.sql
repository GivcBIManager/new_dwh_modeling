{{ config(order_by='(branch_key, month_date_key, employee_key)') }}

-- Primary assignment ACTIVE or SUSPENDED at a month-end (spec 6.1), cancelled hires excluded through dim_employee.
with snap as (
    select * from {{ ref('int_assignment_month_end') }}
    where ifNull(assignment_status, '') in ('ACTIVE', 'SUSPENDED')
),

joined as (
    select s.person_id as person_id, s.month_end as month_end, s.branch_key as branch_key, s.assignment_status as assignment_status,
           s.organization_id as organization_id, s.job_id as job_id, s.grade_id as grade_id, s.position_id as position_id,
           s.location_id as location_id, s.fte as fte,
           e.employee_key as employee_key, e.worker_type_code as worker_type_code, e.gender as gender, e.is_saudi as is_saudi,
           e.birth_date as birth_date, e.staff_key as staff_key,
           p.start_date as start_date, p.original_hire_date as original_hire_date, p.termination_date as termination_date
    from snap as s
    inner join (select employee_key, person_id, worker_type_code, gender, is_saudi, birth_date, staff_key
                from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = s.person_id
    left join {{ ref('int_employee_period') }} as p on p.person_id = s.person_id
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['employee_key', 'month_end']) }}                          as headcount_key,
    branch_key,
    employee_key,
    staff_key,
    if(organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['organization_id']) }}) as hr_department_key,
    if(job_id is null, toInt64(-1), {{ hnh_surrogate_key(['job_id']) }})                   as job_key,
    if(grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['grade_id']) }})               as grade_key,
    if(position_id is null, toInt64(-1), {{ hnh_surrogate_key(['position_id']) }})         as position_key,
    if(location_id is null, toInt64(-1), {{ hnh_surrogate_key(['location_id']) }})         as location_key,
    {{ hnh_date_key('month_end') }}                                                 as month_date_key,
    month_end,
    toUInt8(month_end < today())                                                    as is_closed_month,
    worker_type_code,
    toUInt8(ifNull(worker_type_code, '') in ('CWK', 'CON'))                         as is_contingent,
    assignment_status,
    is_saudi,
    gender,
    {{ hnh_age_band('birth_date', 'toDate32(month_end)') }}                         as age_band,
    {{ hnh_tenure_band('coalesce(original_hire_date, start_date)', 'toDate32(month_end)') }} as tenure_band,
    toUInt8(1)                                                                      as headcount,
    fte,
    toUInt8(start_date is not null and toStartOfMonth(start_date) = toStartOfMonth(month_end))             as is_new_hire_in_month,
    toUInt8(termination_date is not null and toStartOfMonth(termination_date) = toStartOfMonth(month_end)) as is_leaver_in_month,
    now()                                                                           as _loaded_at
from joined
