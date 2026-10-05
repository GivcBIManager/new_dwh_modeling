{{ config(order_by='(branch_id, reconciliation_id, detail_index)') }}

with pulls as (
    -- Only PaymentReconciliation resources are read. The same reconciliation is pulled many times
    -- (each pull is a new response_id) and is identified by its bundle entry fullUrl (resource id, then the response itself, as fallback).
    select
        branch_id, response_id, responded_at,
        coalesce(nullIf(JSONExtractString(entry, 'fullUrl'), ''), nullIf(JSONExtractString(entry, 'resource', 'id'), ''), concat('response:', toString(response_id))) as reconciliation_id
    from (
        select
            branch_id, response_id, responded_at,
            arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'PaymentReconciliation',
                                  JSONExtractArrayRaw(response_bundle, 'entry'))) as entry
        from {{ ref('stg_oasis__pull_responses') }}
        where response_type = 'payment-reconciliation'
    )
),

latest_pull as (
    -- The latest pull of each reconciliation (latest responded_at, then highest response_id) is the one kept.
    select
        branch_id, reconciliation_id,
        argMax(response_id, tuple(ifNull(responded_at, toDateTime(0)), response_id)) as response_id
    from pulls
    group by branch_id, reconciliation_id
),

reconciliations as (
    -- Only the responses that hold a kept pull are expanded.
    select
        branch_id, response_id,
        coalesce(nullIf(JSONExtractString(entry, 'fullUrl'), ''), nullIf(JSONExtractString(entry, 'resource', 'id'), ''), concat('response:', toString(response_id))) as reconciliation_id,
        entry
    from (
        select
            branch_id, response_id,
            arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'PaymentReconciliation',
                                  JSONExtractArrayRaw(response_bundle, 'entry'))) as entry
        from {{ ref('stg_oasis__pull_responses') }}
        where response_type = 'payment-reconciliation'
          and (branch_id, response_id) in (select branch_id, response_id from latest_pull)
    )
    where (branch_id, response_id, reconciliation_id) in (select branch_id, response_id, reconciliation_id from latest_pull)
),

details as (
    -- Payer dates may be ISO datetimes with an offset: the first 10 characters are the calendar date.
    select
        branch_id, response_id, reconciliation_id,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'paymentDate'), 1, 10))     as payment_date,
        JSONExtractFloat(entry, 'resource', 'paymentAmount', 'value')                            as payment_amount_total,
        nullIf(JSONExtractString(entry, 'resource', 'paymentIdentifier', 'value'), '')           as payment_reference,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'period', 'start'), 1, 10)) as period_start,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'period', 'end'), 1, 10))   as period_end,
        -- Each detail is extracted once; no detail row carries the whole list.
        arrayJoin(arrayZip(arrayEnumerate(JSONExtractArrayRaw(entry, 'resource', 'detail')),
                           JSONExtractArrayRaw(entry, 'resource', 'detail')))                    as indexed_detail
    from reconciliations
),

parsed as (
    select
        branch_id, response_id, reconciliation_id, payment_date, payment_amount_total, payment_reference, period_start, period_end,
        toUInt64(tupleElement(indexed_detail, 1))                                       as detail_index,
        tupleElement(indexed_detail, 2)                                                 as detail,
        arrayMap(e -> tuple(JSONExtractString(e, 'url'), JSONExtractFloat(e, 'valueMoney', 'value')),
                 JSONExtractArrayRaw(detail, 'extension'))                              as components
    from details
)

select
    branch_id,
    response_id,
    reconciliation_id,
    detail_index,
    nullIf(JSONExtractString(detail, 'identifier', 'value'), '')                       as detail_identifier,
    toInt64OrNull(JSONExtractString(detail, 'request', 'identifier', 'value'))          as claim_api_trans_id,
    nullIf(JSONExtractString(detail, 'response', 'identifier', 'value'), '')           as payer_claim_response_id,
    JSONExtractString(detail, 'type', 'coding', 1, 'code')                              as detail_type,
    toDateOrNull(substring(JSONExtractString(detail, 'date'), 1, 10))                   as detail_date,
    JSONExtractFloat(detail, 'amount', 'value')                                         as amount,
    arraySum(arrayMap(c -> if(position(tupleElement(c, 1), 'component-payment') > 0, tupleElement(c, 2), 0), components))   as payment_component,
    arraySum(arrayMap(c -> if(position(tupleElement(c, 1), 'early-fee') > 0, tupleElement(c, 2), 0), components))           as early_fee,
    arraySum(arrayMap(c -> if(position(tupleElement(c, 1), 'nphies-fee') > 0, tupleElement(c, 2), 0), components))          as nphies_fee,
    payment_date,
    payment_amount_total,
    period_start,
    period_end,
    payment_reference
from parsed
