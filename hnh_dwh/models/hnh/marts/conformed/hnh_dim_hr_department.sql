{{ config(order_by='hr_department_key') }}

-- Department names are "<branch prefix> <specialty name>" (spec H6); the unified department reuses the Phase 3
-- specialty mapping by name.
with depts as (
    select organization_id, department_name,
           splitByChar(' ', ifNull(department_name, ''))[1]                         as branch_prefix,
           trimBoth(substring(ifNull(department_name, ''), length(splitByChar(' ', ifNull(department_name, ''))[1]) + 2)) as department_base_name
    from {{ ref('stg_fusion__hr_departments') }}
),

unified as (
    select lower(specialty_name) as name_lower, any(unified_department) as unified_dept
    from {{ ref('stg_ref__fusion_specialty_unified') }}
    where specialty_name is not null and unified_department is not null
    group by name_lower
),

departments as (
    select
        {{ hnh_surrogate_key(['d.organization_id']) }}      as hr_department_key,
        toNullable(d.organization_id)                       as organization_id,
        d.department_name                                   as department_name,
        d.branch_prefix                                     as branch_prefix,
        d.department_base_name                              as department_base_name,
        ifNull(u.unified_dept, 'Unknown')             as unified_department,
        {{ hnh_hr_dept_prefix_branch('d.branch_prefix') }}  as branch_key
    from depts as d
    left join unified as u on u.name_lower = lower(d.department_base_name)
    {{ hnh_settings() }}  -- left join in a CTE feeding a union: settings must sit here
)

select * from departments

union all

select toInt64(-1), null, 'Unknown', null, null, 'Unknown', toUInt8(0)
{{ hnh_settings() }}
