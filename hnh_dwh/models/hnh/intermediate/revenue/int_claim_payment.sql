{{ config(order_by='(branch_id, response_id, detail_index)') }}

with reconciliations as (
    -- Only PaymentReconciliation resources are read.
    select
        branch_id, response_id,
        arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'PaymentReconciliation',
                              JSONExtractArrayRaw(response_bundle, 'entry'))) as entry
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type = 'payment-reconciliation'
),

details as (
    -- Payer dates may be ISO datetimes with an offset: the first 10 characters are the calendar date.
    select
        branch_id, response_id,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'paymentDate'), 1, 10))     as payment_date,
        JSONExtractFloat(entry, 'resource', 'paymentAmount', 'value')                            as payment_amount_total,
        nullIf(JSONExtractString(entry, 'resource', 'paymentIdentifier', 'value'), '')           as payment_reference,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'period', 'start'), 1, 10)) as period_start,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'period', 'end'), 1, 10))   as period_end,
        JSONExtractArrayRaw(entry, 'resource', 'detail')                                         as detail_list,
        arrayJoin(arrayEnumerate(detail_list))                                                   as detail_index
    from reconciliations
),

parsed as (
    select
        branch_id, response_id, payment_date, payment_amount_total, payment_reference, period_start, period_end,
        toUInt64(detail_index)                                                          as detail_index,
        detail_list[detail_index]                                                       as detail,
        arrayMap(e -> tuple(JSONExtractString(e, 'url'), JSONExtractFloat(e, 'valueMoney', 'value')),
                 JSONExtractArrayRaw(detail_list[detail_index], 'extension'))           as components
    from details
)

select
    branch_id,
    response_id,
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
