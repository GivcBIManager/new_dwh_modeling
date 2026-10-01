select
    toUInt8(branch_id)                        as branch_id,
    toInt64(staff_type)                       as staff_type,
    {{ hnh_str('staff_type_description') }}   as description,
    {{ hnh_flag('consultant') }}              as is_consultant
from {{ source('oasis', 'staff_types_data') }} final
