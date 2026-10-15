{{ config(alias='dim_location', order_by='location_key') }}
select {{ hnh_surrogate_key(['location_id']) }} as location_key, toNullable(location_id) as location_id, location_code,
       {{ hnh_title('location_name') }} as location_name, {{ hnh_title('town_or_city') }} as town_or_city, is_current
from {{ ref('stg_fusion__locations') }}
union all
select toInt64(-1), null, null, 'Unknown', null, toUInt8(1)
