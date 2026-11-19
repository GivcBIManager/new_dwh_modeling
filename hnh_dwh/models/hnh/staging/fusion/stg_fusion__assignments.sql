select
    assignment_id,
    toDate32(valid_from)                    as valid_from,
    toDate32(ifNull(valid_to, toDateTime64('2299-12-31 00:00:00', 6, 'UTC'))) as valid_to,
    toUInt8(ifNull(is_current, '') = 'Y')   as is_current,
    person_id,
    {{ hnh_code('assignment_type') }}       as assignment_type,
    {{ hnh_code('assignment_status_type') }} as assignment_status,
    {{ hnh_flag('primary_flag') }}          as is_primary,
    organization_id,
    job_id,
    position_id,
    grade_id,
    location_id,
    legal_employer_id,
    {{ hnh_code('employment_category') }}   as employment_category,   -- assignment category: FR, FT, PR, PT
    {{ hnh_code('full_part_time') }}        as full_part_time,
    normal_hours,
    {{ hnh_code('normal_hours_frequency') }} as normal_hours_frequency,
    {{ hnh_is_part_time(hnh_code('employment_category'), hnh_code('full_part_time')) }} as is_part_time
from {{ hnh_fusion_source('dim_assignment') }} final
