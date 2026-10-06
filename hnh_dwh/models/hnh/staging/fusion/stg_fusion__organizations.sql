select organization_id,
       {{ hnh_str('organization_name') }}      as organization_name,
       {{ hnh_str('classification_codes') }}   as classification_codes,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_organization') }} final
order by valid_from desc, valid_to desc
limit 1 by organization_id
