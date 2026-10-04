select
    toUInt8(branch_id)                       as branch_id,
    toInt64(doc_id)                          as doc_id,
    {{ hnh_str('doc_no') }}                  as doc_no,
    {{ hnh_code('doc_type') }}               as doc_type,
    {{ hnh_ksa_wall_clock('doc_date') }}     as doc_at,
    {{ hnh_code('account_code') }}           as account_code,
    {{ hnh_str('ext_ref') }}                 as ext_ref,
    {{ hnh_str('ext_acc_doc_no') }}          as ext_acc_doc_no,
    {{ hnh_id('alloc_doc_id') }}             as alloc_doc_id,
    toFloat64(ifNull(total_doc_price, 0))    as total_doc_price,
    toFloat64(ifNull(total_doc_disc, 0))     as total_doc_disc,
    toFloat64(ifNull(total_doc_tax, 0))      as total_doc_tax
from {{ hnh_oasis_source('doc') }} final
where doc_type in ('INVOICEAR', 'CREDITAR', 'DEBITAR', 'RECEIPT') and doc_status = 'P'
