{{ config(order_by='employee_key') }}

-- Employee names and personal details for the SSAS Employee Details table (visible only to users with pay access):
-- one row per employee of dim_employee (Unknown excluded), the latest current Fusion record, and the employee's branch
-- for the row filter (SSAS spec P37). Personal details added 2026-11-19 for the HR report's record lists (user
-- request): birth date, marital status, email, phone and national ID. Fusion holds the national ID for 2 people only,
-- so the Oasis staff record linked to the employee (dim_employee.staff_key) gives it otherwise (3,195 of 4,491 linked
-- employees, November 2026). Religion is not taken.
with names as (
    select person_id, full_name, birth_date, marital_status_code, email_address, phone_number, national_id
    from {{ ref('stg_fusion__employee_names') }}
    order by person_id, valid_from desc
    limit 1 by person_id
),

oasis as (
    select d.staff_key as staff_key, any(s.national_id) as national_id, any(s.birth_date) as birth_date
    from {{ ref('dim_staff') }} as d
    inner join (select branch_id, staff_id, nullIf(trimBoth(ifNull(national_id, '')), '') as national_id,
                       birth_date
                from {{ ref('stg_oasis__staff') }}) as s
        on s.branch_id = toUInt8(d.branch_key) and s.staff_id = d.staff_id
    where d.staff_id is not null
    group by d.staff_key
)

select
    e.employee_key                                                  as employee_key,
    e.branch_key                                                    as branch_key,
    {{ hnh_title('names.full_name') }}                              as full_name,
    toDate32(coalesce(names.birth_date, o.birth_date))              as birth_date,
    multiIf(names.marital_status_code = 'S', 'Single', names.marital_status_code = 'M', 'Married',
            names.marital_status_code = 'D', 'Divorced', names.marital_status_code = 'W', 'Widowed',
            names.marital_status_code)                              as marital_status,
    names.email_address                                             as email_address,
    names.phone_number                                              as phone_number,
    coalesce(names.national_id, o.national_id)                      as national_id
from {{ ref('hnh_dim_employee') }} as e
left join names on names.person_id = e.person_id
left join oasis as o on o.staff_key = e.staff_key
where e.employee_key != -1
{{ hnh_settings() }}
