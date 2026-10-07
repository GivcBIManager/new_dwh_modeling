{{ config(order_by='(login_name, branch_key)') }}

-- The source UserName already carries an old domain prefix (domain, backslash, name) in mixed case.
-- The login is rebuilt as SSAS machine, backslash, lower-case name without the old prefix.
with raw_users as (
    select
        {{ hnh_user_name('user_name') }} as normalised_name,
        trimBoth(user_name)              as source_name,
        branch_id,
        unified_specialty,
        is_admin
    from {{ ref('stg_ref__bi_users') }}
),

users as (
    select
        normalised_name                                        as user_name,
        source_name                                            as source_user_name,
        branch_id,
        unified_specialty,
        max(is_admin) over (partition by normalised_name)      as is_admin
    from raw_users
),

users_clean as (
    select * from users where user_name != ''
),

admins as (
    -- An administrator sees every branch but keeps the specialty restriction of the source rows.
    select distinct u.user_name as user_name, b.branch_id as branch_key,
           u.unified_specialty as unified_specialty, toUInt8(1) as is_admin
    from users_clean as u
    cross join (
        select branch_id from {{ ref('stg_ref__branch') }}
        union all
        select toUInt8(100)              -- Head Office (Phase 3): admins only, unless a source row grants it
    ) as b
    where u.is_admin = 1
),

restricted as (
    select distinct u.user_name as user_name, assumeNotNull(u.branch_id) as branch_key,
           u.unified_specialty as unified_specialty, toUInt8(0) as is_admin
    from users_clean as u
    where u.is_admin = 0 and u.branch_id is not null
),

specialty_wide as (
    -- A non-admin row with a specialty but no branch grants that specialty in every hospital branch (not Head Office;
    -- open item O2). A row with neither branch nor specialty grants nothing.
    select distinct u.user_name as user_name, b.branch_id as branch_key,
           u.unified_specialty as unified_specialty, toUInt8(0) as is_admin
    from users_clean as u
    cross join (select branch_id from {{ ref('stg_ref__branch') }}) as b
    where u.is_admin = 0 and u.branch_id is null and u.unified_specialty is not null
),

first_source_name as (
    select user_name, min(source_user_name) as source_user_name
    from users_clean
    group by user_name
)

select
    a.user_name                                                          as user_name,
    f.source_user_name                                                   as source_user_name,
    concat('{{ var("hnh_ssas_machine_name") }}', char(92), a.user_name)   as login_name,
    a.branch_key                                                         as branch_key,
    a.unified_specialty                                                  as unified_specialty,
    a.is_admin                                                           as is_admin,
    toUInt8(ifNull(p.can_see_pay, 0))                                    as can_see_pay,
    toUInt8(ifNull(p.can_see_pii, 0))                                    as can_see_pii
from (
    select * from admins
    union all
    select * from restricted
    union distinct
    select * from specialty_wide
) as a
inner join first_source_name as f on f.user_name = a.user_name
left join {{ ref('stg_ref__bi_user_permission') }} as p on p.user_name = a.user_name
{{ hnh_settings() }}
