select
    trimBoth(SPECIALTY_CODE)                  as specialty_code,
    {{ hnh_str('SPECIALTY_NAME') }}           as specialty_name,
    {{ hnh_str('UNIFIED_DEPARTMENT') }}       as unified_department
from {{ source('reference', 'map_fusion_specialty_unified') }}
