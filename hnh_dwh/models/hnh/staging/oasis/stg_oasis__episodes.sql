select
    toUInt8(branch_id)                       as branch_id,
    toInt64(patient_id)                      as patient_id,
    toInt64(episode_no)                      as episode_no,
    {{ hnh_ksa_wall_clock('start_date') }}   as started_at,
    {{ hnh_ksa_wall_clock('end_date') }}     as ended_at,
    {{ hnh_id('eligibility_type') }}         as eligibility_type
from {{ hnh_oasis_source('patient_episodes') }} final
