{{ config(order_by='service_department_key') }}

-- One row per Oasis service department (branch + service_dept) for the charge line's service department, plus the
-- Unknown row (key -1). The type is the raw dept_type, as in hnh_dim_department.

select * from (

select
    {{ hnh_surrogate_key(['s.branch_id', 's.service_dept']) }} as service_department_key,
    s.branch_id                                              as branch_key,
    toNullable(s.service_dept)                               as service_dept,
    ifNull({{ hnh_title('s.description') }}, 'Not named')    as service_department_name,
    s.dept_type                                              as service_department_type,
    s.short_code                                             as short_code
from {{ ref('stg_oasis__service_departments') }} as s

union all

select toInt64(-1), toUInt8(0), cast(null as Nullable(Int64)), 'Unknown', cast(null as Nullable(String)), cast(null as Nullable(String))

)
{{ hnh_settings() }}
