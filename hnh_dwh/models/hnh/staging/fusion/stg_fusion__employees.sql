select
    person_id,
    toDate32(valid_from)                    as valid_from,
    toDate32(ifNull(valid_to, toDateTime64('2299-12-31 00:00:00', 6, 'UTC'))) as valid_to,
    toUInt8(ifNull(is_current, '') = 'Y')   as is_current,
    {{ hnh_code('person_number') }}         as person_number,
    {{ hnh_code('worker_type') }}           as worker_type,
    {{ hnh_code('gender') }}                as gender,
    {{ hnh_code('nationality') }}           as nationality,
    toDate32(date_of_birth)                 as birth_date,
    toDate32(hire_date)                     as hire_date,
    toDate32(actual_termination_date)       as termination_date,
    legal_employer_id
from {{ hnh_fusion_source('dim_employee') }} final
