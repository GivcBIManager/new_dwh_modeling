select
    toUInt8(branch_id)                                  as branch_id,
    toInt64(invoice_no)                                 as invoice_no,
    {{ hnh_ksa_wall_clock('invoice_creation_date') }}   as created_at,
    {{ hnh_ksa_wall_clock('invoice_start_date') }}      as service_start_at,
    {{ hnh_ksa_wall_clock('invoice_end_date') }}        as service_end_at,
    {{ hnh_code('account_code') }}                      as account_code,
    {{ hnh_id('patient_id') }}                          as patient_id,
    {{ hnh_id('episode_no') }}                          as episode_no,
    {{ hnh_code('attendance_type') }}                   as attendance_type,
    toFloat64(ifNull(invoice_gross, 0))                 as gross_amount,
    toFloat64(ifNull(invoice_discount, 0))              as discount_amount,
    toFloat64(ifNull(invoice_net_amount, 0))            as net_amount,
    toFloat64(ifNull(invoice_vat, 0))                   as vat_amount,
    toFloat64(ifNull(invoice_total, 0))                 as total_amount,
    {{ hnh_str('stat_invoice_no') }}                    as stat_invoice_no,
    {{ hnh_code('approval_status') }}                   as approval_status_code,
    {{ hnh_str('claim_type') }}                         as claim_type
from {{ hnh_oasis_source('ar_episode_invoices') }} final
