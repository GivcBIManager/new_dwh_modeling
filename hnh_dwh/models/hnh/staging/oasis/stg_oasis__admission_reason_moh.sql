select
    toUInt8(branch_id)           as branch_id,
    {{ hnh_str('reason') }}      as reason,
    {{ hnh_str('moh_code') }}    as moh_code
from {{ hnh_oasis_source('hnh_admission_reason_mapping') }} final
