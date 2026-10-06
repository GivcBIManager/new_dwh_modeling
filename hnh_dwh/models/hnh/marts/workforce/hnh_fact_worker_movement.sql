{{ config(alias='fact_worker_movement', order_by='(branch_key, action_date_key, movement_key)') }}

-- One Fusion assignment action from 2022 (spec 6.3). Branch from the legal employer of the assignment valid on the action
-- date (previous branch: the day before), falling back to the department prefix, then the employee's current branch.
with mv as (
    select * from {{ ref('stg_fusion__worker_movements') }}
    where action_date >= toDate32('{{ var("hnh_history_start_date") }}') and person_id is not null
),

depts as (select organization_id as dept_org_id, branch_key as dept_org_branch from {{ ref('hnh_dim_hr_department') }} where organization_id is not null),

-- Legal employer valid on the action date (own assignment) and the day before: the same assignment's row, else the
-- person's primary assignment (a transfer starts a new assignment id). One row per movement.
le as (
    select m.assignment_id as assignment_id, m.effective_end_date_key as effective_end_date_key, m.effective_sequence as effective_sequence,
           argMaxIf(a.legal_employer_id, a.valid_from, a.assignment_id = m.assignment_id and a.valid_from <= m.action_date and a.valid_to >= m.action_date) as cur_le,
           ifNull(argMaxIf(a.legal_employer_id, a.valid_from, a.assignment_id = m.assignment_id and a.valid_from <= m.action_date - 1 and a.valid_to >= m.action_date - 1),
                  argMaxIf(a.legal_employer_id, a.valid_from, a.is_primary = 1 and a.valid_from <= m.action_date - 1 and a.valid_to >= m.action_date - 1)) as prev_le
    from mv as m
    inner join (select person_id, assignment_id, is_primary, valid_from, valid_to, legal_employer_id from {{ ref('stg_fusion__assignments') }}) as a
        on a.person_id = m.person_id
    group by m.assignment_id, m.effective_end_date_key, m.effective_sequence
),

le_branch as (
    select le.assignment_id as lb_assignment_id, le.effective_end_date_key as lb_end_key, le.effective_sequence as lb_seq,
           c.branch_key as cur_le_branch, p.branch_key as prev_le_branch
    from le
    left join (select legal_employer_id, branch_key from {{ ref('int_legal_employer_branch') }}) as c on c.legal_employer_id = le.cur_le
    left join (select legal_employer_id, branch_key from {{ ref('int_legal_employer_branch') }}) as p on p.legal_employer_id = le.prev_le
    {{ hnh_settings() }}  -- unresolved employers stay NULL, not 0
),

joined as (
    select m.*, d.dept_org_branch as dept_branch, pd.dept_org_branch as prev_dept_branch,
           lb.cur_le_branch as cur_le_branch, lb.prev_le_branch as prev_le_branch,
           e.employee_key as employee_key, e.branch_key as employee_branch, e.staff_key as staff_key,
           wa.worker_action_key as action_key_found
    from mv as m
    left join depts as d on d.dept_org_id = m.organization_id
    left join depts as pd on pd.dept_org_id = m.previous_organization_id
    left join le_branch as lb on lb.lb_assignment_id = m.assignment_id and lb.lb_end_key = m.effective_end_date_key
        and lb.lb_seq = m.effective_sequence
    inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = m.person_id
    left join (select worker_action_key, ifNull(action_code, '') as wa_code, ifNull(action_reason_code, '') as wa_reason
               from {{ ref('hnh_dim_worker_action') }} where worker_action_key != -1) as wa
        on wa.wa_code = ifNull(m.action_code, '') and wa.wa_reason = ifNull(m.action_reason_code, '')
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['assignment_id', 'effective_end_date_key', 'effective_sequence']) }}  as movement_key,
    multiIf(ifNull(cur_le_branch, 0) != 0, assumeNotNull(cur_le_branch), ifNull(dept_branch, 0) != 0, assumeNotNull(dept_branch), employee_branch) as branch_key,
    multiIf(ifNull(prev_le_branch, 0) != 0, assumeNotNull(prev_le_branch), ifNull(prev_dept_branch, 0) != 0, assumeNotNull(prev_dept_branch), branch_key) as previous_branch_key,
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
