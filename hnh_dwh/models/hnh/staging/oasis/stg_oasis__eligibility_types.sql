select
    toUInt8(branch_id)                          as branch_id,
    toInt64(eligibility_type)                   as eligibility_type,
    {{ hnh_str('eligibility_description') }}    as description,
    {{ hnh_code('attendence_type') }}           as attendance_type,
    toInt32(eligibility_no_days)                as free_follow_up_days
from {{ source('oasis', 'eligibility_types') }} final
