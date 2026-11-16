-- Policy / client-company / referral mapping (docs/policy_client_config.md). Insert-only change log: a change is a
-- new row, the latest row per rule_id wins, is_deleted = 1 removes a rule. Edited by the BI manager with SQL.
-- A row has either policy_code or name_pattern, never both. branch_id 0 = every branch.
-- client_company '' = no opinion; is_referral null = no opinion; name_pattern '' = none.
CREATE TABLE IF NOT EXISTS default.map_policy_client
(
    rule_id String, branch_id UInt8, purchaser_code Nullable(Int64), policy_code Nullable(Int64),
    name_pattern String, client_company String, is_referral Nullable(UInt8),
    changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8
) ENGINE = MergeTree ORDER BY (rule_id, changed_at);
