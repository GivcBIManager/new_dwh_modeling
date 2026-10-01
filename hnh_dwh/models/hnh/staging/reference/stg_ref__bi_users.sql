select
    trimBoth(UserName)                   as user_name,
    nullIf(toUInt8(BRANCH_ID), 0)        as branch_id,
    toUInt8(IsAdmin)                     as is_admin,
    {{ hnh_str('Unified_Speciality') }}  as unified_specialty
from {{ source('reference', 'bi_users') }}
