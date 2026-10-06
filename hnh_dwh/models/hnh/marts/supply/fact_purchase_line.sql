{{ config(order_by='(branch_key, po_date_key, purchase_line_key)') }}

-- One row per Fusion PO schedule (line location) from the branch's first Fusion purchasing month, and per Oasis PO line
-- (PORDER, source PO) up to and including that month, or always for a branch without one (spec 6.5, S1): the first
-- Fusion month is the overlap month and keeps both systems' POs, because they are different documents. Quantities are in each system's ordering unit (uom_code: Oasis base
-- unit, Fusion PO unit). Lead time = PO date to first receipt. AP match = Fusion AP lines on the schedule's PO
-- distributions, with Phase 3's spend definition. Oasis POs carry no requisition, billing or AP link.
-- Oasis receipts are the GRN lines in fact_goods_receipt's scope: the 'Goods receipt' lines of int_oasis_stock_line
-- (posted, not reversed, not cancelled or superseded), so the GRN predicate lives in one place.
{% set first_day = "toDate32('" ~ var('hnh_history_start_date') ~ "')" %}

with cutover as (
    select branch_id, first_fusion_purchasing_month from {{ ref('stg_ref__scm_cutover') }}
),

fusion_schedules as (
    select s.line_location_id as line_location_id, s.po_number as po_number, s.vendor_id as vendor_id,
           s.vendor_site_id as vendor_site_id, s.ship_to_organization_id as ship_to_organization_id, s.item_id as item_id,
           s.uom_code as uom_code, s.document_status as document_status, s.line_type_id as line_type_id,
           s.is_cancelled as is_cancelled, assumeNotNull(s.po_creation_date) as po_date, s.quantity as quantity,
           s.quantity_received as quantity_received, s.quantity_billed as quantity_billed,
           s.quantity_cancelled as quantity_cancelled, s.unit_price as unit_price, s.amount as amount,
           s.amount_received as amount_received, o.branch_key as branch_key
    from {{ ref('stg_fusion__po_schedules') }} as s
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = s.ship_to_organization_id
    inner join cutover as k on k.branch_id = o.branch_key
    where s.po_creation_date is not null and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(s.po_creation_date)) >= k.first_fusion_purchasing_month
),

requisitions as (
    select d.line_location_id as req_line_location_id, argMin(r.requisition_number, d.po_distribution_id) as req_number,
           argMin(r.approved_date, d.po_distribution_id) as req_approved_date
    from {{ ref('stg_fusion__po_distributions') }} as d
    inner join {{ ref('stg_fusion__requisition_distributions') }} as r on r.distribution_id = d.req_distribution_id
    where d.line_location_id is not null
    group by d.line_location_id
),

receipts as (
    select po_line_location_id as rcv_line_location_id, min(transaction_date) as first_receipt_date
    from {{ ref('stg_fusion__receipt_transactions') }}
    where transaction_type = 'RECEIVE' and po_line_location_id is not null
    group by po_line_location_id
),

ap_match as (
    select d.line_location_id as ap_line_location_id, sum(a.spend_amount) as matched_amount
    from {{ ref('fact_ap_invoice_line') }} as a
    inner join {{ ref('stg_fusion__po_distributions') }} as d on d.po_distribution_id = a.po_distribution_id
    where a.po_distribution_id is not null and d.line_location_id is not null
    group by d.line_location_id
),

