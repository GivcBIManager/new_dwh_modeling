{{ config(alias='dim_employee', order_by='employee_key') }}

-- Current state of each Fusion person (cancelled hires excluded). No names, contact details or identifiers.
with emp as (
    select * from {{ ref('stg_fusion__employees') }}
    where is_current = 1 and ifNull(worker_type, '') != 'CANCELED_HIRE'
    order by person_id, valid_from desc
    limit 1 by person_id
),

current_assignment as (
    select person_id, organization_id, job_id, grade_id, position_id, location_id, assignment_status
    from {{ ref('stg_fusion__assignments') }}
    where is_current = 1 and is_primary = 1 and person_id is not null
    order by person_id,
             multiIf(ifNull(assignment_status, '') = 'ACTIVE', 1, ifNull(assignment_status, '') = 'SUSPENDED', 2, 3),
             valid_from desc, assignment_id desc
    limit 1 by person_id
),

joined as (
    select
        e.person_id as person_id, e.person_number as person_number, p.worker_number as worker_number,
        e.worker_type as worker_type_code, e.gender as gender, e.nationality as nationality, e.birth_date as birth_date,
        coalesce(p.start_date, e.hire_date) as hire_date, p.original_hire_date as original_hire_date,
        coalesce(p.termination_date, e.termination_date) as termination_date, ifNull(p.is_terminated, toUInt8(0)) as is_terminated,
        ifNull(p.branch_key, toUInt8(0)) as branch_key,
        a.organization_id as organization_id, a.job_id as job_id, a.grade_id as grade_id, a.position_id as position_id,
        a.location_id as location_id, a.assignment_status as assignment_status, b.staff_key as staff_key
    from emp as e
    left join {{ ref('int_employee_period') }} as p on p.person_id = e.person_id
    left join current_assignment as a on a.person_id = e.person_id
    left join {{ ref('bridge_employee_staff') }} as b on b.employee_key = {{ hnh_surrogate_key(['e.person_id']) }}
    {{ hnh_settings() }}  -- left joins inside a CTE that feeds a union: settings must sit here
)

select
    {{ hnh_surrogate_key(['person_id']) }}                      as employee_key,
    toNullable(person_id)                                       as person_id,
    person_number, worker_number,
    {{ hnh_worker_type_label('worker_type_code') }}             as worker_type,
    worker_type_code, gender, nationality,
    toUInt8(ifNull(nationality, '') = 'SA')                     as is_saudi,
    birth_date,
    {{ hnh_age_band('birth_date', 'toDate32(today())') }}       as age_band,
    hire_date, original_hire_date, termination_date, is_terminated,
    {{ hnh_tenure_band('coalesce(original_hire_date, hire_date)', 'toDate32(today())') }} as tenure_band,
    branch_key,
    if(organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['organization_id']) }}) as hr_department_key,
    if(job_id is null, toInt64(-1), {{ hnh_surrogate_key(['job_id']) }})                   as job_key,
    if(grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['grade_id']) }})               as grade_key,
    if(position_id is null, toInt64(-1), {{ hnh_surrogate_key(['position_id']) }})         as position_key,
    if(location_id is null, toInt64(-1), {{ hnh_surrogate_key(['location_id']) }})         as location_key,
    assignment_status,
    ifNull(staff_key, toInt64(-1))                              as staff_key
from joined

union all

select toInt64(-1), null, null, null, 'Unknown', null, null, null, toUInt8(0), null, 'Unknown', null, null, null, toUInt8(0),
       'Unknown', toUInt8(0), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), null, toInt64(-1)
{{ hnh_settings() }}
