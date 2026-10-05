{{ config(order_by='nphies_reason_key') }}

select {{ hnh_surrogate_key(['reason_code']) }} as nphies_reason_key,
       toNullable(reason_code)                as reason_code,
       reason                                 as reason,
       reason_category                        as reason_category
from {{ ref('stg_ref__nphies_reason') }}

union all
select toInt64(-1), null, 'Unknown code', 'Unknown'

union all
select toInt64(0), null, 'Not given', 'Not given'
