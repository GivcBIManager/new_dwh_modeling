{{ config(order_by='movement_type_key') }}

-- Static movement types (spec 4.4, 5.3).
select
    {{ hnh_surrogate_key(['m']) }}          as movement_type_key,
    m                                       as movement_type,
    {{ hnh_movement_direction('m') }}       as direction,
    {{ hnh_is_consumption('m') }}           as is_consumption,
    toUInt8(s)                              as sort_order
from values('m String, s UInt8',
    ('Patient sale', 1), ('Patient return', 2), ('Department issue', 3), ('Transfer out', 4), ('Transfer in', 5),
    ('Goods receipt', 6), ('Return to supplier', 7), ('Count adjustment', 8), ('Write-off / misc', 9), ('Opening balance', 10))
