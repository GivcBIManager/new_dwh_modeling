select
    toUInt8(branch_id)             as branch_id,
    toInt64(bed_class)             as bed_class,
    {{ hnh_str('description') }}   as description
from {{ source('oasis', 'bed_class_master_data') }} final
