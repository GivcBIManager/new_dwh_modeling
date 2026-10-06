-- Oasis document headers of the stock, purchasing and patient-invoice types (spec F8). pod is the counterparty store of a
-- transfer (and the ordering store on a GRN); 0 becomes null.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(doc_id)                         as doc_id,
    {{ hnh_code('doc_type') }}              as doc_type,
    {{ hnh_code('doc_ind') }}               as doc_ind,
    {{ hnh_code('source_code') }}           as source_code,
    {{ hnh_str('doc_no') }}                 as doc_no,
    {{ hnh_code('doc_status') }}            as doc_status,
    {{ hnh_code('gl_stk') }}                as gl_stk,
    {{ hnh_code('order_type') }}            as order_type,
    {{ hnh_id('c_id') }}                    as store_id,
    {{ hnh_id('pod') }}                     as pod,
    {{ hnh_code('account_code') }}          as account_code,
    toDate32(doc_date)                      as doc_date
from {{ hnh_oasis_source('doc') }} final
where doc_type in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT', 'PORDER')
