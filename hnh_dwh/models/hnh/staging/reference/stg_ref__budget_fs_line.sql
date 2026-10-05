select
    upper(trimBoth(LINE_ITEM_CODE))           as line_item_code,
    lower(trimBoth(MATCH_LEVEL))              as match_level,
    lower({{ hnh_fs_label('MATCH_VALUE') }})  as match_value_lower,
    {{ hnh_str('CARE_TYPE') }}                as care_type
from {{ source('reference', 'map_budget_fs_line') }}
