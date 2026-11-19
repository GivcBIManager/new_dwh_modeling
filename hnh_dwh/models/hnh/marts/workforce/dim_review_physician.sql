{{ config(order_by='staff_key') }}

-- Physician contract review (spec docs/superpowers/specs/2026-11-19-physician-contract-review-design.md, "Population"):
-- one row per dim_staff row. A separate model, not dim_staff columns, because bridge_employee_staff refs dim_staff.
-- The HR attributes come from the one employee linked to the staff row; a row linked to no employee, or to two
-- (3 staff records are shared by 2 employees each: their pay would add up on one row), reads 'Not linked'.
with linked as (
    select b.staff_key as staff_key, any(b.employee_key) as employee_key
    from {{ ref('bridge_employee_staff') }} as b
    group by b.staff_key
    having count() = 1
),

employee as (
    select l.staff_key as staff_key, l.employee_key as employee_key, e.job_key as job_key, e.grade_key as grade_key,
           e.is_part_time as is_part_time, e.hire_date as hire_date
    from linked as l
    inner join {{ ref('hnh_dim_employee') }} as e on e.employee_key = l.employee_key
),

-- The English staff name as tokens (hnh_name_tokens), for comparing a home row with another hospital's row.
staff as (
    select d.staff_key as staff_key, d.branch_key as branch_key, d.staff_id as staff_id, d.category as category,
           d.national_id_hash as national_id_hash, {{ hnh_name_tokens('d.staff_name') }} as name_tokens
    from {{ ref('dim_staff') }} as d
    where d.staff_id is not null
),

-- Review physician (home row): an Oasis doctor linked to one employee, not contingent, whose Fusion job is a physician
-- job (the rule of agg_staff_productivity_monthly's linked staff, doctors only).
physician as (
    select s.staff_key as staff_key, s.branch_key as branch_key, s.staff_id as staff_id, s.national_id_hash as national_id_hash,
           s.name_tokens as name_tokens
    from staff as s
    inner join employee as e on e.staff_key = s.staff_key
    inner join {{ ref('hnh_dim_job') }} as j on j.job_key = e.job_key
    where ifNull(s.category, '') = 'DOCTORS'
      and e.employee_key not in ({{ hnh_contingent_employee_keys() }})
      and lower(trimBoth(ifNull(j.job_name, ''))) in
          ('consultant', 'senior registrar doctor', 'registrar doctor', 'specialist', 'general physician', 'resident doctor')
),

-- The same person in another hospital (ruling R2): the same staff id in another branch, not linked to HR itself, and
-- the national id equal when both rows have one, else the names agree (hnh_name_tokens_agree). A row that matches two
-- home rows is attached to neither.
attached as (
    select o.staff_key as staff_key, if(uniqExact(p.staff_key) = 1, any(p.staff_key), toInt64(-1)) as home_staff_key
    from staff as o
    inner join physician as p on p.staff_id = o.staff_id
    where o.branch_key != p.branch_key
      and o.staff_key not in (select staff_key from {{ ref('bridge_employee_staff') }})
      and if(o.national_id_hash is not null and p.national_id_hash is not null,
             o.national_id_hash = p.national_id_hash,
             {{ hnh_name_tokens_agree('o.name_tokens', 'p.name_tokens') }})
    group by o.staff_key
)

select
    s.staff_key                                                                      as staff_key,
    toUInt8(p.staff_key is not null)                                                 as is_review_physician,
    if(e.staff_key is null, 'Not linked', ifNull({{ hnh_title('j.job_name') }}, 'Unknown')) as job_title,
    if(e.staff_key is null, 'Not linked', ifNull(g.grade_name, 'Unknown'))           as pay_grade,
    multiIf(e.staff_key is null, 'Not linked', e.is_part_time = 1, 'Part-time', 'Full-time') as employment_type,
    if(e.staff_key is null, cast(null as Nullable(Date)), cast(e.hire_date as Nullable(Date))) as hire_date,
    if(p.staff_key is not null, s.staff_key, ifNull(a.home_staff_key, toInt64(-1)))   as review_physician_key,
    now()                                                                            as _loaded_at
from {{ ref('dim_staff') }} as s
left join employee as e on e.staff_key = s.staff_key
left join {{ ref('hnh_dim_job') }} as j on j.job_key = e.job_key
left join {{ ref('hnh_dim_grade') }} as g on g.grade_key = e.grade_key
left join physician as p on p.staff_key = s.staff_key
left join attached as a on a.staff_key = s.staff_key
{{ hnh_settings() }}
