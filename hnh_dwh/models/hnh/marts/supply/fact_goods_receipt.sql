{{ config(order_by='(branch_key, date_key, goods_receipt_key)') }}

-- One row per receipt line (spec 6.6): Fusion RECEIVE and RETURN TO VENDOR transactions from the branch's first Fusion
-- purchasing month, and Oasis GRN lines (STOCKRCPT source GRN, in scope as in int_oasis_stock_line) from the history
-- start; Oasis GRNs after the cutover receive Oasis POs of the overlap month. Oasis returns to supplier (STOCKISS RFN,
-- movement 'Return to supplier') are RETURN TO VENDOR rows like Fusion's; a return that references a GRN line belongs to
-- that GRN's PO line. Quantities in the item's primary unit, returns negative. Fusion store and lot come from the
-- receipt's delivery into inventory. is_po_receipt = the PO line is resolved in fact_purchase_line; is_supplier_receipt =
-- the receipt is from or to a supplier (every Oasis GRN / RFN row; Fusion rows that have a PO line, the rest being
-- internal receipts) and is what supplier KPIs filter on.
with cutover as (
    select branch_id, first_fusion_purchasing_month from {{ ref('stg_ref__scm_cutover') }}
),

deliveries as (
    select parent_transaction_id as deliver_parent_id, min(transaction_id) as deliver_id,
           anyIf(subinventory_code, subinventory_code is not null) as deliver_subinventory
    from {{ ref('stg_fusion__receipt_transactions') }}
    where transaction_type = 'DELIVER' and parent_transaction_id is not null
    group by parent_transaction_id
),

deliver_lots as (
    select assumeNotNull(rcv_transaction_id) as lot_rcv_transaction_id, min(lot_number) as delivered_lot, min(expiry_date) as delivered_expiry
    from {{ ref('int_fusion_stock_line') }}
    where rcv_transaction_id is not null
    group by rcv_transaction_id
),

fusion_receipts as (
    select
        {{ hnh_surrogate_key(["'fusion'", 'r.transaction_id']) }}              as goods_receipt_key,
        o.branch_key                                                            as branch_key,
        assumeNotNull(r.transaction_date)                                       as receipt_date,
        'fusion'                                                                as source_system,
        {{ hnh_surrogate_key(['r.vendor_id', 'r.vendor_site_id']) }}            as supplier_key_raw,
        {{ hnh_surrogate_key(['r.item_id']) }}                                  as item_key_raw,
        {{ hnh_fusion_store_key('r.organization_id', 'dv.deliver_subinventory') }} as store_key_raw,
        {{ hnh_surrogate_key(["'fusion'", 'r.po_line_location_id']) }}          as purchase_line_key_raw,
        r.transaction_type                                                      as receipt_type,
        if(r.transaction_type = 'RETURN TO VENDOR', -1, 1) * r.primary_quantity as quantity,
        r.po_unit_price                                                         as unit_price,
        if(r.primary_quantity != 0, if(r.transaction_type = 'RETURN TO VENDOR', -1, 1) * r.quantity * r.po_unit_price,
           if(r.transaction_type = 'RETURN TO VENDOR', -1, 1) * r.amount)       as received_value,
        toFloat64(0)                                                            as free_quantity,
        coalesce(dl.delivered_lot, r.vendor_lot_number)                         as lot_number,
        dl.delivered_expiry                                                     as expiry_date,
        cast(null as Nullable(Int64))                                           as oasis_line_id,
        toNullable(r.transaction_id)                                            as fusion_transaction_id,
        toUInt8(r.po_line_location_id is not null)                              as has_po_line
    from {{ ref('stg_fusion__receipt_transactions') }} as r
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = r.organization_id
    inner join cutover as k on k.branch_id = o.branch_key
    left join deliveries as dv on dv.deliver_parent_id = r.transaction_id
    left join deliver_lots as dl on dl.lot_rcv_transaction_id = dv.deliver_id
    where r.transaction_type in ('RECEIVE', 'RETURN TO VENDOR') and r.transaction_date is not null
      and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(r.transaction_date)) >= k.first_fusion_purchasing_month
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

