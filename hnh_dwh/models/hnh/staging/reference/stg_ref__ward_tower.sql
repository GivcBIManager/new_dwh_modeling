select
    toUInt8(BRANCH_ID)    as branch_id,
    toInt64(ID)           as work_entity,
    min(trimBoth(Tower))  as tower
from {{ source('reference', 'map_ward_tower') }}
group by branch_id, work_entity
