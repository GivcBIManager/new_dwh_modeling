select
    toUInt8(BRANCH_ID)        as branch_id,
    {{ hnh_code('BED') }}      as bed_location,
    min(trimBoth(CLASSIFICATION)) as classification
from {{ source('reference', 'map_bed_classification') }}
group by branch_id, bed_location
