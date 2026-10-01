{{ config(order_by='(branch_id, work_entity)') }}

with we as (
    select * from {{ ref('stg_oasis__work_entities') }}
),

entity_types as (
    select branch_id, user_code as entity_type, any(description) as entity_type_name
    from {{ ref('int_code_decode') }}
    where code_type = 256 and user_code is not null
    group by branch_id, user_code
)

select
    we.branch_id                                           as branch_id,
    we.work_entity                                         as work_entity,
    ifNull(we.description, 'Not named')                    as department_name,
    we.short_name                                          as short_name,
    we.entity_type                                         as entity_type,
    ifNull(initcap(et.entity_type_name), 'Unknown')        as entity_type_name,
    {{ hnh_care_setting('we.entity_type') }}               as care_setting,
    we.service_dept                                        as service_dept,
    sd.description                                         as service_department_name,
    sd.dept_type                                           as service_department_type,
    ifNull(ud.unified_department, 'Not Mapped')            as unified_department,
    toUInt8(ifNull(ud.not_admitting, 0))                   as is_non_admitting_specialty,
    toUInt8(ifNull(ud.high_value, 0))                      as is_high_value_specialty,
    we.cost_centre_id                                      as cost_centre_id,
    cc.heading                                             as cost_centre_name,
    multiIf(ifNull(tw.tower, '') != '', tw.tower,
            we.branch_id = 1 and ifNull(we.entity_type, '') = 'W', 'NEW',
            'Main')                                        as tower,
    we.max_beds_in_ward                                    as max_beds_in_ward,
    toUInt8(multiSearchAny(upper(ifNull(we.description, '')), ['NURS', 'BOOKING', 'PRE OP'])) as is_excluded_ward,
    toUInt8(hc.work_entity is not null)                    as is_home_care,
    we.is_virtual_clinic                                   as is_virtual_clinic
from we
left join {{ ref('stg_oasis__service_departments') }} as sd
    on sd.branch_id = we.branch_id and sd.service_dept = we.service_dept
left join {{ ref('stg_ref__unified_department') }} as ud
    on ud.department = upper(sd.description)
left join {{ ref('stg_oasis__cost_centres') }} as cc
    on cc.branch_id = we.branch_id and cc.cost_centre_id = we.cost_centre_id
left join {{ ref('stg_ref__ward_tower') }} as tw
    on tw.branch_id = we.branch_id and tw.work_entity = we.work_entity
left join {{ ref('stg_ref__home_care_entity') }} as hc
    on hc.branch_id = we.branch_id and hc.work_entity = we.work_entity
left join entity_types as et
    on et.branch_id = we.branch_id and et.entity_type = we.entity_type
{{ hnh_settings() }}
