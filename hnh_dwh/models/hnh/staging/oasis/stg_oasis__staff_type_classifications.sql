select
    toUInt8(branch_id)               as branch_id,
    toInt64(staff_type)              as staff_type,
    {{ hnh_str('type_desc') }}       as type_desc,
    {{ hnh_str('classificaton') }}   as classification,
    {{ hnh_str('categorynew') }}     as category,
    {{ hnh_str('med_nonmed') }}      as med_nonmed
from {{ hnh_oasis_source('staff_type_classification') }} final
