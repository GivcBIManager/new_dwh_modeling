select
    toUInt8(branch_id)                       as branch_id,
    toInt64(post_number)                     as post_number,
    {{ hnh_code('staff_id') }}               as staff_id,
    {{ hnh_id('work_entity') }}              as work_entity,
    {{ hnh_id('position_type') }}            as position_type,
    {{ hnh_ksa_wall_clock('date_started') }} as started_at,
    {{ hnh_ksa_wall_clock('date_ended') }}   as ended_at,
    {{ hnh_id('posts_id') }}                 as posts_id
from {{ source('oasis', 'staff_posts') }} final
