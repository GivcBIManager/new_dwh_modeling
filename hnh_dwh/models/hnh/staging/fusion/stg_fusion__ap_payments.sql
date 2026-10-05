select
    invoice_payment_id,
    invoice_id,
    payment_num,
    check_number,
    {{ hnh_code('payment_method_code') }}       as payment_method,
    {{ hnh_code('payment_status') }}            as payment_status,
    {{ hnh_flag('posted_flag') }}               as is_posted,
    vendor_id,
    vendor_site_id,
    ledger_id,
    bank_account_id,
    toDate(accounting_date)                     as payment_date,
    toFloat64(ifNull(accounted_amount, 0))      as amount
from {{ hnh_fusion_source('fact_ap_payment') }} final
