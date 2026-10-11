{{ config(order_by='employee_key') }}

-- Employee names for the SSAS Employee Details table: one row per employee of dim_employee (Unknown excluded), the
-- latest current Fusion name, and the employee's branch for the row filter (SSAS spec P37).
with names as (
    select person_id, full_name
    from {{ ref('stg_fusion__employee_names') }}
    order by person_id, valid_from desc
    limit 1 by person_id
)

select
    e.employee_key   as employee_key,
    e.branch_key     as branch_key,
    names.full_name  as full_name
from {{ ref('hnh_dim_employee') }} as e
left join names on names.person_id = e.person_id
where e.employee_key != -1
{{ hnh_settings() }}