fusion_lines as (
    select
        {{ hnh_surrogate_key(["'fusion'", 's.line_location_id']) }}            as purchase_line_key,
        s.branch_key                                                            as branch_key,
        'fusion'                                                                as source_system,
        s.po_date                                                               as po_date,
        {{ hnh_surrogate_key(['s.vendor_id', 's.vendor_site_id']) }}            as supplier_key_raw,
        {{ hnh_surrogate_key(['s.item_id']) }}                                  as item_key_raw,
        {{ hnh_fusion_store_key('s.ship_to_organization_id', 'cast(null as Nullable(String))') }} as ship_to_store_key_raw,
        s.po_number                                                             as po_number,
        toNullable(s.line_location_id)                                          as fusion_line_location_id,
        cast(null as Nullable(Int64))                                           as oasis_line_id,
        q.req_number                                                            as requisition_number,
        q.req_approved_date                                                     as requisition_approved_date,
        s.uom_code                                                              as uom_code,
        s.quantity                                                              as quantity_ordered,
        s.quantity_received                                                     as quantity_received,
        s.quantity_cancelled                                                    as quantity_cancelled,
        s.quantity_billed                                                       as quantity_billed,
        s.unit_price                                                            as unit_price,
        if(s.quantity > 0, s.quantity * s.unit_price, s.amount)                 as ordered_value,
        if(s.quantity > 0, s.quantity_received * s.unit_price, s.amount_received) as received_value,
        r.first_receipt_date                                                    as first_receipt_date,
        ifNull(s.document_status, 'UNKNOWN')                                    as po_status,
        multiIf(lt.line_type_name = 'Goods', 'Goods', ifNull(lt.line_type_name, '') like '%Services%', 'Services',
                ifNull(lt.line_type_name, 'Unknown'))                           as line_type,
        toUInt8(m.ap_line_location_id is not null)                              as is_ap_matched,
        ifNull(m.matched_amount, 0)                                             as ap_matched_amount
    from fusion_schedules as s
    left join requisitions as q on q.req_line_location_id = s.line_location_id
    left join receipts as r on r.rcv_line_location_id = s.line_location_id
    left join ap_match as m on m.ap_line_location_id = s.line_location_id
    left join {{ ref('stg_fusion__po_line_types') }} as lt on lt.line_type_id = s.line_type_id
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

oasis_docs as (
    select branch_id, doc_id, doc_no, account_code, doc_status
    from {{ ref('stg_oasis__stock_documents') }}
    where doc_type = 'PORDER' and source_code = 'PO'
),

oasis_receipts as (
    -- GRN lines per PO line in fact_goods_receipt's scope, in Oasis base units (the line's own quantity)
    select l.branch_id as grn_branch_id, assumeNotNull(l.cross_ref_line_id) as grn_po_line_id,
           sum(l.quantity) as grn_quantity, min(l.line_date) as grn_first_date
    from {{ ref('stg_oasis__stock_document_lines') }} as l
    inner join (select branch_key, oasis_line_id from {{ ref('int_oasis_stock_line') }}
                where movement_type = 'Goods receipt') as g
        on g.branch_key = l.branch_id and g.oasis_line_id = l.line_id
    where l.doc_type = 'STOCKRCPT' and l.cross_ref_line_id is not null
    group by l.branch_id, l.cross_ref_line_id
),

