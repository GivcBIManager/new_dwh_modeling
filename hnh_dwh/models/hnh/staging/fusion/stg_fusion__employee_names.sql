-- Fusion employee names, staged only for gold.dim_employee_pii (the SSAS Employee Details table, visible to pay users;
-- Phase 4 spec section 3 as amended 2026-10-11). No other model reads it.
select
    person_id,
    toDate32(valid_from)                                                         as valid_from,
    nullIf(replaceRegexpAll(trimBoth(ifNull(full_name, '')), '\\s+', ' '), '')   as full_name
from {{ hnh_fusion_source('dim_employee') }} final
where ifNull(is_current, '') = 'Y'
