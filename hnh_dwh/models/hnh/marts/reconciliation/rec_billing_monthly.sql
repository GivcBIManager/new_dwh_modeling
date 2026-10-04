{{ config(order_by='(branch_key, month_start, care_type_key)') }}

select branch_key, month_start, care_type_key,
       sum(claimable_charges)      as claimable_charges,
       sum(invoiced_net)           as invoiced_net,
       sum(verified_invoiced_net)  as verified_invoiced_net,
       sum(long_stay_overbilled)   as long_stay_overbilled
from (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(delivery_date_key))) as month_start, care_type_key,
           sum(claimable_amount) as claimable_charges, toFloat64(0) as invoiced_net,
           toFloat64(0) as verified_invoiced_net, toFloat64(0) as long_stay_overbilled
    from {{ ref('fact_charge_line') }}
    where is_claimable = 1
    group by branch_key, month_start, care_type_key

    union all

    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(invoice_date_key))), care_type_key,
           toFloat64(0), sum(net_amount), sumIf(net_amount, is_verified = 1), toFloat64(0)
    from {{ ref('fact_invoice') }}
    group by branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(invoice_date_key))), care_type_key

    union all

    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(last_invoice_date_key)))), care_type_key,
           toFloat64(0), toFloat64(0), toFloat64(0), sum(overbilled_amount)
    from {{ ref('agg_episode_billing') }}
    where is_long_stay_contract = 1 and last_invoice_date_key is not null
    group by branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(last_invoice_date_key)))), care_type_key
)
group by branch_key, month_start, care_type_key
