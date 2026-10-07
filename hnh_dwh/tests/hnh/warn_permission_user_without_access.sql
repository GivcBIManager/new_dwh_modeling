{{ config(severity='warn') }}
-- SSAS spec 6.1: a user listed in map_bi_user_permission who has no sec_user_access row gets nothing; list them so the
-- BI manager can fix the name.
select p.user_name
from {{ ref('stg_ref__bi_user_permission') }} as p
left join (select distinct user_name from {{ ref('sec_user_access') }}) as s on s.user_name = p.user_name
where s.user_name is null or s.user_name = ''
{{ hnh_settings() }}
