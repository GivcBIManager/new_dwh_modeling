select
    lower(trimBoth(LEVEL))                    as level,
    lower({{ hnh_fs_label('VALUE') }})        as value_lower,
    toUInt16(SORT_ORDER)                      as sort_order,
    {{ hnh_str('STATEMENT_GROUP') }}          as statement_group
from {{ source('reference', 'map_fs_line_order') }}
