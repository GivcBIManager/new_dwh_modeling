{{ config(order_by='(branch_id, reconciliation_id, detail_index)') }}

{#- A reconciliation is identified by its content, not by its fullUrl or resource id: some payers re-issue a new
    fullUrl/id on every pull of the same payment, and others reuse one id for different payments or for the pages
    of one payment. With a payment identifier: identifier, payment date and amount. Without one: payment date,
    amount and a hash of the sorted detail claim identifiers and amounts. One pull holds one PaymentReconciliation. -#}
{%- set reconciliation_identity -%}
if(JSONExtractString(entry, 'resource', 'paymentIdentifier', 'value') != '',
   concat('pid:', JSONExtractString(entry, 'resource', 'paymentIdentifier', 'value'),
          '|', substring(JSONExtractString(entry, 'resource', 'paymentDate'), 1, 10),
          '|', toString(JSONExtractFloat(entry, 'resource', 'paymentAmount', 'value'))),
   concat('hash:', substring(JSONExtractString(entry, 'resource', 'paymentDate'), 1, 10),
          '|', toString(JSONExtractFloat(entry, 'resource', 'paymentAmount', 'value')),
          '|', toString(cityHash64(arraySort(arrayMap(d -> concat(JSONExtractString(d, 'request', 'identifier', 'value'), ':',
                                                                  toString(JSONExtractFloat(d, 'amount', 'value'))),
                                                      JSONExtractArrayRaw(entry, 'resource', 'detail')))))))
{%- endset -%}

{%- set reconciliation_entry -%}
arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'PaymentReconciliation',
                      JSONExtractArrayRaw(response_bundle, 'entry')))
{%- endset -%}

with pull_entries as (
    select branch_id, response_id, responded_at, {{ reconciliation_entry }} as entry
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type = 'payment-reconciliation'
),

kept_pulls as (
    -- One pass over every pull: its reconciliation identity, then the latest pull of each identity
    -- (latest responded_at, then highest response_id) is the one kept.
    select branch_id, argMax(response_id, tuple(ifNull(responded_at, toDateTime(0, 'Asia/Riyadh')), response_id)) as response_id
    from (
        select branch_id, response_id, responded_at, {{ reconciliation_identity }} as reconciliation_id
        from pull_entries
    )
    group by branch_id, reconciliation_id
),

details as (
    -- Only the kept pulls are expanded. Payer dates may be ISO datetimes with an offset: the first 10 characters
    -- are the calendar date.
    select
        branch_id, response_id,
        {{ reconciliation_identity }}                                                            as reconciliation_id,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'paymentDate'), 1, 10))     as payment_date,
        JSONExtractFloat(entry, 'resource', 'paymentAmount', 'value')                            as payment_amount_total,
        nullIf(JSONExtractString(entry, 'resource', 'paymentIdentifier', 'value'), '')           as payment_reference,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'period', 'start'), 1, 10)) as period_start,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'period', 'end'), 1, 10))   as period_end,
        -- Each detail is extracted once; no detail row carries the whole list.
        arrayJoin(arrayZip(arrayEnumerate(JSONExtractArrayRaw(entry, 'resource', 'detail')),
                           JSONExtractArrayRaw(entry, 'resource', 'detail')))                    as indexed_detail
    from (
        select branch_id, response_id, {{ reconciliation_entry }} as entry
        from {{ ref('stg_oasis__pull_responses') }}
        where response_type = 'payment-reconciliation'
          and (branch_id, response_id) in (select branch_id, response_id from kept_pulls)
    )
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
