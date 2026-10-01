select
    toUInt8(branch_id)             as branch_id,
    toInt64(document_id)           as document_id,
    {{ hnh_code('staff_id') }}     as staff_id,
    {{ hnh_id('doc_type') }}       as doc_type,
    {{ hnh_str('doc_number') }}    as doc_number,
    toDate32(date_from)            as valid_from
from {{ hnh_oasis_source('personnel_documents') }} final
