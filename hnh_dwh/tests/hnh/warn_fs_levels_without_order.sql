{{ config(severity='warn') }}
-- FS levels used by the mapping that have no row in map_fs_line_order (they sort last).
select fs_type, fs_element, fs_category, fs_caption
from {{ ref('dim_fs_line') }}
where is_not_mapped = 0 and 999 in (type_sort, element_sort, category_sort, caption_sort)
