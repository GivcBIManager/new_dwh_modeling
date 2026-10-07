{{ config(alias='dim_position', order_by='position_key') }}
select {{ hnh_surrogate_key(['position_id']) }} as position_key, toNullable(position_id) as position_id, position_code, position_name, is_current
from {{ ref('stg_fusion__positions') }}
union all
select toInt64(-1), null, null, 'Unknown', toUInt8(1)
