select organization_id, {{ hnh_str('organization_name') }} as department_name,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_department') }} final
order by valid_from desc, valid_to desc
limit 1 by organization_id
