select
    toUInt8(branch_id)              as branch_id,
    toInt64(room_no)                as room_no,
    {{ hnh_id('work_entity') }}     as work_entity,
    {{ hnh_str('description') }}    as description,
    {{ hnh_id('room_class') }}      as room_class,
    {{ hnh_code('room_sex') }}      as room_sex
from {{ source('oasis', 'room_master') }} final
