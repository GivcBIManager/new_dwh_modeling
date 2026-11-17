{{ config(order_by='(branch_id, policy_code)') }}

-- Client company and referral flag of every Oasis policy, from the BI manager's rules in default.map_policy_client
-- (stg_ref__policy_client, docs/policy_client_config.md). Each value comes from the best rule that has an opinion on it
-- (client_company != '', is_referral not null): an exact policy_code rule beats a pattern rule, a rule for the branch
-- beats a branch 0 rule, then the pattern whose matched text is longest (in characters), then the longer pattern, then
-- the highest rule_id, so the result is stable. A rule with a purchaser_code applies only to that purchaser's policies.
-- A pattern is literal words or phrases separated by "|" (not a regular expression: "C++" and "CO." are plain text, so
-- a typo cannot fail the build); each phrase matches whole words, ignoring case, with any run of spaces between words.
-- No company rule: the client name in the description ("<INSURER> - <CLIENT> (<number>)"): the text after the first
-- " - " (else after the first "-", else all of it), without a trailing "(digits)" or number and the spaces, dots and
-- dashes around it, as written in Oasis (dim_policy title-cases it; is_client_from_rule = 0).
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

-- one row per phrase of a pattern rule, as an RE2 expression: each word quoted literally (\Q...\E, a "\E" inside a word
-- re-quoted), words joined by \s+, and a letter / digit / underscore boundary on both sides (\b would not see the end of
-- "C++", and is ASCII only)
pattern_terms as (
    select
        rule_id, branch_id, purchaser_code, client_company, is_referral,
        toUInt64(lengthUTF8(name_pattern))                     as pattern_length,
        toUInt64(lengthUTF8(arrayStringConcat(words, ' ')))    as term_length,
        concat('(?i)(?:^|[^\\pL\\pN_])',
               arrayStringConcat(arrayMap(w -> concat('\\Q', replaceAll(w, '\\E', '\\E\\\\E\\Q'), '\\E'), words), '\\s+'),
               '(?:$|[^\\pL\\pN_])')                           as term_regex
    from rules
    array join arrayFilter(t -> length(t) > 0, arrayMap(t -> splitByWhitespace(t), splitByChar('|', name_pattern))) as words
    where policy_code is null and name_pattern != ''
),

matches as (
    -- exact rules, joined on the policy code
    select
        p.branch_id as branch_id, p.policy_code as policy_code, r.client_company as client_company, r.is_referral as is_referral,
        tuple(toUInt8(1), toUInt8(r.branch_id != 0), toUInt64(0), toUInt64(0), r.rule_id) as rank
    from policies as p
    inner join (select * from rules where policy_code is not null) as r on r.policy_code = p.policy_code
    where (r.branch_id = 0 or r.branch_id = p.branch_id)
      and (r.purchaser_code is null or ifNull(r.purchaser_code = p.purchaser_code, 0))

    union all

    -- pattern rules: a phrase found as whole words in the description; the matched text is as long as the phrase
    select
        p.branch_id, p.policy_code, t.client_company, t.is_referral,
        tuple(toUInt8(0), toUInt8(t.branch_id != 0), t.term_length, t.pattern_length, t.rule_id)
    from policies as p
    cross join pattern_terms as t
    where (t.branch_id = 0 or t.branch_id = p.branch_id)
      and (t.purchaser_code is null or ifNull(t.purchaser_code = p.purchaser_code, 0))
      and match(ifNull(p.description, ''), t.term_regex)
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
       ifNull(p.fallback_client, 'Not named'))                      as client_company,
    toUInt8(ifNull(m.client_company, '') != '')                     as is_client_from_rule,
    toUInt8(ifNull(m.is_referral, 0))                               as is_referral,
    p.is_active                                                     as is_active
from policies as p
left join resolved as m on m.branch_id = p.branch_id and m.policy_code = p.policy_code
{{ hnh_settings() }}
