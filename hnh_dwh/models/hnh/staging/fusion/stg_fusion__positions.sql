select position_id, {{ hnh_str('position_code') }} as position_code, {{ hnh_str('position_name') }} as position_name
from {{ hnh_fusion_source('dim_position') }} final
where ifNull(is_current, '') = 'Y'
