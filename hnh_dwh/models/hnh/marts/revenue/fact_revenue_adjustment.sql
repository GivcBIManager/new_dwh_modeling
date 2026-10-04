{{ config(order_by='(branch_key, adjustment_date_key, adjustment_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with credit_docs as (
    -- Post-invoice discount: a credit document numbered <charge invoice>D.
    select branch_id, doc_id, doc_no, doc_at, total_doc_price,
           substring(assumeNotNull(doc_no), 1, length(assumeNotNull(doc_no)) - 1) as base_doc_no
    from {{ ref('stg_oasis__ar_documents') }}
    where doc_type = 'CREDITAR' and endsWith(ifNull(doc_no, ''), 'D')
      and doc_at >= {{ first_at }} and toDate(doc_at) <= {{ last_day }}
),

invoice_docs as (
    select distinct branch_id, assumeNotNull(doc_no) as doc_no
    from {{ ref('stg_oasis__ar_documents') }}
    where doc_type = 'INVOICEAR' and doc_no is not null
),

base_lines as (
    select branch_key, invoice_doc_no, episode_key, patient_key, billed_payer_key, care_type_key,
           count() as n, sum(net_amount) as net
    from {{ ref('fact_charge_line') }}
    where charge_status = 'Live' and invoice_doc_no in (select base_doc_no from credit_docs)
    group by branch_key, invoice_doc_no, episode_key, patient_key, billed_payer_key, care_type_key
),

base_picked as (
    -- The most frequent key combination on the invoice (ties go to the lowest episode, patient, payer, care type keys).
    select
        branch_key, invoice_doc_no,
        argMax(tuple(episode_key, patient_key, billed_payer_key, care_type_key), tuple(n, -episode_key, -patient_key, -billed_payer_key, -care_type_key)) as keys,
        sum(net) as base_invoice_net_amount
    from base_lines
    group by branch_key, invoice_doc_no
),

base as (
    select
        branch_key, invoice_doc_no,
        tupleElement(keys, 1) as episode_key,
        tupleElement(keys, 2) as patient_key,
        tupleElement(keys, 3) as billed_payer_key,
        tupleElement(keys, 4) as care_type_key,
        base_invoice_net_amount
    from base_picked
)

select
    {{ hnh_surrogate_key(['c.branch_id', 'c.doc_id']) }}  as adjustment_key,
    c.branch_id                                          as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(c.doc_at)))         as adjustment_date_key,
    ifNull(b.episode_key, toInt64(-1))                   as episode_key,
    ifNull(b.patient_key, toInt64(-1))                   as patient_key,
    ifNull(b.billed_payer_key, toInt64(-1))              as billed_payer_key,
    toInt8(ifNull(b.care_type_key, -1))                  as care_type_key,
    c.doc_id                                             as doc_id,
    c.doc_no                                             as doc_no,
    c.base_doc_no                                        as base_doc_no,
    c.total_doc_price                                    as adjustment_amount,
    ifNull(b.base_invoice_net_amount, 0)                 as base_invoice_net_amount,
    now()                                                as _loaded_at
from credit_docs as c
inner join invoice_docs as i on i.branch_id = c.branch_id and i.doc_no = c.base_doc_no
left join base as b on b.branch_key = c.branch_id and b.invoice_doc_no = c.base_doc_no
{{ hnh_settings() }}
