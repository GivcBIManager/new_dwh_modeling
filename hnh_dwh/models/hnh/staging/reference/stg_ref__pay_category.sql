select
    lower(trimBoth(SOURCE))         as source,
    trimBoth(SOURCE_CODE)           as source_code,
    upper(trimBoth(PAYABLE_TYPE))   as payable_type,
    trimBoth(PAY_CATEGORY)          as pay_category
from {{ source('reference', 'map_pay_category') }}
