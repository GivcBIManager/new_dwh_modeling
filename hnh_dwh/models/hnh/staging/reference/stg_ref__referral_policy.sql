-- Referral policies (fact_episode.is_referral_policy and the BSC referral KPIs): the policies int_policy_client resolves
-- as referrals from the BI manager's rules in default.map_policy_client (docs/policy_client_config.md). Until 2026-11
-- this read default.map_referral_policies, whose rows became the table's first exact referral rules. Column types are
-- kept (UInt8, Int64, Int64): a policy without a purchaser has purchaser_code -1.
select
    p.branch_id                              as branch_id,
    ifNull(p.purchaser_code, toInt64(-1))    as purchaser_code,
    p.policy_code                            as policy_code
from {{ ref('int_policy_client') }} as p
where p.is_referral = 1
