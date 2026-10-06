select absence_plan_id, {{ hnh_str('absence_plan_name') }} as absence_plan_name, {{ hnh_code('plan_type') }} as plan_type,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_absence_plan') }} final
order by is_current desc, valid_from desc, valid_to desc
limit 1 by absence_plan_id
