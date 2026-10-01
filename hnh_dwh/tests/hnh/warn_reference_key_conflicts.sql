{{ config(severity='warn') }}

select 'map_unified_department_v2' as source_table,
       upper(trimBoth(DEPARTMENT)) as key_value,
       uniqExact(trimBoth(UNIFIED_DEPARTMENT)) as distinct_values
from {{ source('reference', 'map_unified_department_v2') }}
group by key_value
having distinct_values > 1

union all

select 'map_bed_classification',
       concat(toString(BRANCH_ID), '|', upper(trimBoth(BED))),
       uniqExact(trimBoth(CLASSIFICATION))
from {{ source('reference', 'map_bed_classification') }}
group by BRANCH_ID, upper(trimBoth(BED))
having uniqExact(trimBoth(CLASSIFICATION)) > 1

union all

select 'map_ward_tower',
       concat(toString(BRANCH_ID), '|', toString(ID)),
       uniqExact(trimBoth(Tower))
from {{ source('reference', 'map_ward_tower') }}
group by BRANCH_ID, ID
having uniqExact(trimBoth(Tower)) > 1

union all

select 'map_termination_reason',
       concat(toString(BRANCH_ID), '|', toString(TERMINATION_REASON_CODE)),
       uniqExact(trimBoth(UNIFIED_REASON))
from {{ source('reference', 'map_termination_reason') }}
group by BRANCH_ID, TERMINATION_REASON_CODE
having uniqExact(trimBoth(UNIFIED_REASON)) > 1
