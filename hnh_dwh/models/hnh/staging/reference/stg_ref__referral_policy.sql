select distinct
    toUInt8(BRANCH_ID)      as branch_id,
    toInt64(PURCHASER_CODE) as purchaser_code,
    toInt64(POLICY_CODE)    as policy_code
from {{ source('reference', 'map_referral_policies') }}
