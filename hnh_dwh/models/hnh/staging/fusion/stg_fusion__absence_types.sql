select absence_type_id, {{ hnh_str('absence_type_name') }} as absence_type_name,
       {{ hnh_str('absence_plan_name') }} as absence_plan_name, {{ hnh_code('plan_type') }} as plan_type,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_absence_type') }} final
order by is_current desc, valid_from desc, valid_to desc
limit 1 by absence_type_id
