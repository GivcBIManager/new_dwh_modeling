select
    transaction_id,
    parent_transaction_id,
    {{ hnh_code('transaction_type') }}      as transaction_type,
    {{ hnh_code('destination_type_code') }} as destination_type_code,
    po_line_location_id,
    po_distribution_id,
    organization_id,
    {{ hnh_code('subinventory') }}          as subinventory_code,
    vendor_id,
    vendor_site_id,
    item_id,
    {{ hnh_str('vendor_lot_num') }}         as vendor_lot_number,
    toDate(transaction_date)                as transaction_date,
    toFloat64(ifNull(quantity, 0))          as quantity,
    ifNull(toFloat64(primary_quantity), toFloat64(ifNull(quantity, 0))) as primary_quantity,
    toFloat64(ifNull(po_unit_price, 0))     as po_unit_price,
    toFloat64(ifNull(amount, 0))            as amount
from {{ hnh_fusion_source('fact_receipt_transaction') }} final
