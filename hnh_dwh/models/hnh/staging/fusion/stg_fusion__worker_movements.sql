select
    assignment_id,
    effective_end_date_key,
    effective_sequence,
    toDate32(effective_start_date)          as effective_start_date,
    person_id,
    {{ hnh_code('action_code') }}           as action_code,
    {{ hnh_code('action_reason_code') }}    as action_reason_code,
    toDate32(coalesce(action_date, effective_start_date)) as action_date,
    {{ hnh_code('assignment_status_type') }} as assignment_status,
    organization_id, job_id, position_id, grade_id, location_id,
    previous_organization_id, previous_job_id, previous_position_id, previous_grade_id, previous_location_id,
    {{ hnh_flag('organization_changed_flag') }} as is_organization_changed,
    {{ hnh_flag('job_changed_flag') }}          as is_job_changed,
    {{ hnh_flag('position_changed_flag') }}     as is_position_changed,
    {{ hnh_flag('grade_changed_flag') }}        as is_grade_changed,
    {{ hnh_flag('location_changed_flag') }}     as is_location_changed
from {{ hnh_fusion_source('fact_worker_movement') }} final
