select
    toUInt8(branch_id)                          as branch_id,
    toInt64(ios_main)                           as ios_main,
    {{ hnh_str('description') }}                as description,
    {{ hnh_code('product_code') }}              as product_code,
    {{ hnh_code('product_category_code') }}     as product_category_code
from {{ hnh_oasis_source('ios_main_data') }} final
