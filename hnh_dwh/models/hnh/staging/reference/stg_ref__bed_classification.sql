select
    toUInt8(BRANCH_ID)        as branch_id,
    trimBoth(BED)             as bed_location,
    any(trimBoth(CLASSIFICATION)) as classification
from {{ source('reference', 'map_bed_classification') }}
group by branch_id, bed_location
