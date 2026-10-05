-- Admins see Head Office; nobody else gets it unless a source row grants branch 100.
select a.user_name
from (select distinct user_name from {{ ref('sec_user_access') }} where is_admin = 1) as a
left join (select user_name from {{ ref('sec_user_access') }} where branch_key = 100) as h on h.user_name = a.user_name
where h.user_name is null
{{ hnh_settings() }}
