-- Referral policies (fact_episode.is_referral_policy and the BSC referral KPIs): the policies int_policy_client resolves
-- as referrals from the BI manager's rules in default.map_policy_client (docs/policy_client_config.md). Until 2026-11
-- this read default.map_referral_policies, whose rows became the table's first exact referral rules.
select
    branch_id,
    purchaser_code,
    policy_code
from {{ ref('int_policy_client') }}
where is_referral = 1
