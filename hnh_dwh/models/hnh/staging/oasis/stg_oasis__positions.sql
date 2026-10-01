select
    toUInt8(branch_id)             as branch_id,
    toInt64(position_type)         as position_type,
    {{ hnh_str('description') }}   as description
from {{ hnh_oasis_source('positions_data') }} final
