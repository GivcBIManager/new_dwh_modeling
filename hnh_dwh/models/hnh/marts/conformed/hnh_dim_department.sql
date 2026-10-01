{{ config(alias='dim_department', order_by='department_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'work_entity']) }} as department_key,
    branch_id                    as branch_key,
    toNullable(work_entity)      as work_entity,
    department_name              as department_name,
    short_name                   as short_name,
    entity_type                  as entity_type,
    entity_type_name             as entity_type_name,
    care_setting                 as care_setting,
    service_dept                 as service_dept,
    service_department_name      as service_department_name,
    service_department_type      as service_department_type,
    unified_department           as unified_department,
    is_non_admitting_specialty   as is_non_admitting_specialty,
    is_high_value_specialty      as is_high_value_specialty,
    cost_centre_id               as cost_centre_id,
    cost_centre_name             as cost_centre_name,
    tower                        as tower,
    max_beds_in_ward             as max_beds_in_ward,
    is_excluded_ward             as is_excluded_ward,
    is_home_care                 as is_home_care,
    is_virtual_clinic            as is_virtual_clinic
from {{ ref('int_department_conformed') }}

union all

select
    toInt64(-1), toUInt8(0), null, 'Unknown', null, null, 'Unknown', 'Unknown', null, null, null,
    'Unknown', toUInt8(0), toUInt8(0), null, null, 'Main', null, toUInt8(0), toUInt8(0), toUInt8(0)
