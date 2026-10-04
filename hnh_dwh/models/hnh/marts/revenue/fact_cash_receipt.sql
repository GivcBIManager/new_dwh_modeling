{{ config(order_by='(branch_key, receipt_date_key, receipt_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with receipts as (
    -- Patient receipts only: account CASHACC or no account. Insurer, contract and other-account
    -- receipts are Phase 3 (Fusion AR); warn_excluded_receipt_accounts lists them.
    select branch_id, doc_id, doc_no, doc_at, total_doc_price,
           toInt64OrNull(ext_ref)        as patient_id,
           toInt64OrNull(ext_acc_doc_no) as episode_no
    from {{ ref('stg_oasis__ar_documents') }}
    where doc_type = 'RECEIPT' and doc_at >= {{ first_at }} and toDate(doc_at) <= {{ last_day }}
      and ifNull(account_code, 'CASHACC') = 'CASHACC'
)

select
    {{ hnh_surrogate_key(['r.branch_id', 'r.doc_id']) }}                    as receipt_key,
    r.branch_id                                                            as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(r.doc_at)))                           as receipt_date_key,
    {{ hnh_time_key('r.doc_at') }}                                         as receipt_time_key,
    ifNull(dp.patient_key, toInt64(-1))                                    as patient_key,
    {{ hnh_surrogate_key(['r.branch_id', 'r.patient_id', 'r.episode_no']) }} as episode_key,
    r.doc_id                                                               as doc_id,
    r.doc_no                                                               as doc_no,
    multiIf(startsWith(ifNull(r.doc_no, ''), 'CSH'), 'Cashier',
            startsWith(ifNull(r.doc_no, ''), 'RCT'), 'AR cash receipt', 'Other') as receipt_type,
    -r.total_doc_price                                                     as receipt_amount,
    toUInt8(-r.total_doc_price < 0)                                        as is_reversal,
    now()                                                                  as _loaded_at
from receipts as r
left join (select patient_key from {{ ref('dim_patient') }}) as dp
    on dp.patient_key = {{ hnh_surrogate_key(['r.branch_id', 'r.patient_id']) }}
{{ hnh_settings() }}
