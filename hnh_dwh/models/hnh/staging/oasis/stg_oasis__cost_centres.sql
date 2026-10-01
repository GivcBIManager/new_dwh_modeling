select
    toUInt8(branch_id)             as branch_id,
    toInt64(c_id)                  as cost_centre_id,
    {{ hnh_str('heading') }}       as heading,
    {{ hnh_str('description') }}   as description
from {{ source('oasis', 'control_contexts_data') }} final
