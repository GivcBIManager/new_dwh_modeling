-- Policy client config: first content. Applied once by apply_policy_config.ps1; afterwards default.map_policy_client
-- is the source of truth. Both statements skip rule_ids that already exist, so a re-run adds nothing twice.

-- Every policy already in the referral list becomes a referral rule on branch + policy code, as the old join matched;
-- purchaser_code stays null (no narrowing) and the old list's purchaser is kept in change_note.
INSERT INTO default.map_policy_client (rule_id, branch_id, purchaser_code, policy_code, name_pattern, client_company, is_referral, changed_at, changed_by, change_note, is_deleted)
SELECT concat('REF-', toString(BRANCH_ID), '-', toString(POLICY_CODE)), toUInt8(BRANCH_ID), CAST(NULL AS Nullable(Int64)), toInt64(POLICY_CODE),
       '', '', toUInt8(1), now64(3), 'seed', concat('from map_referral_policies, purchaser ', toString(PURCHASER_CODE)), toUInt8(0)
FROM default.map_referral_policies
WHERE concat('REF-', toString(BRANCH_ID), '-', toString(POLICY_CODE)) NOT IN (SELECT rule_id FROM default.map_policy_client);

-- Name patterns that set a client company (whole-word match, see docs/policy_client_config.md).
INSERT INTO default.map_policy_client (rule_id, branch_id, purchaser_code, policy_code, name_pattern, client_company, is_referral, changed_at, changed_by, change_note, is_deleted)
SELECT rule_id, toUInt8(0), CAST(NULL AS Nullable(Int64)), CAST(NULL AS Nullable(Int64)), name_pattern, client_company,
       CAST(NULL AS Nullable(UInt8)), now64(3), 'seed', 'seed 2026-11-16', toUInt8(0)
FROM (SELECT 'PAT-STC' AS rule_id, 'STC|SAUDI TELECOM' AS name_pattern, 'STC' AS client_company
      UNION ALL SELECT 'PAT-ARAMCO', 'ARAMCO', 'Saudi Aramco')
WHERE rule_id NOT IN (SELECT rule_id FROM default.map_policy_client);
