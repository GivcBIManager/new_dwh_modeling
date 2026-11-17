select
    toUInt8(branch_id)                          as branch_id,
    toInt64(signon_id)                          as signon_id,
    {{ hnh_code('staff_id') }}                  as staff_id
from {{ hnh_oasis_source('cashiers_signon') }} final
