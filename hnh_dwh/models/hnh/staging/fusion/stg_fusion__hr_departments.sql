select organization_id, {{ hnh_str('organization_name') }} as department_name
from {{ hnh_fusion_source('dim_department') }} final
where ifNull(is_current, '') = 'Y'
