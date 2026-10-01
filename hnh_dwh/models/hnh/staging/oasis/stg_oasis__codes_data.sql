select
    toUInt8(branch_id)              as branch_id,
    toInt64(code)                   as code,
    toInt32(code_type)              as code_type,
    {{ hnh_str('description') }}    as description,
    {{ hnh_str('description_a') }}  as description_ar,
    {{ hnh_str('user_code') }}      as user_code,
    toInt32(prog_code)              as prog_code
from {{ hnh_oasis_source('codes_data') }} final
