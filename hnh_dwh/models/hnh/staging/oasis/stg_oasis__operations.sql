select
    toUInt8(branch_id)                              as branch_id,
    toInt64(operating_slot_code)                    as operating_slot_code,
    toInt64(operation_seq)                          as operation_seq,
    {{ hnh_id('ios_main') }}                        as ios_main,
    {{ hnh_id('operation_status') }}                as operation_status_code,
    {{ hnh_id('speciality_service_dept') }}         as service_dept,
    {{ hnh_code('operation_staff_id') }}            as surgeon_staff_id,
    {{ hnh_id('operation_type') }}                  as operation_type_code,
    {{ hnh_id('anesthesia_type') }}                 as anaesthesia_type_code,
    {{ hnh_code('anesthetist_staff_id') }}          as anaesthetist_staff_id,
    {{ hnh_ksa_wall_clock('operation_started') }}   as operation_started_at,
    {{ hnh_ksa_wall_clock('operation_end') }}       as operation_ended_at
from {{ hnh_oasis_source('operating_slot_details') }} final
