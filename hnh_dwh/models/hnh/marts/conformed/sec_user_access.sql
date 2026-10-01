{{ config(order_by='(login_name, branch_key)') }}

with users as (
    select user_name, branch_id, unified_specialty, max(is_admin) over (partition by user_name) as is_admin
    from {{ ref('stg_ref__bi_users') }}
    where user_name != ''
),

admins as (
    -- An administrator sees every branch and has no specialty restriction.
    select distinct u.user_name as user_name, b.branch_id as branch_key,
           cast(null as Nullable(String)) as unified_specialty, toUInt8(1) as is_admin
    from users as u
    cross join {{ ref('stg_ref__branch') }} as b
    where u.is_admin = 1
),

restricted as (
    select distinct user_name, assumeNotNull(branch_id) as branch_key, unified_specialty, toUInt8(0) as is_admin
    from users
    where is_admin = 0 and branch_id is not null
)

select
    user_name                                                       as user_name,
    concat('{{ var("hnh_ssas_machine_name") }}', char(92), user_name)   as login_name,
    branch_key                                                      as branch_key,
    unified_specialty                                               as unified_specialty,
    is_admin                                                        as is_admin
from (
    select * from admins
    union all
    select * from restricted
)
