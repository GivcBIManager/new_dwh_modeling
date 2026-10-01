{{ config(order_by='bed_key') }}

with from_details as (
    -- Latest known ward, class and gender for every bed location that ever held a row.
    select
        branch_id, bed_location,
        argMax(work_entity, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), bed_detail_id)) as work_entity,
        argMax(bed_class, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), bed_detail_id))   as bed_class,
        argMax(bed_sex, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), bed_detail_id))     as bed_sex
    from {{ ref('stg_oasis__bed_details') }}
    where bed_location is not null
    group by branch_id, bed_location
),

locations as (
    select branch_id, bed_location from from_details
    union distinct
    select branch_id, bed_location from {{ ref('stg_oasis__bed_slots') }} where bed_location is not null
)

select * from (

select
    {{ hnh_surrogate_key(['l.branch_id', 'l.bed_location']) }} as bed_key,
    l.branch_id                                                as branch_key,
    toNullable(l.bed_location)                                 as bed_location,
    ifNull(dep.department_key_value, toInt64(-1))              as current_department_key,
    dep.department_name                                        as current_ward,
    bc.description                                             as bed_class,
    multiIf(fd.bed_sex = 'M', 'Male', fd.bed_sex = 'F', 'Female', 'Any') as bed_gender,
    ifNull(cls.classification, 'Not Mapped')                   as classification,
    toUInt8(ifNull(cls.classification, '') = 'Critical')       as is_critical,
    st.description_upper                                       as current_slot_status,
    toUInt8(s.bed_location is not null
            and ifNull(st.description_upper, '') not in ('NO BED IN SLOT', 'NOT AVAILABLE')) as is_currently_available
from locations as l
left join from_details as fd on fd.branch_id = l.branch_id and fd.bed_location = l.bed_location
left join {{ ref('stg_oasis__bed_slots') }} as s on s.branch_id = l.branch_id and s.bed_location = l.bed_location
left join (
    select branch_id, work_entity, department_name,
           {{ hnh_surrogate_key(['branch_id', 'work_entity']) }} as department_key_value
    from {{ ref('int_department_conformed') }}
) as dep
    on dep.branch_id = l.branch_id and dep.work_entity = coalesce(s.work_entity, fd.work_entity)
left join {{ ref('stg_oasis__bed_classes') }} as bc on bc.branch_id = l.branch_id and bc.bed_class = fd.bed_class
left join {{ ref('stg_ref__bed_classification') }} as cls on cls.branch_id = l.branch_id and upper(cls.bed_location) = l.bed_location
left join {{ ref('int_code_decode') }} as st on st.branch_id = l.branch_id and st.code = s.slot_status

union all

select toInt64(-1), toUInt8(0), null, toInt64(-1), null, null, 'Any', 'Unknown', toUInt8(0), null, toUInt8(0)

)
{{ hnh_settings() }}
