{{ config(order_by='(branch_key, accounting_date_key_nn, ap_invoice_line_key)') }}

select
    {{ hnh_surrogate_key(['d.invoice_distribution_id']) }}      as ap_invoice_line_key,
    ifNull(b.branch_key, toUInt8(0))                            as branch_key,
    ifNull(s.supplier_key, toInt64(-1))                         as supplier_key,
    ifNull(a.gl_account_key, toInt64(-1))                       as gl_account_key,
    {{ hnh_date_key_in_range('d.invoice_date') }}               as invoice_date_key,
    {{ hnh_date_key_in_range('d.accounting_date') }}            as accounting_date_key,
    ifNull({{ hnh_date_key_in_range('d.accounting_date') }}, 0) as accounting_date_key_nn,
    ifNull({{ hnh_gl_period_key_for_date('d.accounting_date') }}, toInt32(0)) as period_key,
    d.invoice_id                                                as invoice_id,
    d.invoice_num                                               as invoice_num,
    multiIf(d.invoice_type_code = 'STANDARD', 'Standard', d.invoice_type_code = 'CREDIT', 'Credit memo',
            d.invoice_type_code = 'PREPAYMENT', 'Prepayment', ifNull(d.invoice_type_code, 'Unknown')) as invoice_type,
    d.line_type                                                 as line_type,
    d.is_posted                                                 as is_posted,
    d.is_cancelled                                              as is_cancelled,
    d.is_reversal                                               as is_reversal,
    toUInt8(d.po_distribution_id is not null)                   as is_po_matched,
    d.amount                                                    as amount,
    if(ifNull(d.line_type, '') in ('ITEM', 'ACCRUAL', 'IPV', 'TRV', 'ERV', 'FREIGHT', 'MISCELLANEOUS'), d.amount, 0) as spend_amount,
    if(ifNull(d.line_type, '') in ('REC_TAX', 'NONREC_TAX'), d.amount, 0)                                         as tax_amount,
    if(ifNull(d.line_type, '') = 'PREPAY', d.amount, 0)                                                           as prepayment_amount,
    now()                                                       as _loaded_at
from {{ ref('stg_fusion__ap_invoice_distributions') }} as d
left join (select gl_account_key, code_combination_id from {{ ref('hnh_dim_gl_account') }} where code_combination_id is not null) as a
    on a.code_combination_id = d.code_combination_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = d.ledger_id
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as s
    on s.supplier_key = {{ hnh_surrogate_key(['d.vendor_id', 'd.vendor_site_id']) }}
{{ hnh_settings() }}
