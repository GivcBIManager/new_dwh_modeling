-- Bin transactions: store requisitions (REQ), transfers (TRF), purchase requisitions (PR) and others (spec F8).
-- Oasis purchase orders carry no reference to a PR, so these rows are not linked to fact_purchase_line.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(bintran_id)                     as bintran_id,
    {{ hnh_str('doc_no') }}                 as doc_no,
    extract(ifNull(doc_no, ''), '^[A-Za-z]+') as requisition_type,
    {{ hnh_code('status') }}                as status,
    {{ hnh_id('c_id') }}                    as store_id,
    {{ hnh_id('to_c_id') }}                 as to_store_id,
    {{ hnh_str('product_code') }}           as product_code,
    toFloat64(ifNull(qty, 0))               as quantity,
    toFloat64(ifNull(qty_received, 0))      as quantity_received,
    toDate32(tran_date)                     as transaction_date
from {{ hnh_oasis_source('bintran') }} final
