{{ config(alias='fact_worker_movement', order_by='(branch_key, action_date_key, movement_key)') }}

-- One Fusion assignment action from 2022 (spec 6.3). Branch from the department prefix (plan refinement), falling
-- back to the person's current branch.
with mv as (
    select * from {{ ref('stg_fusion__worker_movements') }}
    where action_date >= toDate32('{{ var("hnh_history_start_date") }}') and person_id is not null
),

depts as (select organization_id as dept_org_id, branch_key as dept_org_branch from {{ ref('hnh_dim_hr_department') }} where organization_id is not null),

joined as (
    select m.*, d.dept_org_branch as dept_branch, pd.dept_org_branch as prev_dept_branch,
           e.employee_key as employee_key, e.branch_key as employee_branch, e.staff_key as staff_key,
           wa.worker_action_key as action_key_found
    from mv as m
    left join depts as d on d.dept_org_id = m.organization_id
    left join depts as pd on pd.dept_org_id = m.previous_organization_id
    inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = m.person_id
    left join (select worker_action_key, ifNull(action_code, '') as wa_code, ifNull(action_reason_code, '') as wa_reason
               from {{ ref('hnh_dim_worker_action') }} where worker_action_key != -1) as wa
        on wa.wa_code = ifNull(m.action_code, '') and wa.wa_reason = ifNull(m.action_reason_code, '')
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['assignment_id', 'effective_end_date_key', 'effective_sequence']) }}  as movement_key,
    if(ifNull(dept_branch, 0) = 0, employee_branch, assumeNotNull(dept_branch))             as branch_key,
    if(ifNull(prev_dept_branch, 0) = 0, branch_key, assumeNotNull(prev_dept_branch))        as previous_branch_key,
    employee_key,
    staff_key,
    ifNull(action_key_found, toInt64(-1))                                                   as worker_action_key,
    {{ hnh_date_key('assumeNotNull(action_date)') }}                                                       as action_date_key,
    if(organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['organization_id']) }})            as hr_department_key,
    if(previous_organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_organization_id']) }}) as previous_hr_department_key,
    if(job_id is null, toInt64(-1), {{ hnh_surrogate_key(['job_id']) }})                    as job_key,
    if(previous_job_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_job_id']) }})  as previous_job_key,
    if(grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['grade_id']) }})                as grade_key,
    if(previous_grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_grade_id']) }}) as previous_grade_key,
    if(position_id is null, toInt64(-1), {{ hnh_surrogate_key(['position_id']) }})          as position_key,
    if(previous_position_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_position_id']) }}) as previous_position_key,
    if(location_id is null, toInt64(-1), {{ hnh_surrogate_key(['location_id']) }})          as location_key,
    if(previous_location_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_location_id']) }}) as previous_location_key,
    action_code,
    {{ hnh_movement_group('action_code') }}                                                 as movement_group,
    is_organization_changed, is_job_changed, is_position_changed, is_grade_changed, is_location_changed,
    toUInt8(movement_group in ('Hire', 'Rehire'))                                           as is_hire,
    toUInt8(movement_group in ('Voluntary leaver', 'Involuntary leaver'))                   as is_leaver,
    toUInt8(movement_group = 'Voluntary leaver')                                            as is_voluntary_leaver,
    toUInt8(branch_key != previous_branch_key)                                              as is_branch_transfer,
    now()                                                                                   as _loaded_at
from joined
