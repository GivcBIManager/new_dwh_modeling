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
    legal_employer_id
from {{ hnh_fusion_source('dim_assignment') }} final
