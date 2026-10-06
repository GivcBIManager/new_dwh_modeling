select
    toUInt8(BRANCH_ID)              as branch_id,
    toInt32(FIRST_FUSION_MONTH)     as first_fusion_month
from {{ source('reference', 'map_payroll_cutover') }}
