select
    toUInt8(BRANCH_ID)                as branch_id,
    toInt64(TERMINATION_REASON_CODE)  as termination_reason_code,
    any(trimBoth(UNIFIED_REASON))     as unified_reason
from {{ source('reference', 'map_termination_reason') }}
group by branch_id, termination_reason_code
