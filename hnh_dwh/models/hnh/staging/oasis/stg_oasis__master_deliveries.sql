select
    toUInt8(branch_id)                    as branch_id,
    toInt64(master_delivery_no)           as master_delivery_no,
    {{ hnh_id('delivery_work_entity') }}  as work_entity
from {{ hnh_oasis_source('master_deliveries') }} final
