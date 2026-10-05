select
    toUInt8(branch_id)                       as branch_id,
    toInt64(ios)                             as ios,
    {{ hnh_id('ios_main') }}                 as ios_main,
    {{ hnh_code('ios_user') }}               as ios_user,
    {{ hnh_code('ios_type') }}               as ios_type,
    {{ hnh_code('ios_category') }}           as ios_category,
    {{ hnh_id('service_dept') }}             as service_dept,
    {{ hnh_code('product_category_code') }}  as product_category_code,
    {{ hnh_id('generic_id') }}               as generic_id
from {{ hnh_oasis_source('ios_master_data') }} final
