select
    toUInt8(branch_id)                          as branch_id,
    assumeNotNull({{ hnh_str('stat_invoice_no') }}) as stat_invoice_no,
    {{ hnh_ksa_wall_clock('stat_end_date') }}   as statement_end_at,
    {{ hnh_ksa_wall_clock('stat_send_date') }}  as statement_sent_at,
    {{ hnh_ksa_wall_clock('approved_date') }}   as approved_at,
    {{ hnh_str('approved_by') }}                as approved_by,
    {{ hnh_code('cancelled_flag') }}            as cancelled_flag,
    {{ hnh_code('statement_type') }}            as statement_type
from {{ hnh_oasis_source('ar_stat_of_invoices') }} final
