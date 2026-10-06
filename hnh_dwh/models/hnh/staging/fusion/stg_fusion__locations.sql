select location_id, {{ hnh_str('location_code') }} as location_code, {{ hnh_str('location_name') }} as location_name,
       {{ hnh_str('town_or_city') }} as town_or_city,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_location') }} final
order by valid_from desc, valid_to desc
limit 1 by location_id
