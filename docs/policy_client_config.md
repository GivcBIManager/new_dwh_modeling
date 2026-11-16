# Policy client settings

Which client company a policy belongs to, and whether it is a referral policy, is a row in one ClickHouse table in database `default` on `172.22.25.214`: `map_policy_client`. The patient-policy report, Encounters, Admissions and the referral KPIs of the balanced scorecard read it through the gold models.

## How a change works

The table is a change log. To change something, **insert a new row** with the same `rule_id` and the new values. The newest row for a `rule_id` wins. To remove a rule, insert a row with `is_deleted = 1`. Never update or delete rows: the old rows are the history.

Every row ends with the same four columns:

| Column | Value |
|---|---|
| `changed_at` | `now64(3)` |
| `changed_by` | your name |
| `change_note` | why, in a few words |
| `is_deleted` | `0`, or `1` to remove the rule |

**When it shows in the report.** The next morning, after the nightly dbt build and the SSAS refresh, **provided** the nightly dbt job's selector builds `stg_ref__policy_client`, `int_policy_client`, `stg_ref__referral_policy`, `dim_policy` and the facts that read them, and `process.ps1 -Selected` matches that selector (`docs/receiving_project_config.md`, "Charge line relationships", Dagster / nightly). Until that is confirmed, a change shows only after a manual build. To see it sooner, run the dbt build in the receiving project and then `ssas\scripts\process.ps1 -Mode Daily`. That run changes the production SSAS database: ask before running it.

**See the history of a rule:**

```sql
SELECT * FROM default.map_policy_client WHERE rule_id = 'PAT-STC' ORDER BY changed_at;
```

**Undo a change.** Insert the previous values again.

## The table `map_policy_client`

Key: `rule_id` (any text, unique per rule).

| Column | Meaning |
|---|---|
| `branch_id` | 0 = every branch, 1-8 = one branch |
| `purchaser_code` | optional narrowing |
| `policy_code` | set: an exact rule for one policy |
| `name_pattern` | set: literal words or phrases separated by `\|` (`STC\|SAUDI TELECOM`), matched as whole words on the policy description, case-insensitive. Not a regular expression. `''` = none |
| `client_company` | the client name as it should appear (`STC`, `Saudi Aramco`). `''` = this row says nothing about the company |
| `is_referral` | 1 = referral, 0 = not a referral, null = this row says nothing about referral |

A row has either `policy_code` or `name_pattern`, never both.

**Warning:** policy codes are numbered per branch. An exact rule with `branch_id` 0 applies its `policy_code` on every branch, which is usually a different policy on each one. Give exact rules their branch.

## Which rule wins

Per policy (one per branch and policy code):
1. An exact `policy_code` row wins over a pattern row.
2. A row for the branch wins over a row for every branch (`branch_id` 0).
3. Among pattern rows the most specific wins: the one whose matched text in the description is longest (in characters). `STC PAY` beats `STC|SAUDI TELECOM` on `TAWUNIYA - STC PAY (2540)`; on a tie the longer pattern, then the higher `rule_id`.

`client_company` and `is_referral` are resolved separately, each from the best row that has a value in that column. A row added only for the company leaves the referral flag alone. A policy with no referral row is not a referral.

## Whole-word patterns

A pattern is plain text: one or more words or phrases separated by `|`. It is not a regular expression, so `C++` or `CO.` mean exactly those characters. A pattern can therefore never fail the nightly build.

Each phrase matches whole words only:
- `STC` matches `TAWUNIYA - STC PAY (2540)` and `TAWUNIYA-STC SOLUTIONS`.
- `STC` does not match `WESTCON` or `MISTCA`, which contain the letters `STC` inside a word.
- `CO.` does not match `COX`.
- Case does not matter.
- Any run of spaces in the description counts as one space.

## Examples

**Add a client company** (every policy with `ARAMCO` in its name shows as `Saudi Aramco`):

```sql
INSERT INTO default.map_policy_client
  (rule_id, branch_id, purchaser_code, policy_code, name_pattern, client_company, is_referral, changed_at, changed_by, change_note, is_deleted)
VALUES ('PAT-SABIC', 0, NULL, NULL, 'SABIC', 'SABIC', NULL, now64(3), 'bi_manager', 'new client company', 0);
```

**Mark one policy as referral** (branch 3, policy 4521):

```sql
INSERT INTO default.map_policy_client
  (rule_id, branch_id, purchaser_code, policy_code, name_pattern, client_company, is_referral, changed_at, changed_by, change_note, is_deleted)
VALUES ('REF-3-4521', 3, NULL, 4521, '', '', 1, now64(3), 'bi_manager', 'referral agreement 2026', 0);
```

**Delete a rule** (copy its current values and set `is_deleted = 1`):

```sql
INSERT INTO default.map_policy_client
SELECT rule_id, branch_id, purchaser_code, policy_code, name_pattern, client_company, is_referral,
       now64(3), 'bi_manager', 'agreement ended', 1
FROM default.map_policy_client WHERE rule_id = 'REF-3-4521' ORDER BY changed_at DESC LIMIT 1;
```

## First load

`scripts/policy_config/apply_policy_config.ps1` creates the table and seeds it:
- one `REF-<branch>-<policy>` rule for every row of `default.map_referral_policies` (`is_referral` 1), on branch + policy code like the old referral join: `purchaser_code` is left null and the old list's purchaser is kept in `change_note`;
- two pattern rules, `PAT-STC` (`STC|SAUDI TELECOM`, company `STC`) and `PAT-ARAMCO` (`ARAMCO`, company `Saudi Aramco`).

Run it with `-DryRun` first. A run without `-DryRun` writes to the live ClickHouse and asks for a ClickHouse login that may create tables and insert into `default`. A table that already has rows is not seeded again.

## Who can write

Inserting needs a ClickHouse login with `INSERT` on this table. Reading it needs `SELECT`. The report and SSAS read it only through the gold models.
