select
    toUInt8(branch_id)                          as branch_id,
    toInt64(master_order_no)                    as master_order_no,
    {{ hnh_id('patient_id') }}                  as patient_id,
    {{ hnh_id('episode_no') }}                  as episode_no,
    {{ hnh_id('admission_no') }}                as admission_no,
    {{ hnh_code('orderer_staff_id') }}          as orderer_staff_id,
    {{ hnh_ksa_wall_clock('order_date') }}      as ordered_at,
    {{ hnh_code('status') }}                    as order_status,
    {{ hnh_code('attendance_type') }}           as attendance_type,
    {{ hnh_id('service_dept') }}                as service_dept,
    recorded_updated_at                         as updated_at
from {{ hnh_oasis_source('orders_master') }} final
