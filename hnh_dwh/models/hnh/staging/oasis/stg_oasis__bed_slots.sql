select
    toUInt8(branch_id)                as branch_id,
    {{ hnh_code('bed_location') }}    as bed_location,
    {{ hnh_id('work_entity') }}       as work_entity,
    {{ hnh_id('room_no') }}           as room_no,
    {{ hnh_id('slot_status') }}       as slot_status
from {{ source('oasis', 'bed_slots_master') }} final
