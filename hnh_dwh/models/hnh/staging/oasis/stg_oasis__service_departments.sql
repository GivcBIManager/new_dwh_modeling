select
    toUInt8(branch_id)                 as branch_id,
    toInt64(service_dept)              as service_dept,
    {{ hnh_str('description') }}       as description,
    {{ hnh_code('dept_type') }}        as dept_type,
    {{ hnh_str('dept_short_code') }}   as short_code
from {{ hnh_oasis_source('service_dept_data') }} final
