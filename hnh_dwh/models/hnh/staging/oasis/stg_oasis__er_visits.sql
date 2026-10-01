select
    toUInt8(branch_id)                                  as branch_id,
    toInt64(er_visit_id)                                as er_visit_id,
    {{ hnh_id('patient_id') }}                          as patient_id,
    {{ hnh_id('episode_no') }}                          as episode_no,
    {{ hnh_id('priority') }}                            as priority,
    {{ hnh_ksa_wall_clock('time_arrived') }}            as arrived_at,
    {{ hnh_ksa_wall_clock('time_triaged') }}            as triaged_at,
    {{ hnh_ksa_wall_clock('time_treatment_started') }}  as treatment_started_at,
    {{ hnh_ksa_wall_clock('time_complete') }}           as completed_at,
    {{ hnh_id('referred_type') }}                       as referred_type_code,
    {{ hnh_id('outcome_code') }}                        as outcome_code,
    {{ hnh_code('er_status') }}                         as er_status,
    {{ hnh_id('work_entity') }}                         as work_entity,
    {{ hnh_code('treated_by') }}                        as treating_staff_id
from {{ hnh_oasis_source('patient_emergency_visit') }} final
