select
    trimBoth(CATEGORY_CODE)                 as category_code,
    trimBoth(ITEM_GROUP)                    as item_group
from {{ source('reference', 'map_item_group') }}
