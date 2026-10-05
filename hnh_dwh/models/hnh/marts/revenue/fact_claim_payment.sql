{{ config(order_by='(branch_key, payment_date_key, claim_payment_key)') }}

{% set first_day = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with payments as (
    select * from {{ ref('int_claim_payment') }}
    where payment_date >= {{ first_day }} and payment_date <= {{ last_day }}
),

claims as (
    -- one claim visit per NPHIES transaction (latest visit when a transaction was reused)
    select
        branch_id, api_trans_id,
        tupleElement(latest_visit, 1) as visit_id,
        tupleElement(latest_visit, 2) as patient_id,
        tupleElement(latest_visit, 3) as episode_no,
        tupleElement(latest_visit, 4) as purchaser_code,
        tupleElement(latest_visit, 5) as claim_invoice_no,
        tupleElement(latest_visit, 6) as request_at,
        tupleElement(latest_visit, 7) as statement_end_at
    from (
        select
            branch_id, api_trans_id,
            argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id) as latest_visit
        from {{ ref('int_claim_submission') }}
        where api_trans_id is not null
        group by branch_id, api_trans_id
    )
)

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.reconciliation_id', 'p.detail_index']) }}              as claim_payment_key,
    p.branch_id                                                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(p.payment_date)))                                      as payment_date_key,
    {{ hnh_date_key_in_range('c.statement_end_at') }}                                       as statement_end_date_key,
    ifNull(dp.patient_key, toInt64(-1))                                                     as patient_key,
    {{ hnh_surrogate_key(['p.branch_id', 'c.patient_id', 'c.episode_no']) }}                as episode_key,
    ifNull(dpy.payer_key, toInt64(-1))                                                      as payer_key,
    {{ hnh_surrogate_key(['p.branch_id', 'c.claim_invoice_no']) }}                          as invoice_key,
    c.visit_id                                                                              as visit_id,
    p.claim_api_trans_id                                                                    as claim_api_trans_id,
    p.payer_claim_response_id                                                               as payer_claim_response_id,
    p.reconciliation_id                                                                     as reconciliation_id,
    p.detail_type                                                                           as detail_type,
    p.payment_reference                                                                     as payment_reference,
    p.period_start                                                                          as period_start,
    p.period_end                                                                            as period_end,
    p.amount                                                                                as payment_amount,
    p.payment_component                                                                     as payment_component,
    p.early_fee                                                                             as early_fee,
    p.nphies_fee                                                                            as nphies_fee,
    if(c.request_at is null, cast(null as Nullable(Int64)), dateDiff('day', toDate(c.request_at), assumeNotNull(p.payment_date))) as days_to_payment,
    now()                                                                                   as _loaded_at
from payments as p
left join claims as c on c.branch_id = p.branch_id and c.api_trans_id = p.claim_api_trans_id
left join (select patient_key from {{ ref('dim_patient') }}) as dp
    on dp.patient_key = {{ hnh_surrogate_key(['p.branch_id', 'c.patient_id']) }}
left join (select payer_key from {{ ref('dim_payer') }}) as dpy
    on dpy.payer_key = {{ hnh_surrogate_key(['p.branch_id', 'ifNull(c.purchaser_code, toInt64(9999))']) }}
{{ hnh_settings() }}
