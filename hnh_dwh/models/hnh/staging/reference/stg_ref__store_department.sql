select
    lower(trimBoth(SOURCE))                 as source,
    toUInt8(BRANCH_ID)                      as branch_id,
    trimBoth(STORE_CODE)                    as store_code,
    trimBoth(STORE_NAME)                    as store_name,
    trimBoth(STORE_TYPE)                    as store_type,
    trimBoth(UNIFIED_DEPARTMENT)            as unified_department
from {{ source('reference', 'map_store_department') }}
