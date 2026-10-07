{{ config(alias='dim_grade', order_by='grade_key') }}
select {{ hnh_surrogate_key(['grade_id']) }} as grade_key, toNullable(grade_id) as grade_id, grade_code, grade_name, is_current
from {{ ref('stg_fusion__grades') }}
union all
select toInt64(-1), null, null, 'Unknown', toUInt8(1)
