select
    upper(trimBoth(CODE))   as reason_code,
    trimBoth(REASON)        as reason,
    trimBoth(CATEGORY)      as reason_category
from {{ source('reference', 'map_nphies_reason') }}
