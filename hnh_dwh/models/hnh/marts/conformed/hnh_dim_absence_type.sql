{{ config(alias='dim_absence_type', order_by='absence_type_key') }}
select {{ hnh_surrogate_key(['absence_type_id']) }} as absence_type_key, toNullable(absence_type_id) as absence_type_id,
       absence_type_name, absence_plan_name, plan_type, {{ hnh_absence_category('absence_type_name') }} as absence_category
from {{ ref('stg_fusion__absence_types') }}
union all
select toInt64(-1), null, 'Unknown', null, null, 'Other'
