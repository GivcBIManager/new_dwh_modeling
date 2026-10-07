-- Pay and PII permissions of BI users (SSAS spec 6.1). One row per normalised user name; the source may carry an old
-- domain prefix, as bi_users does. A user who is not listed gets no permission (fail closed in sec_user_access).
select user_name, max(can_see_pay) as can_see_pay, max(can_see_pii) as can_see_pii
from (
    select
        {{ hnh_user_name('bi_user_name') }} as user_name,
        toUInt8(can_see_pay)                as can_see_pay,
        toUInt8(can_see_pii)                as can_see_pii
    from {{ source('reference', 'map_bi_user_permission') }}
)
where user_name != ''
group by user_name
