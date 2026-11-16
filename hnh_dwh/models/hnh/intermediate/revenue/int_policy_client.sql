{{ config(order_by='(branch_id, policy_code)') }}

-- Client company and referral flag of every Oasis policy, from the BI manager's rules in default.map_policy_client
-- (stg_ref__policy_client, docs/policy_client_config.md). Each value comes from the best rule that has an opinion on it
-- (client_company != '', is_referral not null): an exact policy_code rule beats a pattern rule, a rule for the branch
-- beats a branch 0 rule, a longer pattern beats a shorter one (then the highest rule_id, so the result is stable).
-- A rule with a purchaser_code applies only to that purchaser's policies. A pattern matches whole words, ignoring case.
-- No company rule: the client name in the description ("<INSURER> - <CLIENT> (<number>)"): the text after the first
-- " - " (else after the first "-", else all of it), without a trailing "(digits)" or number and the spaces, dots and
-- dashes around it, title-cased.
-- No referral rule: not a referral. stg_ref__referral_policy reads the referral policies from here.

with policies as (
    select
        p.branch_id      as branch_id,
        p.policy_code    as policy_code,
        p.purchaser_code as purchaser_code,
        p.description    as description,
        p.is_active      as is_active,
        multiIf(position(p.description, ' - ') > 0, substring(p.description, position(p.description, ' - ') + 3),
                position(p.description, '-') > 0, substring(p.description, position(p.description, '-') + 1),
                p.description) as after_dash,
        nullIf(trimBoth(replaceRegexpOne(after_dash, '[\\s.\\-]*(\\(\\s*\\d+\\s*\\)|\\d+)?[\\s.\\-]*$', '')), '') as client_raw,
        ifNull(client_raw, p.description) as fallback_client
    from {{ ref('stg_oasis__policies') }} as p
),

rules as (
    select rule_id, branch_id, purchaser_code, policy_code, name_pattern, client_company, is_referral
    from {{ ref('stg_ref__policy_client') }}
),

matches as (
    -- exact rules, joined on the policy code
    select
        p.branch_id as branch_id, p.policy_code as policy_code, r.client_company as client_company, r.is_referral as is_referral,
        tuple(toUInt8(1), toUInt8(r.branch_id != 0), toUInt64(0), r.rule_id) as rank
    from policies as p
    inner join (select * from rules where policy_code is not null) as r on r.policy_code = p.policy_code
    where (r.branch_id = 0 or r.branch_id = p.branch_id)
      and (r.purchaser_code is null or ifNull(r.purchaser_code = p.purchaser_code, 0))

    union all

    -- pattern rules, whole-word and case-insensitive on the description
    select
        p.branch_id, p.policy_code, r.client_company, r.is_referral,
        tuple(toUInt8(0), toUInt8(r.branch_id != 0), toUInt64(length(r.name_pattern)), r.rule_id)
    from policies as p
    cross join (select * from rules where policy_code is null and name_pattern != '') as r
    where (r.branch_id = 0 or r.branch_id = p.branch_id)
      and (r.purchaser_code is null or ifNull(r.purchaser_code = p.purchaser_code, 0))
      and match(ifNull(p.description, ''), concat('(?i)\\b(', r.name_pattern, ')\\b'))
),

resolved as (
    select
        branch_id,
        policy_code,
        argMaxIf(client_company, rank, client_company != '')    as client_company,
        argMaxIf(is_referral, rank, is_referral is not null)    as is_referral
    from matches
    group by branch_id, policy_code
)

select
    p.branch_id                                                     as branch_id,
    p.policy_code                                                   as policy_code,
    p.purchaser_code                                                as purchaser_code,
    p.description                                                   as policy_name,
    if(ifNull(m.client_company, '') != '', assumeNotNull(m.client_company),
       ifNull({{ hnh_title('p.fallback_client') }}, 'Not named'))   as client_company,
    toUInt8(ifNull(m.is_referral, 0))                               as is_referral,
    p.is_active                                                     as is_active
from policies as p
left join resolved as m on m.branch_id = p.branch_id and m.policy_code = p.policy_code
{{ hnh_settings() }}
