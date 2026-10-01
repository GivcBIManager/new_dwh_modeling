select
    toUInt8(branch_id)                         as branch_id,
    toInt64(bed_detail_id)                     as bed_detail_id,
    {{ hnh_code('current_record') }}           as is_current,
    {{ hnh_id('work_entity') }}                as work_entity,
    {{ hnh_id('room_no') }}                    as room_no,
    {{ hnh_code('bed_location') }}             as bed_location,
    {{ hnh_id('bed_status') }}                 as bed_status,
    {{ hnh_id('bed_class') }}                  as bed_class,
    {{ hnh_ksa_wall_clock('start_date') }}     as started_at,
    {{ hnh_ksa_wall_clock('end_date') }}       as ended_at,
    {{ hnh_id('patient_id') }}                 as patient_id,
    {{ hnh_id('admission_no') }}               as admission_no,
    {{ hnh_id('episode_no') }}                 as episode_no,
    {{ hnh_code('bed_sex') }}                  as bed_sex,
    {{ hnh_id('trans_from_work_entity') }}     as transferred_from_work_entity
from {{ source('oasis', 'bed_details') }} final