oasis_lines as (
    select
        {{ hnh_surrogate_key(["'oasis'", 'l.branch_id', 'l.line_id']) }}       as purchase_line_key,
        l.branch_id                                                             as branch_key,
        'oasis'                                                                 as source_system,
        toDate(assumeNotNull(l.line_date))                                      as po_date,
        {{ hnh_surrogate_key(["'oasis'", 'l.branch_id', 'd.account_code']) }}  as supplier_key_raw,
        {{ hnh_stock_item_key('x.inventory_item_id', 'l.branch_id', 'l.product_code') }} as item_key_raw,
        {{ hnh_surrogate_key(["'oasis'", 'l.branch_id', 'l.store_id']) }}      as ship_to_store_key_raw,
        d.doc_no                                                                as po_number,
        cast(null as Nullable(Int64))                                           as fusion_line_location_id,
        toNullable(l.line_id)                                                   as oasis_line_id,
        cast(null as Nullable(String))                                          as requisition_number,
        cast(null as Nullable(Date32))                                          as requisition_approved_date,
        l.uom_code                                                              as uom_code,
        l.qty_ordered                                                           as quantity_ordered,
        ifNull(g.grn_quantity, 0)                                               as quantity_received,
        if(ifNull(l.line_status, '') = 'C', greatest(l.qty_ordered - ifNull(g.grn_quantity, 0), 0), 0) as quantity_cancelled,
        toFloat64(0)                                                            as quantity_billed,
        l.list_unit_price * (1 - l.list_discount_pct / 100) * (1 - l.discount_pct / 100) as unit_price,
        l.qty_ordered * unit_price                                              as ordered_value,
        ifNull(g.grn_quantity, 0) * unit_price                                  as received_value,
        if(g.grn_first_date is null, cast(null as Nullable(Date)), toDate(g.grn_first_date)) as first_receipt_date,
        {{ hnh_oasis_po_status('d.doc_status', 'l.line_status') }}              as po_status,
        'Goods'                                                                 as line_type,
        toUInt8(0)                                                              as is_ap_matched,
        toFloat64(0)                                                            as ap_matched_amount
    from {{ ref('stg_oasis__stock_document_lines') }} as l
    inner join oasis_docs as d on d.branch_id = l.branch_id and d.doc_id = l.doc_id
    left join cutover as k on k.branch_id = l.branch_id
    left join oasis_receipts as g on g.grn_branch_id = l.branch_id and g.grn_po_line_id = l.line_id
    left join {{ ref('int_item_crosswalk') }} as x on x.branch_key = l.branch_id and x.product_code = l.product_code
    where l.doc_type = 'PORDER' and l.line_date >= {{ first_day }} and l.line_date <= toDate32(today())
      and (k.first_fusion_purchasing_month is null or toInt32(toYYYYMM(l.line_date)) <= k.first_fusion_purchasing_month)
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

lines as (
    select * from fusion_lines
    union all
    select * from oasis_lines
)

select
    l.purchase_line_key                                         as purchase_line_key,
    l.branch_key                                                as branch_key,
    {{ hnh_date_key('l.po_date') }}                             as po_date_key,
    ifNull(sp.supplier_key, toInt64(-1))                        as supplier_key,
    ifNull(i.item_key, toInt64(-1))                             as item_key,
    ifNull(st.store_key, toInt64(-1))                           as ship_to_store_key,
    l.source_system                                             as source_system,
    l.po_number                                                 as po_number,
    l.fusion_line_location_id                                   as fusion_line_location_id,
    l.oasis_line_id                                             as oasis_line_id,
    l.requisition_number                                        as requisition_number,
    {{ hnh_date_key_in_range('l.requisition_approved_date') }}  as requisition_approved_date_key,
    l.uom_code                                                  as uom_code,
    l.quantity_ordered                                          as quantity_ordered,
    l.quantity_received                                         as quantity_received,
    l.quantity_cancelled                                        as quantity_cancelled,
    l.quantity_billed                                           as quantity_billed,
    l.unit_price                                                as unit_price,
    l.ordered_value                                             as ordered_value,
    l.received_value                                            as received_value,
    {{ hnh_date_key_in_range('l.first_receipt_date') }}         as first_receipt_date_key,
    if(l.first_receipt_date is null, cast(null as Nullable(Int32)),
       toInt32(dateDiff('day', l.po_date, assumeNotNull(l.first_receipt_date)))) as lead_time_days,
    l.po_status                                                 as po_status,
    l.line_type                                                 as line_type,
    l.is_ap_matched                                             as is_ap_matched,
    l.ap_matched_amount                                         as ap_matched_amount,
    now()                                                       as _loaded_at
from lines as l
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as sp on sp.supplier_key = l.supplier_key_raw
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = l.item_key_raw
left join (select store_key from {{ ref('dim_store') }}) as st on st.store_key = l.ship_to_store_key_raw
{{ hnh_settings() }}
