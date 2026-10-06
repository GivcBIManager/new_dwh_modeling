select grade_id, {{ hnh_str('grade_code') }} as grade_code, {{ hnh_str('grade_name') }} as grade_name
from {{ hnh_fusion_source('dim_grade') }} final
where ifNull(is_current, '') = 'Y'
