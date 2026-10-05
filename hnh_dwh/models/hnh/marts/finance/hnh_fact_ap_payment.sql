{{ config(alias='fact_ap_payment', order_by='(branch_key, payment_date_key_nn, ap_payment_key)') }}

select
    {{ hnh_surrogate_key(['p.invoice_payment_id']) }}           as ap_payment_key,
    p.invoice_payment_id                                        as invoice_payment_id,
    ifNull(b.branch_key, toUInt8(0))                            as branch_key,
    ifNull(s.supplier_key, toInt64(-1))                         as supplier_key,
    {{ hnh_date_key_in_range('p.payment_date') }}               as payment_date_key,
    ifNull({{ hnh_date_key_in_range('p.payment_date') }}, 0)    as payment_date_key_nn,
    p.bank_account_id                                           as bank_account_id,
    p.invoice_id                                                as invoice_id,
    p.payment_num                                               as payment_num,
    p.check_number                                              as check_number,
    p.payment_method                                            as payment_method,
    p.payment_status                                            as payment_status,
    toUInt8(ifNull(p.payment_status, '') = 'VOIDED')            as is_voided,
    p.is_posted                                                 as is_posted,
    p.amount                                                    as amount,
    if(sc.invoice_date is null or p.payment_date is null, cast(null as Nullable(Int64)),
       dateDiff('day', assumeNotNull(sc.invoice_date), assumeNotNull(p.payment_date)))  as days_invoice_to_payment,
    if(sc.due_date is null or p.payment_date is null, cast(null as Nullable(Int64)),
       dateDiff('day', assumeNotNull(sc.due_date), assumeNotNull(p.payment_date)))      as days_after_due,
    now()                                                       as _loaded_at
from {{ ref('stg_fusion__ap_payments') }} as p
left join (select invoice_id, invoice_date, due_date from {{ ref('stg_fusion__ap_payment_schedules') }}) as sc on sc.invoice_id = p.invoice_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = p.ledger_id
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as s
    on s.supplier_key = {{ hnh_surrogate_key(['p.vendor_id', 'p.vendor_site_id']) }}
{{ hnh_settings() }}
