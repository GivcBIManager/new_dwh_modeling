{{ config(order_by='discharge_outcome_key') }}

select
    {{ hnh_surrogate_key(['branch_id', 'code']) }}            as discharge_outcome_key,
    branch_id                                                 as branch_key,
    toNullable(code)                                          as outcome_code,
    ifNull(initcap(description), 'Not named')                 as outcome,
    {{ hnh_discharge_outcome_group('description_upper') }}    as outcome_group,
    moh_code                                                  as moh_code
from {{ ref('int_code_decode') }}
where code_type = 10

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', null
