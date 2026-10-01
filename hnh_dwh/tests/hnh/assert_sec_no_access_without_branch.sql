-- Review focus 5: fail closed. A non-admin user gets access only to branches
-- named on their own source rows (compared on the normalised user name).
select a.user_name, a.branch_key
from {{ ref('sec_user_access') }} as a
left join (
    select distinct {{ hnh_user_name('user_name') }} as user_name, branch_id
    from {{ ref('stg_ref__bi_users') }}
) as u
    on u.user_name = a.user_name and u.branch_id = a.branch_key
where a.is_admin = 0 and u.user_name is null
{{ hnh_settings() }}
