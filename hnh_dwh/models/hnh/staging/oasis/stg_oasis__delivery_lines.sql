select
    toUInt8(branch_id)                  as branch_id,
    toInt64(delivery_line)              as delivery_line,
    {{ hnh_id('master_delivery_no') }}  as master_delivery_no,
    {{ hnh_id('order_line') }}          as order_line
from {{ hnh_oasis_source('delivery_lines') }} final
