{{ config(order_by='(branch_key, month_start)') }}

-- Per branch and month (spec 8): received value against PO-matched AP spend, with non-PO AP spend; ordered value by
-- PO month. AP months are accounting months; spend follows Phase 3 (spend_amount). Received value includes returns to
-- supplier (negative).
with ordered as (
    select branch_key, toStartOfMonth(toDate(toString(po_date_key))) as month_start,
           sumIf(ordered_value, source_system = 'oasis') as oasis_ordered_value,
           sumIf(ordered_value, source_system = 'fusion') as fusion_ordered_value
    from {{ ref('fact_purchase_line') }}
    group by branch_key, month_start
),

received as (
    select branch_key, toStartOfMonth(toDate(toString(date_key))) as month_start,
           sumIf(received_value, source_system = 'oasis') as oasis_received_value,
           sumIf(received_value, source_system = 'fusion') as fusion_received_value
    from {{ ref('fact_goods_receipt') }}
    group by branch_key, month_start
),

ap as (
    -- accounting_date_key is Nullable; the month is a sort-key column, so it is taken from the non-null value
    select branch_key, toStartOfMonth(toDate(toString(assumeNotNull(accounting_date_key)))) as month_start,
           sumIf(spend_amount, po_distribution_id is not null) as ap_po_matched_spend,
           sumIf(spend_amount, po_distribution_id is null) as ap_non_po_spend
    from {{ ref('fact_ap_invoice_line') }}
    where accounting_date_key is not null
    group by branch_key, month_start
),

spine as (
    select branch_key, month_start from ordered
    union distinct select branch_key, month_start from received
    union distinct select branch_key, month_start from ap
)

select
    s.branch_key                                        as branch_key,
    s.month_start                                       as month_start,
    ifNull(o.oasis_ordered_value, 0)                    as oasis_ordered_value,
    ifNull(o.fusion_ordered_value, 0)                   as fusion_ordered_value,
    ifNull(r.oasis_received_value, 0)                   as oasis_received_value,
    ifNull(r.fusion_received_value, 0)                  as fusion_received_value,
    ifNull(a.ap_po_matched_spend, 0)                    as ap_po_matched_spend,
    ifNull(a.ap_non_po_spend, 0)                        as ap_non_po_spend,
    ifNull(r.fusion_received_value, 0) - ifNull(a.ap_po_matched_spend, 0) as fusion_received_not_matched
from spine as s
left join ordered as o on o.branch_key = s.branch_key and o.month_start = s.month_start
left join received as r on r.branch_key = s.branch_key and r.month_start = s.month_start
left join ap as a on a.branch_key = s.branch_key and a.month_start = s.month_start
{{ hnh_settings() }}
