select
    toUInt8(branch_id)                               as branch_id,
    toInt64(admission_request_id)                    as admission_request_id,
    {{ hnh_id('admission_no') }}                     as admission_no,
    {{ hnh_id('patient_id') }}                       as patient_id,
    {{ hnh_id('episode_no') }}                       as episode_no,
    {{ hnh_code('consultant_id') }}                  as consultant_staff_id,
    {{ hnh_ksa_wall_clock('planned_admit_date') }}   as planned_admit_at,
    {{ hnh_id('work_entity') }}                      as work_entity,
    {{ hnh_id('service_dept') }}                     as service_dept,
    {{ hnh_id('reason_for_admit') }}                 as reason_code,
    {{ hnh_id('admission_department') }}             as admission_department_code,
    {{ hnh_id('urgency') }}                          as urgency_code,
    {{ hnh_code('admission_type') }}                 as admission_type,
    {{ hnh_ksa_wall_clock('creation_date') }}        as created_at
from {{ hnh_oasis_source('admission_request') }} final
