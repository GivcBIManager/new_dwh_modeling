select
    toUInt8(branch_id)                 as branch_id,
    toInt64(staff_contract_no)         as staff_contract_no,
    {{ hnh_code('staff_id') }}         as staff_id,
    toDate32(start_date)               as started_at,
    toDate32(end_date)                 as ended_at,
    toDate32(termination_date)         as terminated_at,
    {{ hnh_id('termination_reason_code') }} as termination_reason_code
from {{ source('oasis', 'staff_contracts') }} final