oasis_grn_lines as (
    select branch_key as grn_branch_key, oasis_line_id as grn_line_id, cross_ref_line_id as grn_po_line_id
    from {{ ref('int_oasis_stock_line') }}
    where movement_type = 'Goods receipt'
),

oasis_receipts as (
    select
        {{ hnh_surrogate_key(["'oasis-line'", 'g.branch_key', 'g.oasis_line_id']) }} as goods_receipt_key,
        g.branch_key                                                            as branch_key,
        toDate(g.line_date)                                                     as receipt_date,
        'oasis'                                                                 as source_system,
        {{ hnh_surrogate_key(["'oasis'", 'g.branch_key', 'g.account_code']) }} as supplier_key_raw,
        g.item_key                                                              as item_key_raw,
        {{ hnh_surrogate_key(["'oasis'", 'g.branch_key', 'g.store_id']) }}     as store_key_raw,
        {{ hnh_surrogate_key(["'oasis'", 'g.branch_key',
            "if(g.movement_type = 'Return to supplier', coalesce(rg.grn_po_line_id, g.cross_ref_line_id), g.cross_ref_line_id)"]) }} as purchase_line_key_raw,
        if(g.movement_type = 'Return to supplier', 'RETURN TO VENDOR', 'GRN')   as receipt_type,
        g.primary_quantity                                                      as quantity,
        g.unit_cost                                                             as unit_price,
        g.cost_amount                                                           as received_value,
        g.bonus_quantity                                                        as free_quantity,
        g.lot_number                                                            as lot_number,
        g.expiry_date                                                           as expiry_date,
        toNullable(g.oasis_line_id)                                             as oasis_line_id,
        cast(null as Nullable(Int64))                                           as fusion_transaction_id,
        toUInt8(0)                                                              as has_po_line
    from {{ ref('int_oasis_stock_line') }} as g
    left join oasis_grn_lines as rg on rg.grn_branch_key = g.branch_key and rg.grn_line_id = g.cross_ref_line_id
    where g.movement_type in ('Goods receipt', 'Return to supplier')
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
),

receipts as (
    select * from fusion_receipts
    union all
    select * from oasis_receipts
)

select
    r.goods_receipt_key                                     as goods_receipt_key,
    r.branch_key                                            as branch_key,
    {{ hnh_date_key('r.receipt_date') }}                    as date_key,
    ifNull(sp.supplier_key, toInt64(-1))                    as supplier_key,
    ifNull(i.item_key, toInt64(-1))                         as item_key,
    ifNull(st.store_key, toInt64(-1))                       as store_key,
    ifNull(pl.purchase_line_key, toInt64(-1))               as purchase_line_key,
    r.source_system                                         as source_system,
    r.receipt_type                                          as receipt_type,
    r.quantity                                              as quantity,
    r.unit_price                                            as unit_price,
    r.received_value                                        as received_value,
    r.free_quantity                                         as free_quantity,
    toUInt8(r.free_quantity > 0)                            as is_free_of_charge,
    r.lot_number                                            as lot_number,
    r.expiry_date                                           as expiry_date,
    r.oasis_line_id                                         as oasis_line_id,
    r.fusion_transaction_id                                 as fusion_transaction_id,
    toUInt8(if(r.source_system = 'fusion', r.has_po_line = 1, pl.purchase_line_key is not null)) as is_po_receipt,
    toUInt8(r.source_system = 'oasis' or r.has_po_line = 1)  as is_supplier_receipt,
    now()                                                   as _loaded_at
from receipts as r
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as sp on sp.supplier_key = r.supplier_key_raw
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = r.item_key_raw
left join (select store_key from {{ ref('dim_store') }}) as st on st.store_key = r.store_key_raw
left join (select purchase_line_key from {{ ref('fact_purchase_line') }}) as pl on pl.purchase_line_key = r.purchase_line_key_raw
{{ hnh_settings() }}
