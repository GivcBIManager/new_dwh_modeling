select
    toUInt8(branch_id)                       as branch_id,
    toInt64(work_entity)                     as work_entity,
    {{ hnh_str('description') }}             as description,
    {{ hnh_str('short_name') }}              as short_name,
    {{ hnh_code('entity_type') }}            as entity_type,
    {{ hnh_id('clinic_service_dept') }}      as service_dept,
    {{ hnh_id('part_of_work_entity') }}      as parent_work_entity,
    toInt64OrNull(trimBoth(ifNull(gl_section_code, ''))) as cost_centre_id,
    toInt32(max_beds_in_ward)                as max_beds_in_ward,
    {{ hnh_flag('virtual_clinic') }}         as is_virtual_clinic,
    {{ hnh_flag('private_flag') }}           as is_private,
    {{ hnh_flag('vip_flag') }}               as is_vip
from {{ source('oasis', 'work_entities_data') }} final
