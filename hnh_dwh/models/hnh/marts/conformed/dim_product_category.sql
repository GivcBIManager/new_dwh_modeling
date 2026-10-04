{{ config(order_by='product_category_key') }}

with codes as (
    select distinct branch_id, category_code from (
        select branch_id, category_code from {{ ref('stg_ref__product_category') }}
        union all
        select branch_id, assumeNotNull(product_category_code) from {{ ref('stg_oasis__ios_master') }}
        where product_category_code is not null
        union all
        select branch_id, assumeNotNull(product_category_code) from {{ ref('stg_oasis__service_items') }}
        where product_category_code is not null
    )
)

select * from (
select
    {{ hnh_surrogate_key(['c.branch_id', 'c.category_code']) }} as product_category_key,
    c.branch_id                                      as branch_key,
    toNullable(c.category_code)                      as category_code,
    ifNull(pc.group_name, 'Not Mapped')              as product_group,
    ifNull(pc.unified_category, 'Not Mapped')        as unified_category,
    ifNull(pc.department, 'Not Mapped')              as product_department,
    ifNull(pc.high_level_department, 'Not Mapped')   as high_level_department,
    {{ hnh_is_medication('c.category_code', "cast(null as Nullable(String))") }} as is_medication_category
from codes as c
left join {{ ref('stg_ref__product_category') }} as pc
    on pc.branch_id = c.branch_id and pc.category_code = c.category_code

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', 'Unknown', 'Unknown', toUInt8(0)
)
{{ hnh_settings() }}
