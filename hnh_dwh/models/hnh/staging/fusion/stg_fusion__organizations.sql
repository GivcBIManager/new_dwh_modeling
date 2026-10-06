select organization_id,
       {{ hnh_str('organization_name') }}      as organization_name,
       {{ hnh_str('classification_codes') }}   as classification_codes
from {{ hnh_fusion_source('dim_organization') }} final
where ifNull(is_current, '') = 'Y'
limit 1 by organization_id
