{{ config(order_by='(branch_key, month_start)') }}

with charges as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(delivery_date_key)))  as month_start,
        sum(revenue_amount)                                          as revenue,
        sumIf(gross_amount, is_recognised_revenue = 1)               as gross_charges,
        sumIf(line_discount_amount, is_recognised_revenue = 1)       as line_discount,
        sumIf(vat_amount, is_recognised_revenue = 1)                 as vat,
        sum(claimable_amount)                                        as claimable_revenue,
        sumIf(revenue_amount, is_patient_share = 1)                  as patient_share_revenue,
        sumIf(revenue_amount, is_cash_billed = 1)                    as cash_revenue,
        sumIf(revenue_amount, is_medication = 1)                     as medication_revenue,
        sum(package_content_amount)                                  as package_content,
        sumIf(net_amount, charge_status = 'Cancelled')               as cancelled_charges,
        sumIf(revenue_amount, care_type_key = 1)                     as op_revenue,
        sumIf(revenue_amount, care_type_key = 2)                     as er_revenue,
        sumIf(revenue_amount, care_type_key = 3)                     as ip_revenue,
        sumIf(revenue_amount, care_type_key = 4)                     as daycase_revenue,
        sumIf(revenue_amount, care_type_key = -1)                    as unknown_care_revenue,
        sum(legacy_revenue_amount)                                   as legacy_charge_revenue
    from {{ ref('fact_charge_line') }}
    group by branch_key, month_start
),

adjustments as (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(adjustment_date_key))) as month_start,
           sum(adjustment_amount) as adjustments
    from {{ ref('fact_revenue_adjustment') }}
    group by branch_key, month_start
),

legacy_discounts as (
    -- old vw_discounts: every AR document whose number ends in D, before the fan-out
    select branch_id as branch_key, toStartOfMonth(toDate(doc_at)) as month_start,
           sum(total_doc_price) as legacy_discount_documents
    from {{ ref('stg_oasis__ar_documents') }}
    where endsWith(ifNull(doc_no, ''), 'D')
      and doc_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
    group by branch_key, month_start
)

select
    -- Named explicitly: with two joins ClickHouse names c.* columns 'c.branch_key', which the sorting key cannot find.
    c.branch_key as branch_key,
    c.month_start as month_start,
    c.revenue as revenue,
    c.gross_charges as gross_charges,
    c.line_discount as line_discount,
    c.vat as vat,
    c.claimable_revenue as claimable_revenue,
    c.patient_share_revenue as patient_share_revenue,
    c.cash_revenue as cash_revenue,
    c.medication_revenue as medication_revenue,
    c.package_content as package_content,
    c.cancelled_charges as cancelled_charges,
    c.op_revenue as op_revenue,
    c.er_revenue as er_revenue,
    c.ip_revenue as ip_revenue,
    c.daycase_revenue as daycase_revenue,
    c.unknown_care_revenue as unknown_care_revenue,
    c.legacy_charge_revenue as legacy_charge_revenue,
    ifNull(a.adjustments, 0)                      as adjustments,
    c.revenue + ifNull(a.adjustments, 0)          as net_revenue_after_adjustments,
    ifNull(d.legacy_discount_documents, 0)        as legacy_discount_documents
from charges as c
left join adjustments as a on a.branch_key = c.branch_key and a.month_start = c.month_start
left join legacy_discounts as d on d.branch_key = c.branch_key and d.month_start = c.month_start
{{ hnh_settings() }}
