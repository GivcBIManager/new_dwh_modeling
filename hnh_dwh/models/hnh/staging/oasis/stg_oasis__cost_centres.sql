select
    toUInt8(branch_id)             as branch_id,
    toInt64(c_id)                  as cost_centre_id,
    {{ hnh_str('heading') }}       as heading,
    {{ hnh_str('description') }}   as description
from {{ hnh_oasis_source('control_contexts_data') }} final
