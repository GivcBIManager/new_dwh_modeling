{{ config(order_by='er_priority_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'priority']) }}  as er_priority_key,
    branch_id                                           as branch_key,
    toNullable(priority)                                as priority,
    ifNull(description, 'Not named')                    as description,
    toUInt8OrNull(extract(ifNull(description, ''), '(?i)level\\s*([1-5])')) as ctas_level,
    colour                                              as colour,
    target_minutes                                      as target_minutes
from {{ ref('stg_oasis__er_priorities') }}

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', null, null, null
