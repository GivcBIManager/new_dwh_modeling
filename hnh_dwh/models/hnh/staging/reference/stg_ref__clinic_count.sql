select
    toUInt8(BRANCH_ID)      as branch_id,
    toInt32(CLINICS_COUNT)  as clinics_count
from {{ source('reference', 'map_clinic_count') }}
