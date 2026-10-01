select
    toUInt8(BRANCH_ID)             as branch_id,
    toInt64(PURCHASER_CODE)        as purchaser_code,
    {{ hnh_str('INSURANCE') }}     as insurer,
    {{ hnh_str('CREDITOR') }}      as creditor,
    {{ hnh_str('CATEGORY') }}      as category,
    {{ hnh_str('BILLING_TYPE') }}  as billing_type,
    {{ hnh_str('MANUAL_SUBMISSION') }} as manual_submission
from {{ source('reference', 'map_purchasers') }} final
