{{ config(order_by='(branch_key, ap_open_item_key)') }}

-- As-of-build snapshot: Fusion keeps only the current remaining amount of each invoice.
with items as (
    select
        sc.invoice_id as invoice_id, sc.vendor_id as vendor_id, sc.vendor_site_id as vendor_site_id, sc.invoice_num as invoice_num,
        sc.invoice_type_code as invoice_type_code, sc.approval_status as approval_status, sc.payment_status_flag as payment_status_flag,
        sc.is_on_hold as is_on_hold, sc.invoice_date as invoice_date, sc.cancelled_date as cancelled_date,
        sc.business_unit_id as business_unit_id, sc.due_date as due_date, sc.gross_amount as gross_amount,
        sc.amount_remaining as amount_remaining,
        toUInt8(sc.cancelled_date is not null)                                       as is_cancelled_f,
        if(sc.amount_remaining = 0 or sc.cancelled_date is not null or sc.due_date is null, toInt64(0),
           greatest(dateDiff('day', assumeNotNull(sc.due_date), today()), 0))        as days_overdue_f
    from {{ ref('stg_fusion__ap_payment_schedules') }} as sc
)

select
    {{ hnh_surrogate_key(['i.invoice_id']) }}                   as ap_open_item_key,
    ifNull(b.branch_key, toUInt8(0))                            as branch_key,
    ifNull(s.supplier_key, toInt64(-1))                         as supplier_key,
    {{ hnh_date_key_in_range('i.invoice_date') }}               as invoice_date_key,
    {{ hnh_date_key_in_range('i.due_date') }}                   as due_date_key,
    i.invoice_id                                                as invoice_id,
    i.invoice_num                                               as invoice_num,
    multiIf(i.invoice_type_code = 'STANDARD', 'Standard', i.invoice_type_code = 'CREDIT', 'Credit memo',
            i.invoice_type_code = 'PREPAYMENT', 'Prepayment', ifNull(i.invoice_type_code, 'Unknown')) as invoice_type,
    i.approval_status                                           as approval_status,
    multiIf(i.payment_status_flag = 'Y', 'Paid', i.payment_status_flag = 'P', 'Partially paid', 'Unpaid') as payment_status,
    i.is_on_hold                                                as is_on_hold,
    i.is_cancelled_f                                            as is_cancelled,
    if(i.amount_remaining = 0 or i.is_cancelled_f = 1, 'Settled',
       if(i.due_date is not null and i.due_date >= today(), 'Not due', {{ hnh_ageing_bucket('i.days_overdue_f') }})) as ageing_bucket,
    today()                                                     as snapshot_date,
    i.gross_amount                                              as gross_amount,
    i.amount_remaining                                          as amount_remaining,
    i.days_overdue_f                                            as days_overdue,
    now()                                                       as _loaded_at
from items as i
left join (select business_unit_id, primary_ledger_id from {{ ref('stg_fusion__business_units') }}) as bu
    on bu.business_unit_id = i.business_unit_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = bu.primary_ledger_id
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as s
    on s.supplier_key = {{ hnh_surrogate_key(['i.vendor_id', 'i.vendor_site_id']) }}
{{ hnh_settings() }}
