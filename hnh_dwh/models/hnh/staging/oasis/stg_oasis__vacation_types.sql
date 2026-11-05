select
    toUInt8(branch_id)                 as branch_id,
    toInt64(vacation_type_id)          as vacation_type_id,
    {{ hnh_str('description') }}       as vacation_type_name,
    toUInt8(upper(ifNull(description, '')) like '%ANNUAL%') as is_annual_leave
from {{ hnh_oasis_source('vacation_types') }} final
