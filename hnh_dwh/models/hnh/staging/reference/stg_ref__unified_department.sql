select
    upper(trimBoth(DEPARTMENT))            as department,
    min(trimBoth(UNIFIED_DEPARTMENT))      as unified_department,
    toUInt8(max(NOT_ADMITTING))            as not_admitting,
    toUInt8(max(High_Value))               as high_value
from {{ source('reference', 'map_unified_department_v2') }}
group by department
