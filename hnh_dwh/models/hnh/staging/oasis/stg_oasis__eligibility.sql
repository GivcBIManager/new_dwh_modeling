select
    toUInt8(branch_id)                          as branch_id,
    toInt64(patient_eligibility_id)             as patient_eligibility_id,
    {{ hnh_id('patient_id') }}                  as patient_id,
    {{ hnh_id('episode_no') }}                  as episode_no,
    toInt64(sequence)                           as sequence,
    {{ hnh_str('responsibility') }}             as responsibility,
    {{ hnh_code('attendance_type') }}           as attendance_type,
    {{ hnh_code('consultant_id') }}             as consultant_staff_id,
    {{ hnh_id('eligibility_service_dept') }}    as service_dept,
    {{ hnh_id('work_entity') }}                 as work_entity,
    {{ hnh_id('eligibility_work_entity') }}     as eligibility_work_entity,
    {{ hnh_id('admission_no') }}                as admission_no
from {{ hnh_oasis_source('patient_eligibility') }} final
