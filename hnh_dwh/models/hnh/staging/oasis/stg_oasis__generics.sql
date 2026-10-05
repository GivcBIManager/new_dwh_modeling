select
    toUInt8(branch_id)              as branch_id,
    toInt64(generic_id)             as generic_id,
    {{ hnh_str('generic_name') }}   as generic_name
from {{ hnh_oasis_source('generics') }} final
