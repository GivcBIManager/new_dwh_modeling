select
    toUInt8(branch_id)                          as branch_id,
    toInt64(order_line)                         as order_line,
    {{ hnh_id('master_order_no') }}             as master_order_no,
    {{ hnh_id('ios') }}                         as ios,
    {{ hnh_id('generic_id') }}                  as generic_id,
    toFloat64(ifNull(units_ordered, 0))         as units_ordered,
    toFloat64(ifNull(units_given, 0))           as units_given,
    toFloat64(ifNull(units_scheduled, 0))       as units_scheduled,
    toFloat64(ifNull(units_completed, 0))       as units_completed,
    {{ hnh_code('status') }}                    as line_status_code,
    {{ hnh_str('status_reason') }}              as status_reason,
    {{ hnh_id('original_order_line') }}         as original_order_line,
    {{ hnh_code('urgent_flag') }}               as urgent_flag,
    {{ hnh_id('order_work_entity') }}           as order_work_entity,
    {{ hnh_ksa_wall_clock('line_order_date') }} as line_ordered_at,
    toFloat64(ifNull(std_price, 0))             as std_price,
    recorded_updated_at                         as updated_at
from {{ hnh_oasis_source('order_lines') }} final
