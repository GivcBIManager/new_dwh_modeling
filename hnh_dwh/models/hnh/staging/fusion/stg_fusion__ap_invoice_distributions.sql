select
    invoice_distribution_id,
    invoice_id,
    {{ hnh_str('invoice_num') }}                as invoice_num,
    {{ hnh_code('line_type_lookup_code') }}     as line_type,
    po_distribution_id,
    rcv_transaction_id,
    {{ hnh_flag('posted_flag') }}               as is_posted,
    {{ hnh_flag('cancellation_flag') }}         as is_cancelled,
    {{ hnh_flag('reversal_flag') }}             as is_reversal,
    {{ hnh_code('invoice_type_lookup_code') }}  as invoice_type_code,
    vendor_id,
    vendor_site_id,
    ledger_id,
    code_combination_id,
    toDate(invoice_date)                        as invoice_date,
    toDate(accounting_date)                     as accounting_date,
    toFloat64(ifNull(accounted_amount, 0))      as amount
from {{ hnh_fusion_source('fact_ap_invoice_distribution') }} final
