select location_id, {{ hnh_str('location_code') }} as location_code, {{ hnh_str('location_name') }} as location_name,
       {{ hnh_str('town_or_city') }} as town_or_city
from {{ hnh_fusion_source('dim_location') }} final
where ifNull(is_current, '') = 'Y'
limit 1 by location_id
