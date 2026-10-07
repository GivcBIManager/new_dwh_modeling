-- Review focus 5: fail closed. A non-admin user gets access only to branches named on their own source rows (compared on
-- the normalised user name), or, for a source row with a specialty and no branch, to that specialty in a hospital branch
-- (not Head Office; open item O2).
select a.user_name, a.branch_key, a.unified_specialty
from {{ ref('sec_user_access') }} as a
left join (
    select distinct {{ hnh_user_name('user_name') }} as user_name, branch_id
    from {{ ref('stg_ref__bi_users') }}
    where branch_id is not null
) as u
    on u.user_name = a.user_name and u.branch_id = a.branch_key
left join (
    select distinct {{ hnh_user_name('user_name') }} as user_name, unified_specialty
    from {{ ref('stg_ref__bi_users') }}
    where branch_id is null and unified_specialty is not null
) as s
    on s.user_name = a.user_name and s.unified_specialty = a.unified_specialty
where a.is_admin = 0 and u.user_name is null and (s.user_name is null or a.branch_key = 100)
{{ hnh_settings() }}
