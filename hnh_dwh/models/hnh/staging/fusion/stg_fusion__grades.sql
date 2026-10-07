select grade_id, {{ hnh_str('grade_code') }} as grade_code, {{ hnh_str('grade_name') }} as grade_name,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_grade') }} final
order by is_current desc, valid_from desc, valid_to desc
limit 1 by grade_id
