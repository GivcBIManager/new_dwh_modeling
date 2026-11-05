{{ config(alias='dim_absence_type', order_by='absence_type_key') }}
select {{ hnh_surrogate_key(['absence_type_id']) }} as absence_type_key, toNullable(absence_type_id) as absence_type_id,
       absence_type_name, absence_plan_name, plan_type, {{ hnh_absence_category('absence_type_name') }} as absence_category,
       is_current
from {{ ref('stg_fusion__absence_types') }}
union all
-- Oasis vacation types, one per branch (their ids differ by branch), for the Oasis absences (2026-11-05).
select {{ hnh_surrogate_key(["'oasis'", 'branch_id', 'vacation_type_id']) }}, cast(null as Nullable(Int64)),
       {{ hnh_title('vacation_type_name') }}, cast(null as Nullable(String)), cast(null as Nullable(String)),
       {{ hnh_absence_category('vacation_type_name') }}, toUInt8(1)
from {{ ref('stg_oasis__vacation_types') }}
union all
select toInt64(-1), null, 'Unknown', null, null, 'Other', toUInt8(1)
