select
    toUInt8(BRANCH_ID)                as branch_id,
    trimBoth(CODE)                    as code,
    upper({{ hnh_fs_label('TYPE') }}) as fs_type,
    {{ hnh_fs_label('FS_ELEMENT') }}  as fs_element,
    {{ hnh_fs_label('FS_CATEGORY') }} as fs_category,
    {{ hnh_fs_label('FS_CAPTION') }}  as fs_caption,
    {{ hnh_fs_label('FS_LINE') }}     as fs_line
from {{ source('reference', 'map_oasis_fs_account') }}
