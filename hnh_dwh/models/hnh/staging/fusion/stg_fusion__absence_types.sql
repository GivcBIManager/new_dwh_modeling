select absence_type_id, {{ hnh_str('absence_type_name') }} as absence_type_name,
       {{ hnh_str('absence_plan_name') }} as absence_plan_name, {{ hnh_code('plan_type') }} as plan_type
from {{ hnh_fusion_source('dim_absence_type') }} final
where ifNull(is_current, '') = 'Y'
