select
    toUInt8(branch_id)                        as branch_id,
    {{ hnh_code('staff_id') }}                as staff_id,
    {{ hnh_code('department') }}              as department,
    {{ hnh_ksa_wall_clock('creation_date') }} as created_at
from {{ source('oasis', 'hnh_internal_doctor_list') }} final
