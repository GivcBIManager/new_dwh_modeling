{{ config(order_by='service_key') }}

with services as (
    select
        m.branch_id      as branch_id,
        m.ios            as ios,
        m.ios_user       as ios_user,
        m.ios_type       as ios_type,
        m.ios_category   as ios_category,
        m.service_dept   as service_dept,
        m.ios_main       as ios_main,
        si.description   as service_name,
        coalesce(m.product_category_code, si.product_category_code) as product_category_code
    from {{ ref('stg_oasis__ios_master') }} as m
    left join {{ ref('stg_oasis__service_items') }} as si
        on si.branch_id = m.branch_id and si.ios_main = m.ios_main
)

select * from (
select
    {{ hnh_surrogate_key(['s.branch_id', 's.ios']) }} as service_key,
    s.branch_id                                       as branch_key,
    toNullable(s.ios)                                 as ios,
    s.ios_user                                        as ios_user,
    ifNull(s.service_name, 'Unknown')                 as service_name,
    s.ios_type                                        as ios_type,
    s.ios_category                                    as ios_category,
    s.service_dept                                    as service_dept,
    s.ios_main                                        as ios_main,
    s.product_category_code                           as product_category_code,
    ifNull(pc.group_name, 'Not Mapped')               as product_group,
    ifNull(pc.unified_category, 'Not Mapped')         as unified_category,
    ifNull(pc.department, 'Not Mapped')               as product_department,
    ifNull(pc.high_level_department, 'Not Mapped')    as high_level_department
from services as s
left join {{ ref('stg_ref__product_category') }} as pc
    on pc.branch_id = s.branch_id and pc.category_code = s.product_category_code

union all

select toInt64(-1), toUInt8(0), null, null, 'Unknown', null, null, null, null, null,
       'Unknown', 'Unknown', 'Unknown', 'Unknown'
)
{{ hnh_settings() }}
