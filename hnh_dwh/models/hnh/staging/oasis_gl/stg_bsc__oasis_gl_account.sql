-- Oasis GL accounts with the old fs_mapping hierarchy, lower-cased and trimmed like the Fusion side of
-- fact_gl_fs_monthly ('' when unmapped). account_code is the main + sub account the fs_mapping is keyed on.
select
    oasis_gl_account_key,
    branch_key,
    oasis_account                          as account_code,
    lower(trimBoth(ifNull(fs_type, '')))     as fs_type,
    lower(trimBoth(ifNull(fs_element, '')))  as fs_element,
    lower(trimBoth(ifNull(fs_category, ''))) as fs_category,
    lower(trimBoth(ifNull(fs_caption, '')))  as fs_caption,
    lower(trimBoth(ifNull(fs_line, '')))     as fs_line
from {{ hnh_oasis_gl_source('dim_oasis_gl_account') }}
