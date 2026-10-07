-- Oasis document lines of the stock, purchasing and patient-invoice types, and credit notes so that Fusion references
-- to them resolve (spec F8). quantity is in the product's base unit: qty_change, or qty_shipped on invoice lines that
-- carry no qty_change; unit_cost and list_unit_price are per base unit.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(line_id)                        as line_id,
    toInt64(ifNull(doc_id, 0))              as doc_id,
    {{ hnh_code('doc_type') }}              as doc_type,
    {{ hnh_str('doc_no') }}                 as doc_no,
    toDate32(doc_date)                      as line_date,
    {{ hnh_id('c_id') }}                    as store_id,
    {{ hnh_str('product_code') }}           as product_code,
    toFloat64(if(ifNull(qty_change, 0) != 0, ifNull(qty_change, 0), ifNull(qty_shipped, 0))) as quantity,
    toFloat64(ifNull(qty_ordered, 0))       as qty_ordered,
    toFloat64(ifNull(conv_factor, 0))       as conv_factor,
    toFloat64(ifNull(unit_cost, 0))         as unit_cost,
    toFloat64(ifNull(total_cost, 0))        as total_cost,
    toFloat64(ifNull(exp_fob_cost, 0))      as list_unit_price,
    toFloat64(ifNull(list_discount, 0))     as list_discount_pct,
    toFloat64(ifNull(disc_1, 0))            as discount_pct,
    toFloat64(ifNull(vat_value, 0))         as vat_value,
    toFloat64(ifNull(bonus_order, 0))       as bonus_quantity,
    {{ hnh_code('line_status') }}           as line_status,
    {{ hnh_id('cross_ref_line_id') }}       as cross_ref_line_id,
    {{ hnh_str('lot_no') }}                 as lot_number,
    {{ hnh_str('serial_no_1') }}            as batch_number,
    toDate32(adj_date)                      as expiry_date,
    {{ hnh_code('uom_code') }}              as uom_code
from {{ hnh_oasis_source('docl') }} final
where doc_type in ('INVOICEAR', 'CREDITAR', 'STOCKISS', 'STOCKRCPT', 'PORDER')
