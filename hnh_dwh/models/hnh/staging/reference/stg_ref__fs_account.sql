select
    toUInt32(ORACLE_CODE)             as natural_account,
    upper({{ hnh_fs_label('FS_TYPE') }}) as fs_type,
    {{ hnh_fs_label('FS_ELEMENT') }}  as fs_element,
    {{ hnh_fs_label('FS_CATEGORY') }} as fs_category,
    {{ hnh_fs_label('FS_CAPTION') }}  as fs_caption,
    {{ hnh_fs_label('FS_LINE') }}     as fs_line,
    MAPPED_IN                         as mapped_in
from {{ source('reference', 'map_fs_account') }}
