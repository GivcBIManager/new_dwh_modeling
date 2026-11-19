-- Fusion employee names and personal details, staged only for gold.dim_employee_pii (the SSAS Employee Details table,
-- visible to pay users; Phase 4 spec section 3 as amended 2026-10-11; personal details added 2026-11-19 for the HR
-- report's record lists). No other model reads it.
select
    person_id,
    toDate32(valid_from)                                                         as valid_from,
    nullIf(replaceRegexpAll(trimBoth(ifNull(full_name, '')), '\\s+', ' '), '')   as full_name,
    toDate32(date_of_birth)                                                      as birth_date,
    {{ hnh_code('marital_status') }}                                             as marital_status_code,  -- S, M, D
    nullIf(lower(trimBoth(ifNull(email_address, ''))), '')                       as email_address,
    nullIf(trimBoth(ifNull(phone_number, '')), '')                               as phone_number,
    if(national_identifier_number is null, cast(null as Nullable(String)),
       toString(national_identifier_number))                                     as national_id
from {{ hnh_fusion_source('dim_employee') }} final
where ifNull(is_current, '') = 'Y'
