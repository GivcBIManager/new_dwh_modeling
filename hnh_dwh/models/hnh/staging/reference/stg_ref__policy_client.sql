-- Policy / client-company / referral rules (docs/policy_client_config.md). default.map_policy_client is an insert-only change log: the latest row per
-- rule_id wins and a latest row with is_deleted = 1 removes the rule.
select
    rule_id,
    latest.1 as branch_id,
    latest.2 as purchaser_code,
    latest.3 as policy_code,
    latest.4 as name_pattern,
    latest.5 as client_company,
    latest.6 as is_referral
from (
    select rule_id,
           argMax(tuple(branch_id, purchaser_code, policy_code, trimBoth(name_pattern), trimBoth(client_company), is_referral, is_deleted), changed_at) as latest
    from {{ source('reference', 'map_policy_client') }}
    group by rule_id
)
where latest.7 = 0
