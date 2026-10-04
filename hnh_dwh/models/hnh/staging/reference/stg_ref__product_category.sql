-- The mapping holds a few categories twice, once with stray whitespace in the code
-- (branch 6 ' GC' and 'GC'); collapse them to one row per cleaned code.
select
    toUInt8(BRANCH_ID)                                  as branch_id,
    assumeNotNull({{ hnh_code('CATEGORY_CODE') }})      as category_code,
    min({{ hnh_str('`GROUP`') }})                       as group_name,
    min({{ hnh_str('UNIFIED_CATEGORY') }})              as unified_category,
    min({{ hnh_str('DEPARTMENT') }})                    as department,
    min({{ hnh_str('HIGH_LEVEL_DEPT') }})               as high_level_department
from {{ source('reference', 'map_product_category') }}
where {{ hnh_code('CATEGORY_CODE') }} is not null
group by branch_id, category_code
