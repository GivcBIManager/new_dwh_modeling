select
    invoice_id,
    payment_num,
    vendor_id,
    vendor_site_id,
    {{ hnh_str('invoice_num') }}                as invoice_num,
    {{ hnh_code('invoice_type_lookup_code') }}  as invoice_type_code,
    {{ hnh_code('invoice_approval_status') }}   as approval_status,
    {{ hnh_code('payment_status_flag') }}       as payment_status_flag,
    {{ hnh_flag('hold_flag') }}                 as is_on_hold,
    toDate(invoice_date)                        as invoice_date,
    toDate(cancelled_date)                      as cancelled_date,
    business_unit_id,
    toDate(due_date)                            as due_date,
    {{ hnh_code('invoice_currency_code') }}     as currency_code,
    toFloat64(ifNull(entered_gross_amount, 0))      as gross_amount,
    toFloat64(ifNull(entered_amount_remaining, 0))  as amount_remaining
from {{ hnh_fusion_source('fact_ap_payment_schedule') }} final
