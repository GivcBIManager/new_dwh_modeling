select absence_plan_id, {{ hnh_str('absence_plan_name') }} as absence_plan_name, {{ hnh_code('plan_type') }} as plan_type
from {{ hnh_fusion_source('dim_absence_plan') }} final
where ifNull(is_current, '') = 'Y'
