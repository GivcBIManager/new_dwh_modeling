{{ config(order_by='outcome_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'code']) }}   as outcome_key,
    branch_id                                        as branch_key,
    toNullable(code)                                 as outcome_code,
    ifNull(initcap(description), 'Not named')        as outcome,
    {{ hnh_outcome_group('description_upper') }}     as outcome_group,
    toUInt8({{ hnh_outcome_group('description_upper') }} in ('Cancelled', 'Rescheduled')) as is_cancelled
from {{ ref('int_code_decode') }}
where code_type = 21

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', toUInt8(0)
