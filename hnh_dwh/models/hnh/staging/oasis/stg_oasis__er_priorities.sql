select
    toUInt8(branch_id)                 as branch_id,
    toInt64(priority)                  as priority,
    {{ hnh_str('description') }}       as description,
    {{ hnh_str('priority_color') }}    as colour,
    toInt32(target_time_mins)          as target_minutes
from {{ source('oasis', 'er_priorities') }} final
