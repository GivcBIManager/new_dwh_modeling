{{ config(order_by='eligibility_type_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'eligibility_type']) }} as eligibility_type_key,
    branch_id                              as branch_key,
    toNullable(eligibility_type)           as eligibility_type,
    ifNull(description, 'Not named')       as description,
    {{ hnh_care_type('attendance_type') }} as care_type,
    free_follow_up_days                    as free_follow_up_days
from {{ ref('stg_oasis__eligibility_types') }}

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', null
