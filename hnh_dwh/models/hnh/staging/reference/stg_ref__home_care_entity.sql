select distinct
    toUInt8(BRANCH_ID)    as branch_id,
    toInt64(WORK_ENTITY)  as work_entity
from {{ source('reference', 'map_home_care_entity') }}
