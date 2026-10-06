select position_id, {{ hnh_str('position_code') }} as position_code, {{ hnh_str('position_name') }} as position_name,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_position') }} final
order by valid_from desc, valid_to desc
limit 1 by position_id
