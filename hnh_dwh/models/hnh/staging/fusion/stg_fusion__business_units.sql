select
    business_unit_id,
    {{ hnh_str('business_unit_name') }}     as business_unit_name,
    primary_ledger_id
from {{ hnh_fusion_source('dim_business_unit') }} final
