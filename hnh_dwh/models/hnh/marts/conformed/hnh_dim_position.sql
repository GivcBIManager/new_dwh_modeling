{{ config(alias='dim_position', order_by='position_key') }}
-- position_base_name: the name without its hospital prefix ("RBW Staff Nurse" -> "Staff Nurse"), so a position groups
-- across hospitals, as hnh_dim_hr_department.department_base_name does for departments (ruling R30). A name whose first
-- word is not a prefix hnh_hr_dept_prefix_branch knows (Head Office titles such as "Medical Director") is kept whole.
select {{ hnh_surrogate_key(['position_id']) }} as position_key, toNullable(position_id) as position_id, position_code, position_name,
       if({{ hnh_hr_dept_prefix_branch("splitByChar(' ', ifNull(position_name, ''))[1]") }} = 0, position_name,
          trimBoth(substring(ifNull(position_name, ''), length(splitByChar(' ', ifNull(position_name, ''))[1]) + 2))) as position_base_name,
       is_current
from {{ ref('stg_fusion__positions') }}
union all
select toInt64(-1), null, null, 'Unknown', 'Unknown', toUInt8(1)
