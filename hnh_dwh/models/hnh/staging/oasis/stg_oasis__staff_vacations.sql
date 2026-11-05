select
    toUInt8(branch_id)                 as branch_id,
    toInt64(staff_vacation_id)         as staff_vacation_id,
    {{ hnh_code('staff_id') }}         as staff_id,
    {{ hnh_id('staff_contract_no') }}  as staff_contract_no,
    {{ hnh_id('vacation_type_id') }}   as vacation_type_id,
    toDate32(from_date)                as from_date,
    toFloat64(ifNull(days, 0))         as days,
    {{ hnh_code('status') }}           as status
from {{ hnh_oasis_source('staff_vacations') }} final
