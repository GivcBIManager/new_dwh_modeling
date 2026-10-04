{{ config(order_by='(branch_key, episode_key)') }}

with charges as (
    select branch_key, episode_key, any(patient_key) as patient_key, any(care_type_key) as care_type_key,
           sum(claimable_amount) as claimable_amount
    from {{ ref('fact_charge_line') }}
    where is_claimable = 1 and episode_key != -1
    group by branch_key, episode_key
),

invoices as (
    select branch_key, episode_key, any(patient_key) as patient_key, any(care_type_key) as care_type_key,
           sum(net_amount) as invoiced_net_amount, count() as invoice_count,
           min(invoice_date_key) as first_invoice_date_key, max(invoice_date_key) as last_invoice_date_key,
           countIf(startsWith(ifNull(account_code, ''), 'DIR-')) as contract_invoices
    from {{ ref('fact_invoice') }}
    where episode_key != -1
    group by branch_key, episode_key
),

both_sides as (
    select branch_key, episode_key, patient_key, care_type_key, claimable_amount as claimable_in,
           toFloat64(0) as invoiced_in, toUInt64(0) as invoices_in,
           cast(null as Nullable(Int32)) as first_invoice_date_key, cast(null as Nullable(Int32)) as last_invoice_date_key,
           toUInt64(0) as contract_invoices
    from charges
    union all
    select branch_key, episode_key, patient_key, care_type_key, toFloat64(0), invoiced_net_amount, invoice_count,
           toNullable(first_invoice_date_key), toNullable(last_invoice_date_key), contract_invoices
    from invoices
)

select
    branch_key,
    episode_key,
    any(patient_key)                                      as patient_key,
    any(care_type_key)                                    as care_type_key,
    sum(claimable_in)                                 as claimable_amount,
    sum(invoiced_in)                              as invoiced_net_amount,
    greatest(sum(claimable_in) - sum(invoiced_in), 0) as unbilled_amount,
    greatest(sum(invoiced_in) - sum(claimable_in), 0) as overbilled_amount,
    sum(invoices_in)                                    as invoice_count,
    min(first_invoice_date_key)                           as first_invoice_date_key,
    max(last_invoice_date_key)                            as last_invoice_date_key,
    toUInt8(sum(contract_invoices) > 0 and sum(invoices_in) > 12) as is_long_stay_contract,
    now()                                                 as _loaded_at
from both_sides
group by branch_key, episode_key
