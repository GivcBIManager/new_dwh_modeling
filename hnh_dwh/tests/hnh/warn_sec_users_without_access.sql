{{ config(severity='warn') }}
-- Users in the source who end up with no access at all. Each needs a branch assigned.
-- Compared on the normalised user name; blank names are ignored.
select u.user_name
from (
    select distinct {{ hnh_user_name('user_name') }} as user_name
    from {{ ref('stg_ref__bi_users') }}
    where {{ hnh_user_name('user_name') }} != ''
) as u
left join (select distinct user_name from {{ ref('sec_user_access') }}) as a on a.user_name = u.user_name
where a.user_name is null
{{ hnh_settings() }}
