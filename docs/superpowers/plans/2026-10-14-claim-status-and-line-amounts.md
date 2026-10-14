# Claim Status Hierarchy and Claim Line Amounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Analyse billed statements by claim status (Validation → Submission → Detailed Status) and submission channel (NPHIES, Manual, Not submitted). Then analyse the NPHIES claim lines behind them, with approved and rejected amounts taken from each line's response outcome.

**Architecture:**
- **One rule macro file.** `hnh_rules_claims.sql` gains two macros: the submission channel and the claim status key.
- **One new intermediate model.** `int_invoice_claim_status` gives every invoice its status, channel and key.
- **One new dimension.** `dim_claim_status` is related to both `fact_invoice` and `fact_claim_line`.
- **Redefined amounts.** `fact_claim_line.approved_amount` and `rejected_amount` follow the response outcome; `bsc_vw_rcm` changes its rate denominators to match.
- **SSAS.** A `Claim Status` table with a hierarchy, four new billed measures and two redefined rate measures.
- **Offline checks.** dbt is not installed on HNHANALYTICSSRV. Each model's logic is checked here with a hand-written read-only query against gold. The dbt build, with the unit tests, runs on the receiving server (Ubuntu) in Task 8.

**Tech Stack:** dbt-clickhouse (receiving project), ClickHouse 26.5, SSAS Tabular (TMDL, Tabular Editor 2.27), Python 3.12 + pytest, Windows PowerShell 5.1 + Pester 3.4, System.Data.Odbc over the DSN `HNH_Gold`.

**Spec:** `docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md` (parents: `2026-10-05-hnh-dwh-phase2b-claims-design.md`, `2026-10-07-hnh-ssas-tabular-model-design.md`).

**Branch:** create `claim-status` from `main`.

## Global Constraints

- **HNHANALYTICSSRV is the production server** (`CLAUDE.md`).
  - **Ask the user before:**
    - the dbt build on the receiving server;
    - `ssas/scripts/deploy.ps1`, `process.ps1` or `partitions.ps1` without `-DryRun`;
    - any ClickHouse write.
  - **Needs no confirmation:** `SELECT`, `DESCRIBE` and `SHOW` through `HNH_Gold`; DAX queries; pytest; Pester; Tabular Editor `-A` BPA runs.
  - Never print or commit a password.
- **dbt conventions:**
  - Work only under `hnh/` folders. Macros are prefixed `hnh_`. YAML uses the `tests:` key.
  - `branch_id` / `branch_key` is `UInt8`.
  - A gold or intermediate table with a `left join` ends with `{{ hnh_settings() }}` (`join_use_nulls = 1`).
- **ClickHouse cautions met before:**
  - An alias that shadows a source column *inside an aggregate* raises error 184: name the intermediate differently.
  - `union` branches must have matching types.
- **Claim status values** (spec 4.1), exactly:
  - channels: `NPHIES`, `Manual`, `Not submitted`, `Unknown`;
  - a null approval code: `New` / `New` / `New`;
  - an unmapped code: `Unknown` / `Unknown` / `Unknown`;
  - key: `hnh_surrogate_key([detailed_status, submission_channel])`.
- **Line amounts** (spec 4.2), only when the line has an adjudicated response (`has_adjudication = 1`):
  - Approved: approved = net, rejected = 0;
  - Partially approved: approved = `ifNull(benefit, 0)`, rejected = `greatest(net − benefit, 0)`;
  - Rejected: approved = 0, rejected = net;
  - otherwise both are 0.
- **The `legacy_*` columns do not change.**
- **SSAS:**
  - Measures are edited only between `VAR __Value = ( -- measure body` and `) -- end of measure body`.
  - After editing measures, run `python ssas/tools/measure_guards.py` and then `python ssas/tools/sync_perspectives.py`.
  - Every measure has a check in `ssas/tests/measures/*.json`.
- **Shell syntax.**
  - Windows PowerShell 5.1: no ternary, no `??`, no `&&` / `||` between commands.
  - Pester 3.4 syntax: `| Should Be`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Spec refinements made while planning

| Spec says | Plan does | Why |
|---|---|---|
| `bsc_vw_rcm` reads the redefined columns unchanged (C5) | `bsc_vw_rcm` also divides its rejection and approval rates by approved + rejected instead of the response's submitted amount | The amounts are now net-based (no VAT); dividing them by the VAT-inclusive submitted amount would mix bases. This matches the new `Claim Rejection Rate %`. |
| `fact_invoice` takes `submission_channel` (5.3) | Kept on gold `fact_invoice`, dropped from `ssas_fact_invoice` | In SSAS the channel is a column of `Claim Status` only, so there is one slicer for it, not two. |
| `rec_claims_monthly` unit tests updated (7) | Unchanged | The model only sums the columns; its fixture supplies approved and rejected as inputs, so the test stays valid. |
| Unit test, visit 11: net 115 including VAT | Net 100 (the response's submitted 115 includes 15 tax) | Spec section 2: line net excludes VAT. |
| Singular test: approved + rejected = net on decided lines | Allows negative nets | 138 lines (SAR −8k) have a negative net; 108 of them are adjudicated. |

Key values used in the unit tests: `hnh_surrogate_key([d, c])`, computed on the server on 2026-10-14.

| Detailed status | Channel | Key |
|---|---|---|
| Submitted | NPHIES | 2892288513816667301 |
| New | Manual | 4221634614679168790 |
| New | Not submitted | 9000259100679503054 |
| Valid | Not submitted | 8318118211403771765 |
| Posted | Manual | 5877239766880445822 |
| Posted | Not submitted | 4531730290053478704 |
| Invalid | Not submitted | 6074471015946240322 |
| Unknown | Unknown | 1591316910076942424 |

## Review Focus

1. **An invoice with no approval status on a manual purchaser** counts as Manual, not Not submitted. It is the bulk of the manual channel. Pinned in Task 1: unit test, invoice 2.
2. **A claim line whose invoice is not in AR** gets the Unknown key, not -1 or null. Otherwise SSAS would drop it from every total sliced by Claim Status (about 25K claim invoice numbers are absent from AR). Pinned in Task 3: unit test, visits 3 and 5–12.
3. **A line marked Adjudicated whose response has no matching item** gets 0 approved and 0 rejected, even though Oasis's own `outcome` says APPROVED. Only the pull response counts (R5). Pinned in Task 3: unit test, visit 7.
4. **A partially approved line whose benefit exceeds net** is not given a negative rejected amount. Pinned in Task 3: unit test, visit 12, and the singular test `assert_claim_line_amounts_add_up`.
5. **A status mapping without a `New` row** still gives the dimension its New rows, so invoices with no approval status always find their key. Pinned in Task 2: unit test (its mapping has no New row) and the `relationships` tests in Task 3.

---

## File map

```
hnh_dwh/macros/hnh/hnh_rules_claims.sql                                  Task 1  channel + key macros
hnh_dwh/models/hnh/intermediate/revenue/int_invoice_claim_status.sql     Task 1  new
hnh_dwh/models/hnh/intermediate/revenue/_revenue__models.yml             Task 1  tests
hnh_dwh/models/hnh/intermediate/revenue/_claims_unit_tests.yml           Task 1  unit test
hnh_dwh/models/hnh/marts/conformed/dim_claim_status.sql                  Task 2  new
hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml                Task 2  tests
hnh_dwh/models/hnh/marts/conformed/_claims_conformed_unit_tests.yml      Task 2  new unit test
hnh_dwh/models/hnh/marts/revenue/fact_invoice.sql                        Task 3
hnh_dwh/models/hnh/marts/revenue/fact_claim_line.sql                     Task 3
hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml              Task 3  tests
hnh_dwh/models/hnh/marts/revenue/_claims_marts_unit_tests.yml            Task 3  unit test
hnh_dwh/tests/hnh/assert_claim_line_amounts_add_up.sql                   Task 3  new
hnh_dwh/models/hnh/marts/bsc/bsc_vw_rcm.sql                              Task 4
hnh_dwh/models/hnh/marts/ssas/ssas_dim_claim_status.sql                  Task 5  new
hnh_dwh/models/hnh/marts/ssas/ssas_fact_invoice.sql                      Task 5
hnh_dwh/models/hnh/marts/ssas/ssas_fact_claim_line.sql                   Task 5
hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml                          Task 5  contracts
ssas/tools/model_config.py                                               Task 5
ssas/HNH_Analytics/tables/Claim Status.tmdl                              Task 5  generated + hierarchy
ssas/HNH_Analytics/tables/Invoices.tmdl, Claim Lines.tmdl,
  relationships.tmdl, perspectives/*                                     Task 5  generated
ssas/HNH_Analytics/tables/_Measures.tmdl                                 Task 6
ssas/tests/measures/revenue_cycle.json, claims_preauth.json              Task 6
docs/reconciliation_claim_status.md                                      Task 7, 8
docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md   Task 8 (status line)
```

---

### Task 1: Channel and key macros, `int_invoice_claim_status`

**Files:**
- Modify: `hnh_dwh/macros/hnh/hnh_rules_claims.sql` (append)
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_invoice_claim_status.sql`
- Modify: `hnh_dwh/models/hnh/intermediate/revenue/_revenue__models.yml`, `hnh_dwh/models/hnh/intermediate/revenue/_claims_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_oasis__episode_invoices` (`branch_id UInt8`, `invoice_no Int64`, `account_code Nullable(String)`, `approval_status_code Nullable(String)`); `int_code_decode` (`branch_id`, `code_type Nullable(Int32)`, `user_code Nullable(String)`, `description Nullable(String)`); `stg_ref__claim_status` (three `String` columns); `int_invoice_payer` (`branch_id`, `account_code String`, `purchaser_code Int64`); `stg_ref__purchaser_mapping` (`branch_id`, `purchaser_code Int64`, `manual_submission Nullable(String)`).
- Produces:
  - macro `hnh_claim_submission_channel(submission_status, manual_submission)` → `String`;
  - macro `hnh_claim_status_key(detailed_status, submission_channel)` → `Int64`;
  - model `int_invoice_claim_status`, grain `(branch_id, invoice_no)`, columns `branch_id UInt8, invoice_no Int64, purchaser_code Nullable(Int64), manual_submission Nullable(String), is_status_mapped UInt8, detailed_status String, submission_status String, validation_status String, submission_channel String, claim_status_key Int64`.

- [ ] **Step 1: Create the branch**

```bash
git checkout -b claim-status main
```

- [ ] **Step 2: Write the unit test**

Append to `hnh_dwh/models/hnh/intermediate/revenue/_claims_unit_tests.yml` (under the existing `unit_tests:` list, two-space indent like the others):

```yaml
  - name: int_invoice_claim_status_sets_status_and_channel
    description: >
      Claim status spec 4.1. Invoice 1: status Submitted, NPHIES. Invoice 2: no approval status on a manual
      purchaser: New, Manual. Invoice 3: no approval status on a purchaser flagged N: New, Not submitted.
      Invoice 4: Valid on a manual purchaser: Under Processing, Not submitted (the manual flag counts only for New).
      Invoice 5: a code with no decode row: Unknown, not mapped. Invoice 6: no approval status and an account with
      no purchaser: New, Not submitted. Invoice 7: Posted, matched case-insensitively ('posted'), on a manual
      purchaser: New, Manual, detailed status Posted.
    model: int_invoice_claim_status
    given:
      - input: ref('stg_oasis__episode_invoices')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(i) as invoice_no,
                 if(acc = '', cast(null as Nullable(String)), toNullable(acc)) as account_code,
                 if(code = '', cast(null as Nullable(String)), toNullable(code)) as approval_status_code
          from values('i UInt32, acc String, code String',
              (1, 'A-N', 'S'), (2, 'A-Y', ''), (3, 'A-N', ''), (4, 'A-Y', 'V'), (5, 'A-N', 'X'),
              (6, 'A-NONE', ''), (7, 'A-Y', 'P'))
      - input: ref('int_code_decode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toNullable(toInt32(5116)) as code_type, toNullable(uc) as user_code,
                 toNullable(d) as description
          from values('uc String, d String', ('S', 'Submitted'), ('V', 'Valid'), ('P', 'posted'))
      - input: ref('stg_ref__claim_status')
        format: sql
        rows: |
          select d as detailed_status, s as submission_status, v as validation_status
          from values('d String, s String, v String',
              ('Submitted', 'Submitted', 'Valid'), ('Valid', 'Under Processing', 'Valid'),
              ('Posted', 'New', 'New'), ('New', 'New', 'New'))
      - input: ref('int_invoice_payer')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, acc as account_code, toInt64(p) as purchaser_code
          from values('acc String, p UInt32', ('A-N', 300), ('A-Y', 301))
      - input: ref('stg_ref__purchaser_mapping')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(p) as purchaser_code, toNullable(f) as manual_submission
          from values('p UInt32, f String', (300, 'N'), (301, 'Y'))
    expect:
      rows:
        - {invoice_no: 1, detailed_status: Submitted, submission_status: Submitted, validation_status: Valid, is_status_mapped: 1, submission_channel: NPHIES, claim_status_key: 2892288513816667301}
        - {invoice_no: 2, detailed_status: New, submission_status: New, validation_status: New, is_status_mapped: 1, submission_channel: Manual, claim_status_key: 4221634614679168790}
        - {invoice_no: 3, detailed_status: New, submission_status: New, validation_status: New, is_status_mapped: 1, submission_channel: Not submitted, claim_status_key: 9000259100679503054}
        - {invoice_no: 4, detailed_status: Valid, submission_status: Under Processing, validation_status: Valid, is_status_mapped: 1, submission_channel: Not submitted, claim_status_key: 8318118211403771765}
        - {invoice_no: 5, detailed_status: Unknown, submission_status: Unknown, validation_status: Unknown, is_status_mapped: 0, submission_channel: Unknown, claim_status_key: 1591316910076942424}
        - {invoice_no: 6, detailed_status: New, submission_status: New, validation_status: New, is_status_mapped: 1, submission_channel: Not submitted, claim_status_key: 9000259100679503054}
        - {invoice_no: 7, detailed_status: Posted, submission_status: New, validation_status: New, is_status_mapped: 1, submission_channel: Manual, claim_status_key: 5877239766880445822}
```

The test runs in the Task 8 build. It fails there until Steps 3–4 exist (the model is missing).

- [ ] **Step 3: Add the macros**

Append to `hnh_dwh/macros/hnh/hnh_rules_claims.sql`:

```sql

{# Submission channel of an invoice (claim status spec 4.1): NPHIES for every submission status except New, Under
   Processing (detailed status Valid) and Invalid; Manual for New on a purchaser flagged manual_submission = 'Y';
   otherwise Not submitted; Unknown for an approval status the mapping does not know. #}
{% macro hnh_claim_submission_channel(submission_status, manual_submission) -%}
multiIf({{ submission_status }} = 'Unknown', 'Unknown',
        {{ submission_status }} in ('Under Processing', 'Invalid'), 'Not submitted',
        {{ submission_status }} = 'New',
            if(upper(trimBoth(ifNull({{ manual_submission }}, ''))) = 'Y', 'Manual', 'Not submitted'),
        'NPHIES')
{%- endmacro %}

{# Key of dim_claim_status: one row per detailed status and submission channel. #}
{% macro hnh_claim_status_key(detailed_status, submission_channel) -%}
{{ hnh_surrogate_key([detailed_status, submission_channel]) }}
{%- endmacro %}
```

- [ ] **Step 4: Write the model**

Create `hnh_dwh/models/hnh/intermediate/revenue/int_invoice_claim_status.sql`:

```sql
{{ config(order_by='(branch_id, invoice_no)') }}

-- Claim status and submission channel of every invoice, all history (claim status spec 4.1, 5.1). fact_invoice and
-- fact_claim_line take claim_status_key from here, so a claim line finds its invoice's status whatever the invoice date.
with approval_codes as (
    -- Code type 5116 is matched on user_code; identical in all eight branches (as fact_invoice).
    select branch_id, assumeNotNull(user_code) as user_code, any(description) as code_description
    from {{ ref('int_code_decode') }}
    where code_type = 5116 and user_code is not null
    group by branch_id, user_code
),

joined as (
    select
        i.branch_id              as branch_id,
        i.invoice_no             as invoice_no,
        i.approval_status_code   as approval_status_code,
        py.purchaser_code        as purchaser_code,
        cs.detailed_status       as mapped_detailed,
        cs.submission_status     as mapped_submission,
        cs.validation_status     as mapped_validation,
        pm.manual_submission     as manual_submission
    from {{ ref('stg_oasis__episode_invoices') }} as i
    left join approval_codes as ac
        on ac.branch_id = i.branch_id and ac.user_code = i.approval_status_code
    left join {{ ref('stg_ref__claim_status') }} as cs
        on lower(cs.detailed_status) = lower(ac.code_description)
    left join {{ ref('int_invoice_payer') }} as py
        on py.branch_id = i.branch_id and py.account_code = i.account_code
    left join {{ ref('stg_ref__purchaser_mapping') }} as pm
        on pm.branch_id = i.branch_id and pm.purchaser_code = py.purchaser_code
),

classified as (
    -- no approval status = New (rule R2); a code the mapping does not know = Unknown
    select
        branch_id, invoice_no, purchaser_code, manual_submission,
        toUInt8(approval_status_code is null or mapped_detailed is not null)                                       as is_status_mapped,
        multiIf(approval_status_code is null, 'New', mapped_detailed is null, 'Unknown', assumeNotNull(mapped_detailed))   as detailed_status,
        multiIf(approval_status_code is null, 'New', mapped_detailed is null, 'Unknown', assumeNotNull(mapped_submission)) as submission_status,
        multiIf(approval_status_code is null, 'New', mapped_detailed is null, 'Unknown', assumeNotNull(mapped_validation)) as validation_status
    from joined
)

select
    branch_id,
    invoice_no,
    purchaser_code,
    manual_submission,
    is_status_mapped,
    detailed_status,
    submission_status,
    validation_status,
    {{ hnh_claim_submission_channel('submission_status', 'manual_submission') }}   as submission_channel,
    {{ hnh_claim_status_key('detailed_status', 'submission_channel') }}           as claim_status_key
from classified
{{ hnh_settings() }}
```

- [ ] **Step 5: Add the model tests**

In `hnh_dwh/models/hnh/intermediate/revenue/_revenue__models.yml`, insert after the `int_invoice_payer` block (after its `columns: [branch_id, account_code]` line and the blank line):

```yaml
  - name: int_invoice_claim_status
    description: >
      Claim status (validation, submission, detailed) and submission channel of every invoice, all history
      (claim status spec 4.1). claim_status_key joins dim_claim_status.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, invoice_no]
    columns:
      - name: claim_status_key
        tests: [not_null]
      - name: submission_channel
        tests:
          - accepted_values:
              values: ['NPHIES', 'Manual', 'Not submitted', 'Unknown']

```

- [ ] **Step 6: Check the logic on gold (read-only)**

The model cannot be rendered here (macros), so run its logic as a query. Expected: the channel split of invoices dated 2026-01-01 to 2026-08-31 matches spec section 2. That is NPHIES SAR ≈ 873.0m, and New split as Manual SAR ≈ 108.1m / 17,040 invoices and Not submitted SAR ≈ 449.8m plus the Under Processing and Invalid invoices. Unknown is 0.

```powershell
Import-Module D:\new_dwh_modeling\scripts\HnhCh.psm1 -Force
$sql = @'
SELECT channel, count() AS invoices, round(sum(net)) AS net_sar FROM (
  SELECT f.net_amount AS net,
         multiIf(f.submission_status IN ('Under Processing', 'Invalid'), 'Not submitted',
                 f.submission_status = 'New', if(upper(trimBoth(ifNull(pm.manual_submission, ''))) = 'Y', 'Manual', 'Not submitted'),
                 'NPHIES') AS channel
  FROM gold.fact_invoice AS f
  LEFT JOIN stg.stg_ref__purchaser_mapping AS pm ON pm.branch_id = f.branch_key AND pm.purchaser_code = f.purchaser_code
  WHERE f.invoice_date_key BETWEEN 20260101 AND 20260831
) GROUP BY channel ORDER BY channel
'@
Invoke-HnhSelect -Dsn HNH_Gold -Sql $sql | Format-Table -AutoSize
```

Record the four rows. Task 7 compares them with the built model.

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_claims.sql hnh_dwh/models/hnh/intermediate/revenue/int_invoice_claim_status.sql hnh_dwh/models/hnh/intermediate/revenue/_revenue__models.yml hnh_dwh/models/hnh/intermediate/revenue/_claims_unit_tests.yml
git commit -m "Add int_invoice_claim_status: claim status and submission channel per invoice

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `dim_claim_status`

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_claim_status.sql`, `hnh_dwh/models/hnh/marts/conformed/_claims_conformed_unit_tests.yml`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`

**Interfaces:**
- Consumes: macros `hnh_claim_submission_channel`, `hnh_claim_status_key` (Task 1); `stg_ref__claim_status`.
- Produces: model `dim_claim_status`, columns `claim_status_key Int64, validation_status String, submission_status String, detailed_status String, submission_channel String, is_submitted UInt8`; one row per key.

- [ ] **Step 1: Write the unit test**

Create `hnh_dwh/models/hnh/marts/conformed/_claims_conformed_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: dim_claim_status_lists_each_status_with_its_channels
    description: >
      Claim status spec 4.1, 5.2. The mapping has no New row, but New is still added (invoices with no approval
      status use it). Statuses under submission status New (Posted, New) get Manual and Not submitted; Under
      Processing and Invalid get Not submitted; Submitted gets NPHIES; Unknown is added once.
    model: dim_claim_status
    given:
      - input: ref('stg_ref__claim_status')
        format: sql
        rows: |
          select d as detailed_status, s as submission_status, v as validation_status
          from values('d String, s String, v String',
              ('Submitted', 'Submitted', 'Valid'), ('Valid', 'Under Processing', 'Valid'),
              ('Invalid', 'Invalid', 'Invalid'), ('Posted', 'New', 'New'))
    expect:
      rows:
        - {claim_status_key: 2892288513816667301, detailed_status: Submitted, submission_status: Submitted, validation_status: Valid, submission_channel: NPHIES, is_submitted: 1}
        - {claim_status_key: 8318118211403771765, detailed_status: Valid, submission_status: Under Processing, validation_status: Valid, submission_channel: Not submitted, is_submitted: 0}
        - {claim_status_key: 6074471015946240322, detailed_status: Invalid, submission_status: Invalid, validation_status: Invalid, submission_channel: Not submitted, is_submitted: 0}
        - {claim_status_key: 5877239766880445822, detailed_status: Posted, submission_status: New, validation_status: New, submission_channel: Manual, is_submitted: 1}
        - {claim_status_key: 4531730290053478704, detailed_status: Posted, submission_status: New, validation_status: New, submission_channel: Not submitted, is_submitted: 0}
        - {claim_status_key: 4221634614679168790, detailed_status: New, submission_status: New, validation_status: New, submission_channel: Manual, is_submitted: 1}
        - {claim_status_key: 9000259100679503054, detailed_status: New, submission_status: New, validation_status: New, submission_channel: Not submitted, is_submitted: 0}
        - {claim_status_key: 1591316910076942424, detailed_status: Unknown, submission_status: Unknown, validation_status: Unknown, submission_channel: Unknown, is_submitted: 0}
```

- [ ] **Step 2: Write the model**

Create `hnh_dwh/models/hnh/marts/conformed/dim_claim_status.sql`:

```sql
{{ config(order_by='claim_status_key') }}

-- One row per detailed status and each submission channel it can have (claim status spec 4.1, 5.2). New is added
-- even when the mapping has no New row (invoices with no approval status use it); Unknown is for codes the mapping
-- does not know. The channel comes from the same macro as int_invoice_claim_status, over both manual flags.
with statuses as (
    select detailed_status, submission_status, validation_status from {{ ref('stg_ref__claim_status') }}
    union distinct
    select 'New' as detailed_status, 'New' as submission_status, 'New' as validation_status
    union distinct
    select 'Unknown' as detailed_status, 'Unknown' as submission_status, 'Unknown' as validation_status
),

channels as (
    select distinct
        s.detailed_status                                                       as detailed_status,
        s.submission_status                                                     as submission_status,
        s.validation_status                                                     as validation_status,
        {{ hnh_claim_submission_channel('s.submission_status', 'f.flag') }}     as submission_channel
    from statuses as s
    cross join (select arrayJoin(['Y', 'N']) as flag) as f
)

select
    {{ hnh_claim_status_key('detailed_status', 'submission_channel') }}  as claim_status_key,
    validation_status,
    submission_status,
    detailed_status,
    submission_channel,
    toUInt8(submission_channel in ('NPHIES', 'Manual'))                  as is_submitted
from channels
```

- [ ] **Step 3: Add the model tests**

In `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`, insert after the `dim_nphies_reason` block (its `tests: [unique, not_null]` line):

```yaml
  - name: dim_claim_status
    description: >
      Claim status of invoices and claim lines: validation, submission and detailed status from map_claim_status,
      and the submission channel (claim status spec 4.1). One row per detailed status and channel.
    columns:
      - name: claim_status_key
        tests: [unique, not_null]
      - name: submission_channel
        tests:
          - accepted_values:
              values: ['NPHIES', 'Manual', 'Not submitted', 'Unknown']
```

- [ ] **Step 4: Check the rows on gold (read-only)**

Run the dimension's logic on the live mapping (14 rows). Expected:
- New and Posted (submission status New; the added New row is deduplicated) give Manual and Not submitted: 4 rows.
- Valid (Under Processing) and Invalid give Not submitted: 2 rows.
- The 10 other statuses give NPHIES: 10 rows.
- Unknown: 1 row.
- Total 17, and keys are unique (`rows = keys`). Checked on 2026-10-14: 17 / 17.

```powershell
Import-Module D:\new_dwh_modeling\scripts\HnhCh.psm1 -Force
$sql = @'
SELECT count() AS rows, uniqExact(detailed_status, channel) AS keys, groupArray(concat(detailed_status, '/', channel)) AS combos FROM (
  SELECT DISTINCT s.detailed_status AS detailed_status,
         multiIf(s.submission_status = 'Unknown', 'Unknown', s.submission_status IN ('Under Processing', 'Invalid'), 'Not submitted',
                 s.submission_status = 'New', if(f.flag = 'Y', 'Manual', 'Not submitted'), 'NPHIES') AS channel
  FROM (SELECT detailed_status, submission_status FROM stg.stg_ref__claim_status
        UNION DISTINCT SELECT 'New', 'New' UNION DISTINCT SELECT 'Unknown', 'Unknown') AS s
  CROSS JOIN (SELECT arrayJoin(['Y', 'N']) AS flag) AS f
)
'@
Invoke-HnhSelect -Dsn HNH_Gold -Sql $sql | Format-List
```

Expected: `rows = 17`, `keys = 17`.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed/dim_claim_status.sql hnh_dwh/models/hnh/marts/conformed/_claims_conformed_unit_tests.yml hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml
git commit -m "Add dim_claim_status: each claim status with its submission channels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Claim status key on both facts, new claim line amounts

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/revenue/fact_invoice.sql`, `hnh_dwh/models/hnh/marts/revenue/fact_claim_line.sql`
- Modify: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`, `hnh_dwh/models/hnh/marts/revenue/_claims_marts_unit_tests.yml`
- Create: `hnh_dwh/tests/hnh/assert_claim_line_amounts_add_up.sql`

**Interfaces:**
- Consumes: `int_invoice_claim_status` (`branch_id`, `invoice_no`, `submission_channel`, `claim_status_key`); macro `hnh_claim_status_key`.
- Produces:
  - `fact_invoice`: new `claim_status_key Int64` (after `care_type_key`) and `submission_channel String` (after `validation_status`).
  - `fact_claim_line`: new `claim_status_key Int64` (after `nphies_reason_key`) and `response_benefit_amount Nullable(Float64)` (after `rejected_amount`).
  - `fact_claim_line.approved_amount` and `rejected_amount` become `Float64`, never null.

- [ ] **Step 1: Update the fact_claim_line unit test**

In `hnh_dwh/models/hnh/marts/revenue/_claims_marts_unit_tests.yml`, test `fact_claim_line_applies_adjudication_rules`.

Replace the `description:` block with:

```yaml
    description: >
      Claim status spec 4.2: approved = net if approved, the benefit if partially approved; rejected = net if
      rejected, net - benefit (not below 0) if partially approved; 0 and 0 without an adjudicated response item.
      Invoice 500: visit 1 (submission 1) was rejected with BE-1-3; visit 2 (latest) was partially approved
      without a reason. Visit 3 was sent but not answered (0 / 0). Visit 4 (invoice 700): line 1 approved with a
      co-pay (approved = net 30, not the benefit 24); line 2 rejected with no reason in the response but MN-1-1 in
      the notes. Visit 5: approved item without an eligible amount (approved = net 50). Visit 6: rejected item.
      Visit 7: marked Adjudicated but its response has no matching item, so its Oasis outcome APPROVED does not
      count (0 / 0). Visit 8: PARTIAL line whose response carries a reason-bearing adjudication (legacy approved =
      its benefit). Visit 9: partially approved item without a submitted amount. Visit 10: Error status, so the
      reason code and amounts on its response item are ignored. Visit 11: partially approved; net 100 excludes VAT
      while the response's submitted 115 includes 15 tax (rejected 36). Visit 12: partially approved with a
      benefit (120) above net (100): approved 120, rejected 0. Invoices 500 and 700 have a claim status (keys 11
      and 22); the other invoices are not in AR and get the Unknown key. Only invoice 500 under transaction 1002
      is on an AR statement, so only visit 2 is in the old models' scope.
```

In the `stg_oasis__claim_services` input, replace the `from values(...)` rows with:

```yaml
          from values('v UInt32, sq UInt32, net Float64, oc String, nt String',
              (1, 1, 100, 'REJECTED', ''), (2, 1, 100, 'PARTIAL', ''), (3, 1, 50, '', ''),
              (4, 1, 30, 'APPROVED', ''), (4, 2, 40, 'REJECTED', '- MN-1-1 not justified'),
              (5, 1, 50, 'APPROVED', ''), (6, 1, 60, 'REJECTED', ''), (7, 1, 70, 'APPROVED', ''), (7, 2, 20, '', ''),
              (8, 1, 100, 'PARTIAL', ''), (9, 1, 90, 'PARTIAL', ''), (10, 1, 40, 'REJECTED', ''), (11, 1, 100, 'PARTIAL', ''),
              (12, 1, 100, 'PARTIAL', ''))
```

In the `int_claim_submission` input, replace the `from values(...)` rows with:

```yaml
          from values('v UInt32, inv UInt32, sn UInt32, lt UInt8, fr UInt32, st String',
              (1, 500, 1, 0, 9001, 'Adjudicated'), (2, 500, 2, 1, 9002, 'Adjudicated'),
              (3, 600, 1, 1, 0, 'No response'), (4, 700, 1, 1, 9004, 'Adjudicated'),
              (5, 800, 1, 1, 9005, 'Adjudicated'), (6, 810, 1, 1, 9006, 'Adjudicated'),
              (7, 820, 1, 1, 9007, 'Adjudicated'), (8, 830, 1, 1, 9008, 'Adjudicated'),
              (9, 840, 1, 1, 9009, 'Adjudicated'), (10, 850, 1, 1, 9010, 'Error'), (11, 860, 1, 1, 9011, 'Adjudicated'),
              (12, 870, 1, 1, 9012, 'Adjudicated'))
```

In the `int_nphies_adjudication` input, add the row `(9012, 1, 'Partially approved', 100, 100, 120, 0, '', 0)` after the `9011` row:

```yaml
              (9011, 1, 'Partially approved', 115, 80, 64, 16, '', 15),
              (9012, 1, 'Partially approved', 100, 100, 120, 0, '', 0))
```

Add this input after the `int_nphies_adjudication` input:

```yaml
      - input: ref('int_invoice_claim_status')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(i) as invoice_no, toInt64(k) as claim_status_key
          from values('i UInt32, k Int64', (500, 11), (700, 22))
```

Replace the whole `expect: rows:` list with:

```yaml
    expect:
      rows:
        - {visit_id: 1, sequence_no: 1, is_latest_submission: 0, submitted_amount: 100, adjudication_status: Adjudicated, item_outcome: Rejected, approved_amount: 0, rejected_amount: 100, response_benefit_amount: 0, reason_source: NPHIES response, primary_reason_code: BE-1-3, legacy_approved_amount: 0, legacy_rejected_amount: 100, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 11}
        - {visit_id: 2, sequence_no: 1, is_latest_submission: 1, submitted_amount: 100, adjudication_status: Adjudicated, item_outcome: Partially approved, approved_amount: 64, rejected_amount: 36, response_benefit_amount: 64, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 100, care_type_key: 1, legacy_in_scope: 1, claim_status_key: 11}
        - {visit_id: 3, sequence_no: 1, is_latest_submission: 1, submitted_amount: null, adjudication_status: No response, item_outcome: Not adjudicated, approved_amount: 0, rejected_amount: 0, response_benefit_amount: null, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 50, legacy_rejected_amount: 0, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 4, sequence_no: 1, is_latest_submission: 1, submitted_amount: 30, adjudication_status: Adjudicated, item_outcome: Approved, approved_amount: 30, rejected_amount: 0, response_benefit_amount: 24, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 30, legacy_rejected_amount: 0, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 22}
        - {visit_id: 4, sequence_no: 2, is_latest_submission: 1, submitted_amount: 40, adjudication_status: Adjudicated, item_outcome: Rejected, approved_amount: 0, rejected_amount: 40, response_benefit_amount: 0, reason_source: Claim notes, primary_reason_code: MN-1-1, legacy_approved_amount: 0, legacy_rejected_amount: 40, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 22}
        - {visit_id: 5, sequence_no: 1, is_latest_submission: 1, submitted_amount: 50, adjudication_status: Adjudicated, item_outcome: Approved, approved_amount: 50, rejected_amount: 0, response_benefit_amount: 40, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 50, legacy_rejected_amount: 0, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 6, sequence_no: 1, is_latest_submission: 1, submitted_amount: 60, adjudication_status: Adjudicated, item_outcome: Rejected, approved_amount: 0, rejected_amount: 60, response_benefit_amount: 0, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 60, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 7, sequence_no: 1, is_latest_submission: 1, submitted_amount: null, adjudication_status: Adjudicated, item_outcome: Approved, approved_amount: 0, rejected_amount: 0, response_benefit_amount: null, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 70, legacy_rejected_amount: 0, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 7, sequence_no: 2, is_latest_submission: 1, submitted_amount: null, adjudication_status: Adjudicated, item_outcome: Not adjudicated, approved_amount: 0, rejected_amount: 0, response_benefit_amount: null, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 20, legacy_rejected_amount: 0, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 8, sequence_no: 1, is_latest_submission: 1, submitted_amount: 100, adjudication_status: Adjudicated, item_outcome: Partially approved, approved_amount: 64, rejected_amount: 36, response_benefit_amount: 64, reason_source: NPHIES response, primary_reason_code: BE-1-3, legacy_approved_amount: 64, legacy_rejected_amount: 36, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 9, sequence_no: 1, is_latest_submission: 1, submitted_amount: 90, adjudication_status: Adjudicated, item_outcome: Partially approved, approved_amount: 50, rejected_amount: 40, response_benefit_amount: 50, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 90, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 10, sequence_no: 1, is_latest_submission: 1, submitted_amount: null, adjudication_status: Error, item_outcome: Rejected, approved_amount: 0, rejected_amount: 0, response_benefit_amount: null, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 40, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 11, sequence_no: 1, is_latest_submission: 1, submitted_amount: 115, adjudication_status: Adjudicated, item_outcome: Partially approved, approved_amount: 64, rejected_amount: 36, response_benefit_amount: 64, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 100, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
        - {visit_id: 12, sequence_no: 1, is_latest_submission: 1, submitted_amount: 100, adjudication_status: Adjudicated, item_outcome: Partially approved, approved_amount: 120, rejected_amount: 0, response_benefit_amount: 120, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 100, care_type_key: 1, legacy_in_scope: 0, claim_status_key: 1591316910076942424}
```

- [ ] **Step 2: Change the fact_claim_line amounts**

In `hnh_dwh/models/hnh/marts/revenue/fact_claim_line.sql`, replace:

```sql
    if(k.has_adjudication = 1, ifNull(k.response_benefit, 0), null)         as approved_amount,
```

with:

```sql
    -- claim status spec 4.2: by the line's response outcome; 0 without an adjudicated response item
    multiIf(k.has_adjudication = 0, 0,
            k.response_outcome = 'Approved', k.net_amount,
            k.response_outcome = 'Partially approved', ifNull(k.response_benefit, 0),
            0)                                                              as approved_amount,
```

Replace the block from `    -- payers omit eligible on approved items and send eligible = submitted on rejected ones, so go by outcome;` down to and including `       null)                                                                as rejected_amount,` with:

```sql
    multiIf(k.has_adjudication = 0, 0,
            k.response_outcome = 'Rejected', k.net_amount,
            k.response_outcome = 'Partially approved', greatest(k.net_amount - ifNull(k.response_benefit, 0), 0),
            0)                                                              as rejected_amount,
    if(k.has_adjudication = 1, k.response_benefit, null)                    as response_benefit_amount,
```

- [ ] **Step 3: Add the claim status key to fact_claim_line**

In the same file, after the line:

```sql
    if(k.primary_reason_code is null, toInt64(0), ifNull(dr.nphies_reason_key, toInt64(-1))) as nphies_reason_key,
```

insert:

```sql
    -- status of the line's invoice (claim status spec 5.4); Unknown when the claim invoice is not in AR
    ifNull(ics.claim_status_key, {{ hnh_claim_status_key("'Unknown'", "'Unknown'") }}) as claim_status_key,
```

After the line:

```sql
    on dr.nphies_reason_key = {{ hnh_surrogate_key(['k.primary_reason_code']) }}
```

insert:

```sql
left join (select branch_id, invoice_no, claim_status_key from {{ ref('int_invoice_claim_status') }}) as ics
    on ics.branch_id = k.branch_id and ics.invoice_no = k.claim_invoice_no
```

- [ ] **Step 4: Add the claim status to fact_invoice**

In `hnh_dwh/models/hnh/marts/revenue/fact_invoice.sql`, in the `enriched` CTE replace:

```sql
        py.purchaser_code      as purchaser_code,
        ep.care_type           as episode_care_type
```

with:

```sql
        py.purchaser_code      as purchaser_code,
        ep.care_type           as episode_care_type,
        ics.submission_channel as submission_channel,
        ics.claim_status_key   as claim_status_key
```

After:

```sql
    left join (select branch_id, patient_id, episode_no, care_type from {{ ref('int_episode') }}) as ep
        on ep.branch_id = i.branch_id and ep.patient_id = i.patient_id and ep.episode_no = i.episode_no
)
```

change it so the new join sits before the closing parenthesis:

```sql
    left join (select branch_id, patient_id, episode_no, care_type from {{ ref('int_episode') }}) as ep
        on ep.branch_id = i.branch_id and ep.patient_id = i.patient_id and ep.episode_no = i.episode_no
    left join (select branch_id, invoice_no, submission_channel, claim_status_key from {{ ref('int_invoice_claim_status') }}) as ics
        on ics.branch_id = i.branch_id and ics.invoice_no = i.invoice_no
)
```

In the final select, after:

```sql
    {{ hnh_care_type_key(hnh_charge_care_type('e.episode_care_type', 'e.attendance_type')) }} as care_type_key,
```

insert:

```sql
    ifNull(e.claim_status_key, {{ hnh_claim_status_key("'Unknown'", "'Unknown'") }}) as claim_status_key,
```

After:

```sql
    ifNull(e.validation_status, 'New')                                      as validation_status,
```

insert:

```sql
    ifNull(e.submission_channel, 'Unknown')                                 as submission_channel,
```

- [ ] **Step 5: Add the column tests**

In `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`, `fact_invoice` block, after the `care_type_key` test:

```yaml
      - name: claim_status_key
        tests:
          - not_null
          - relationships: {to: ref('dim_claim_status'), field: claim_status_key}
      - name: submission_channel
        tests:
          - accepted_values:
              values: ['NPHIES', 'Manual', 'Not submitted', 'Unknown']
```

In the `fact_claim_line` block, after the `nphies_reason_key` test:

```yaml
      - name: claim_status_key
        tests:
          - not_null
          - relationships: {to: ref('dim_claim_status'), field: claim_status_key}
      - name: approved_amount
        tests: [not_null]
      - name: rejected_amount
        tests: [not_null]
```

- [ ] **Step 6: Add the singular test**

Create `hnh_dwh/tests/hnh/assert_claim_line_amounts_add_up.sql`:

```sql
-- Claim status spec 4.2: a line's approved + rejected is 0 (no NPHIES decision) or its net amount, except a partially
-- approved line whose benefit exceeds net (approved = benefit, rejected = 0). Nets can be negative (credit lines).
select claim_line_key, item_outcome, adjudication_status, claimed_amount, approved_amount, rejected_amount
from {{ ref('fact_claim_line') }}
where not (
    abs(approved_amount + rejected_amount) < 0.01
    or abs(approved_amount + rejected_amount - claimed_amount) < 0.01
    or (item_outcome = 'Partially approved' and rejected_amount = 0 and approved_amount > claimed_amount)
)
```

- [ ] **Step 7: Check the new amounts on gold (read-only)**

Run the new rules against today's `fact_claim_line`. Its `submitted_amount` is non-null exactly when `has_adjudication = 1`, and today's `approved_amount` on a partial line is the benefit. Expected for statement end 2026-01-01 to 2026-08-31, latest not cancelled:
- approved from Approved lines ≈ SAR 547.56m (spec section 2);
- `bad_rows = 0` (every decided line adds up to net or is a partial over-benefit line).

```powershell
Import-Module D:\new_dwh_modeling\scripts\HnhCh.psm1 -Force
$sql = @'
SELECT round(sum(ap)) AS approved_sar, round(sum(rj)) AS rejected_sar, round(sumIf(ap, item_outcome = 'Approved')) AS approved_from_approved_lines,
       countIf(NOT (abs(ap + rj) < 0.01 OR abs(ap + rj - claimed_amount) < 0.01 OR (item_outcome = 'Partially approved' AND rj = 0 AND ap > claimed_amount))) AS bad_rows
FROM (
  SELECT item_outcome, claimed_amount,
         multiIf(submitted_amount IS NULL, 0, item_outcome = 'Approved', claimed_amount, item_outcome = 'Partially approved', ifNull(approved_amount, 0), 0) AS ap,
         multiIf(submitted_amount IS NULL, 0, item_outcome = 'Rejected', claimed_amount, item_outcome = 'Partially approved', greatest(claimed_amount - ifNull(approved_amount, 0), 0), 0) AS rj
  FROM gold.fact_claim_line
  WHERE is_latest_submission = 1 AND is_cancelled_claim = 0 AND statement_end_date_key BETWEEN 20260101 AND 20260831
)
'@
Invoke-HnhSelect -Dsn HNH_Gold -Sql $sql | Format-List
```

Record `approved_sar` and `rejected_sar` in Task 7; the built model must give the same totals.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/models/hnh/marts/revenue/fact_invoice.sql hnh_dwh/models/hnh/marts/revenue/fact_claim_line.sql hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml hnh_dwh/models/hnh/marts/revenue/_claims_marts_unit_tests.yml hnh_dwh/tests/hnh/assert_claim_line_amounts_add_up.sql
git commit -m "Claim status key on invoices and claim lines; approved and rejected by response outcome

Approved = net of approved lines and the benefit of partially approved ones; rejected = net of
rejected lines and net - benefit (not below 0) of partially approved ones; 0 without an adjudicated
response item. The benefit stays as response_benefit_amount.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `bsc_vw_rcm` rates over approved + rejected

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/bsc/bsc_vw_rcm.sql`

**Interfaces:**
- Consumes: `fact_claim_line.approved_amount`, `rejected_amount` (Task 3).
- Produces: same columns and types as today (the contract in `_bsc__models.yml` does not change).

- [ ] **Step 1: Change the denominators**

In `hnh_dwh/models/hnh/marts/bsc/bsc_vw_rcm.sql`:

Replace the header comment line:

```sql
-- F9); rates are over adjudicated submitted. Pre-authorisation by request month, payer advances left out.
```

with:

```sql
-- F9); rates are over approved + rejected (claim status spec 4.2). Pre-authorisation by request month, payer advances left out.
```

Remove these lines from the `claims` CTE (the `rejected` line keeps its comma removed):

```sql
        sumIf(ifNull(rejected_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0)   as rejected,
        sumIf(ifNull(submitted_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0
                                           and adjudication_status = 'Adjudicated')              as adjudicated_submitted
```

and put back:

```sql
        sumIf(ifNull(rejected_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0)   as rejected
```

Replace:

```sql
    round(100 * c.rejected / nullIf(c.adjudicated_submitted, 0), 2)             as rejection_rate_pct,
    round(100 * c.approved / nullIf(c.adjudicated_submitted, 0), 2)             as approval_rate_pct,
```

with:

```sql
    round(100 * c.rejected / nullIf(c.approved + c.rejected, 0), 2)             as rejection_rate_pct,
    round(100 * c.approved / nullIf(c.approved + c.rejected, 0), 2)             as approval_rate_pct,
```

- [ ] **Step 2: Check the rates on gold (read-only)**

`render_model_sql.py` renders `bsc_vw_rcm` (it uses only `var()`, `ref()` and `config()`), but `fact_claim_line` is not rebuilt yet, so the rates will still use today's amounts. Check only that the view still runs and keeps its columns:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\check_bsc_contract.ps1 -Model bsc_vw_rcm
```

Expected: no column or type differences reported.

- [ ] **Step 3: Commit**

```bash
git add hnh_dwh/models/hnh/marts/bsc/bsc_vw_rcm.sql
git commit -m "bsc.vw_rcm: rejection and approval rates over approved + rejected

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: SSAS table Claim Status and its relationships

**Files:**
- Create: `hnh_dwh/models/hnh/marts/ssas/ssas_dim_claim_status.sql`
- Modify: `hnh_dwh/models/hnh/marts/ssas/ssas_fact_invoice.sql`, `hnh_dwh/models/hnh/marts/ssas/ssas_fact_claim_line.sql`, `hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml`, `ssas/tools/model_config.py`
- Generated: `ssas/HNH_Analytics/tables/Claim Status.tmdl`, `Invoices.tmdl`, `Claim Lines.tmdl`, `relationships.tmdl`, `model.tmdl`, `perspectives/*`
- Modify after generation: `ssas/HNH_Analytics/tables/Claim Status.tmdl` (hierarchy)

**Interfaces:**
- Consumes: `dim_claim_status`, `fact_invoice.claim_status_key`, `fact_claim_line.claim_status_key`, `response_benefit_amount` (Tasks 2–3).
- Produces:
  - SSAS table `'Claim Status'` with columns `'Validation Status'`, `'Submission Status'`, `'Detailed Status'`, `'Submission Channel'`, `'Is Submitted'` and hierarchy `'Claim Status'`;
  - relationships `Invoices[Claim Status Key]` → `'Claim Status'[Claim Status Key]` and `'Claim Lines'[Claim Status Key]` → `'Claim Status'[Claim Status Key]`;
  - column `'Claim Lines'[Response Benefit Amount]`.

- [ ] **Step 1: The SSAS views**

Create `hnh_dwh/models/hnh/marts/ssas/ssas_dim_claim_status.sql`:

```sql
{{ hnh_ssas_view('dim_claim_status') }}
```

Replace `hnh_dwh/models/hnh/marts/ssas/ssas_fact_invoice.sql` with:

```sql
{{ hnh_ssas_view('fact_invoice', drop=['invoice_key', 'episode_key', 'submission_channel'], decimals=['gross_amount', 'discount_amount', 'net_amount', 'vat_amount', 'total_amount']) }}
```

Replace `hnh_dwh/models/hnh/marts/ssas/ssas_fact_claim_line.sql` with:

```sql
{{ hnh_ssas_view('fact_claim_line', drop=['claim_line_key', 'episode_key', 'invoice_key', 'visit_id', 'sequence_no', 'claim_invoice_no', 'stat_invoice_no', 'service_code', 'reason_codes'], decimals=['claimed_amount', 'submitted_amount', 'eligible_amount', 'approved_amount', 'copay_amount', 'deductible_amount', 'patient_share_amount', 'tax_amount', 'rejected_amount', 'response_benefit_amount'], floats=['approved_qty']) }}
```

- [ ] **Step 2: The contracts**

`gen_view_contracts.py` needs `clickhouse_connect`, which is not on this server, so edit `hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml` by hand. Column order follows the model (`hnh_ssas_view` keeps it).

Insert directly before `  - name: ssas_dim_date` (after the `ssas_dim_care_type` block; the `ssas_dim_*` blocks are alphabetical):

```yaml
  - name: ssas_dim_claim_status
    config:
      contract: {enforced: true}
    columns:
      - name: claim_status_key
        data_type: "Int64"
      - name: validation_status
        data_type: "String"
      - name: submission_status
        data_type: "String"
      - name: detailed_status
        data_type: "String"
      - name: submission_channel
        data_type: "String"
      - name: is_submitted
        data_type: "String"
```

In the `ssas_fact_invoice` block, after the `care_type_key` column (`data_type: "Int64"`), insert:

```yaml
      - name: claim_status_key
        data_type: "Int64"
```

In the `ssas_fact_claim_line` block, after the `nphies_reason_key` column, insert:

```yaml
      - name: claim_status_key
        data_type: "Int64"
```

and after the `rejected_amount` column (the block's last), insert:

```yaml
      - name: response_benefit_amount
        data_type: "Nullable(Decimal(18, 4))"
```

- [ ] **Step 3: Register the table**

In `ssas/tools/model_config.py`, after:

```python
    Table("ssas_dim_nphies_reason", "NPHIES Reason", "dim", "NPHIES adjudication and rejection reasons."),
```

insert:

```python
    Table("ssas_dim_claim_status", "Claim Status", "dim", "Claim status (validation, submission, detailed) and submission channel of invoices and claim lines."),
```

After:

```python
    "preauth_outcome_key": ("Pre-auth Outcome", "preauth_outcome_key"),
```

insert:

```python
    "claim_status_key": ("Claim Status", "claim_status_key"),
```

- [ ] **Step 4: Generate the TMDL**

Run: `python ssas/tools/generate.py --from-contracts`
Expected: `columns from the dbt contracts; sortByColumn pairs not checked (needs ClickHouse)` and no error.

Run: `git status --short ssas/HNH_Analytics`
Expected:
- new `tables/Claim Status.tmdl`;
- modified `tables/Invoices.tmdl`, `tables/Claim Lines.tmdl`, `relationships.tmdl`, `model.tmdl`;
- modified perspective files: Executive, Revenue Cycle, Claims & Pre-auth and Patient Details (each perspective gets every dimension its facts reach).

Run: `grep -n "Claim Status" ssas/HNH_Analytics/relationships.tmdl`
Expected: two relationships, from `Invoices.'Claim Status Key'` and `'Claim Lines'.'Claim Status Key'` to `'Claim Status'.'Claim Status Key'`.

- [ ] **Step 5: Add the hierarchy**

In `ssas/HNH_Analytics/tables/Claim Status.tmdl`, insert directly after the `table 'Claim Status'` line (tabs, as in `tables/Date.tmdl`):

```
	hierarchy 'Claim Status'

		level 'Validation Status'
			column: 'Validation Status'

		level 'Submission Status'
			column: 'Submission Status'

		level 'Detailed Status'
			column: 'Detailed Status'

```

Run `python ssas/tools/generate.py --from-contracts` again, then `git diff --stat "ssas/HNH_Analytics/tables/Claim Status.tmdl"`.
Expected: the hierarchy is still there (the generator keeps hierarchy blocks). If the generator moved it, accept its placement.

- [ ] **Step 6: Offline checks**

Run: `python -m pytest ssas/tools -q`
Expected: all pass.

Run: `& "C:\Program Files (x86)\Tabular Editor\TabularEditor.exe" ssas\HNH_Analytics -A ssas\bpa_rules.json -V`
Expected: no line with `type=error`.

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/models/hnh/marts/ssas ssas/tools/model_config.py ssas/HNH_Analytics
git commit -m "SSAS: Claim Status table with its hierarchy, related to Invoices and Claim Lines

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Billed measures and the rejection rates

**Files:**
- Modify: `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/tests/measures/revenue_cycle.json`, `ssas/tests/measures/claims_preauth.json`
- Regenerated by tools: guard wrappers in `_Measures.tmdl`, perspective measure lists

**Interfaces:**
- Consumes: `'Claim Status'[Submission Channel]`, `'Claim Lines'[Approved Amount]`, `[Rejected Amount]` (Task 5).
- Produces: measures `'Billed Statements'`, `'Billed Submitted to NPHIES'`, `'Billed Manual'`, `'Billed Not Submitted'`; redefined `'Claim Rejection Rate %'`, `'First-pass Rejection Rate %'`.

- [ ] **Step 1: Write the measure checks**

In `ssas/tests/measures/revenue_cycle.json`, after the `Verified Billed Amount, branch 1, 2026-08` entry (keep the comma between entries), add:

```json
  {"name": "Billed Statements, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Billed Statements], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901"},
  {"name": "Billed Submitted to NPHIES, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Billed Submitted to NPHIES], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901 and claim_status_key in (select claim_status_key from gold.ssas_dim_claim_status where submission_channel = 'NPHIES')"},
  {"name": "Billed Manual, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Billed Manual], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901 and claim_status_key in (select claim_status_key from gold.ssas_dim_claim_status where submission_channel = 'Manual')"},
  {"name": "Billed Not Submitted, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Billed Not Submitted], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901 and claim_status_key in (select claim_status_key from gold.ssas_dim_claim_status where submission_channel = 'Not submitted')"},
  {"name": "Billed Statements, branch 1, 2026-08, Submission Status Submitted (hierarchy slice)", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Billed Statements], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608, 'Claim Status'[Submission Status] = \"Submitted\"))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901 and claim_status_key in (select claim_status_key from gold.ssas_dim_claim_status where submission_status = 'Submitted')"},
```

In `ssas/tests/measures/claims_preauth.json`, replace the `Claim Rejection Rate %, branch 1, 2026-06` entry's `sql` with:

```
select sum(rejected_amount) / (sum(approved_amount) + sum(rejected_amount)) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No' and adjudication_status = 'Adjudicated'
```

and the `First-pass Rejection Rate %, branch 1, 2026-06` entry's `sql` with:

```
select sum(rejected_amount) / (sum(approved_amount) + sum(rejected_amount)) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and submission_number = 1 and adjudication_status = 'Adjudicated'
```

Add after the `Claims Rejected, branch 1, 2026-06` entry (one line, like its neighbours):

```json
  {"name": "Claims Rejected, branch 1, 2026-06, channel NPHIES (Claim Status filters claim lines)", "tolerance": 0.01, "dax": "EVALUATE ROW(\"v\", CALCULATE([Claims Rejected], Branch[Branch Key] = 1, 'Date'[Year Month] = 202606, 'Claim Status'[Submission Channel] = \"NPHIES\"))", "sql": "select sum(rejected_amount) from gold.ssas_fact_claim_line where branch_key = 1 and statement_end_date_key >= 20260601 and statement_end_date_key < 20260701 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No' and claim_status_key in (select claim_status_key from gold.ssas_dim_claim_status where submission_channel = 'NPHIES')"},
```

Run: `python -m pytest ssas/tools/test_measure_catalogue.py -q`
Expected: FAIL in `test_checks_reference_existing_columns_and_measures`, naming `[Billed Statements]`, `[Billed Submitted to NPHIES]`, `[Billed Manual]` and `[Billed Not Submitted]`, which do not exist yet.

- [ ] **Step 2: Add the billed measures**

In `ssas/HNH_Analytics/tables/_Measures.tmdl`, insert after the `'Verified Billed Amount'` block (after its `displayFolder: Revenue Cycle\Billing` line):

```
	/// Billed statements in SAR: Σ invoice net amount (INVOICE_NET_AMOUNT); slice by the Claim Status hierarchy (claim status spec R1, 6.2).
	measure 'Billed Statements' =
			VAR __Value = ( -- measure body
				SUM ( Invoices[Net Amount] )
			) -- end of measure body
			VAR __Wrong = [_Guard Invoices]
			RETURN IF ( __Wrong = "", __Value, """Billed Statements"" can't be analysed by " & __Wrong )
		formatString: #,0
		displayFolder: Revenue Cycle\Billing
	/// Billed statements in SAR submitted through NPHIES: every claim status except New, Valid and Invalid (claim status spec R3, 6.2).
	measure 'Billed Submitted to NPHIES' =
			VAR __Value = ( -- measure body
				CALCULATE ( [Billed Statements], KEEPFILTERS ( 'Claim Status'[Submission Channel] = "NPHIES" ) )
			) -- end of measure body
			VAR __Wrong = [_Guard Invoices]
			RETURN IF ( __Wrong = "", __Value, """Billed Submitted to NPHIES"" can't be analysed by " & __Wrong )
		formatString: #,0
		displayFolder: Revenue Cycle\Billing
	/// Billed statements in SAR submitted manually: status New on a purchaser flagged manual submission (claim status spec R4, 6.2).
	measure 'Billed Manual' =
			VAR __Value = ( -- measure body
				CALCULATE ( [Billed Statements], KEEPFILTERS ( 'Claim Status'[Submission Channel] = "Manual" ) )
			) -- end of measure body
			VAR __Wrong = [_Guard Invoices]
			RETURN IF ( __Wrong = "", __Value, """Billed Manual"" can't be analysed by " & __Wrong )
		formatString: #,0
		displayFolder: Revenue Cycle\Billing
	/// Billed statements in SAR not submitted: New on a purchaser not flagged manual, Valid (Under Processing) or Invalid (claim status spec 4.1, 6.2).
	measure 'Billed Not Submitted' =
			VAR __Value = ( -- measure body
				CALCULATE ( [Billed Statements], KEEPFILTERS ( 'Claim Status'[Submission Channel] = "Not submitted" ) )
			) -- end of measure body
			VAR __Wrong = [_Guard Invoices]
			RETURN IF ( __Wrong = "", __Value, """Billed Not Submitted"" can't be analysed by " & __Wrong )
		formatString: #,0
		displayFolder: Revenue Cycle\Billing
```

- [ ] **Step 3: Redefine the rates and the amount descriptions**

Replace the description line of `'Claims Approved'`:

```
	/// Approved amount in SAR of the latest, not cancelled submission (Phase 2B spec section 8).
```

with:

```
	/// Approved amount in SAR of the latest, not cancelled submission: net amount of approved lines, the NPHIES benefit of partially approved lines, by the line's response outcome (claim status spec 4.2).
```

Replace the description line of `'Claims Rejected'`:

```
	/// Outcome-aware rejected amount in SAR of the latest, not cancelled submission; slice by NPHIES Reason for rejections by reason (Phase 2B spec section 8).
```

with:

```
	/// Rejected amount in SAR of the latest, not cancelled submission: net amount of rejected lines, net minus benefit (not below 0) of partially approved lines (claim status spec 4.2); slice by NPHIES Reason for rejections by reason.
```

Replace the description and body of `'Claim Rejection Rate %'`:

```
	/// Rejected ÷ submitted amount of adjudicated lines of the latest, not cancelled submission (Phase 2B spec section 8; receiving notes).
```

with:

```
	/// Rejected ÷ (approved + rejected) amount of adjudicated lines of the latest, not cancelled submission (claim status spec 6.2).
```

and its body, between `VAR __Value = ( -- measure body` and `) -- end of measure body`:

```
				VAR Rejected = CALCULATE ( [Claims Rejected], 'Claim Lines'[Adjudication Status] = "Adjudicated" )
				VAR Approved = CALCULATE ( [Claims Approved], 'Claim Lines'[Adjudication Status] = "Adjudicated" )
				RETURN DIVIDE ( Rejected, Approved + Rejected )
```

Replace the description of `'First-pass Rejection Rate %'`:

```
	/// Rejection rate of first submissions (submission 1 as sent, cancelled claims included: the one exception to the cancelled rule) (Phase 2B spec section 8; receiving notes).
```

with:

```
	/// Rejected ÷ (approved + rejected) of first submissions (submission 1 as sent, cancelled claims included: the one exception to the cancelled rule) (claim status spec 6.2).
```

and its body:

```
				VAR Rejected =
					CALCULATE (
						SUM ( 'Claim Lines'[Rejected Amount] ),
						'Claim Lines'[Submission Number] = 1,
						'Claim Lines'[Adjudication Status] = "Adjudicated"
					)
				VAR Approved =
					CALCULATE (
						SUM ( 'Claim Lines'[Approved Amount] ),
						'Claim Lines'[Submission Number] = 1,
						'Claim Lines'[Adjudication Status] = "Adjudicated"
					)
				RETURN DIVIDE ( Rejected, Approved + Rejected )
```

- [ ] **Step 4: Guards and perspectives**

Run: `python ssas/tools/measure_guards.py`
Then: `python ssas/tools/sync_perspectives.py`
Then: `python ssas/tools/measure_guards.py --check`
Expected: the check reports no change. In `git diff ssas/HNH_Analytics/tables/_Measures.tmdl`, the four billed measures keep `[_Guard Invoices]`, and no billed measure lists `'Claim Status'` as a wrong table.

- [ ] **Step 5: Offline checks**

Run: `python -m pytest ssas/tools -q`
Expected: all pass.

Run: `powershell -NoProfile -Command "Invoke-Pester -Script ssas\scripts"`
Expected: 0 failed.

Run: `& "C:\Program Files (x86)\Tabular Editor\TabularEditor.exe" ssas\HNH_Analytics -A ssas\bpa_rules.json -V`
Expected: no `type=error`.

- [ ] **Step 6: Commit**

```bash
git add ssas/HNH_Analytics ssas/tests/measures/revenue_cycle.json ssas/tests/measures/claims_preauth.json
git commit -m "SSAS: billed statements by submission channel; rejection rates over approved + rejected

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Expected values before the build

**Files:**
- Create: `docs/reconciliation_claim_status.md`

**Interfaces:**
- Consumes: the numbers recorded in Task 1 Step 6 and Task 3 Step 7.
- Produces: the "expected" column that Task 8 fills in with built values.

- [ ] **Step 1: Write the reconciliation file**

Create `docs/reconciliation_claim_status.md`, filling in the numbers from Task 1 Step 6 and Task 3 Step 7:

```markdown
# Claim status and claim line amounts: reconciliation

Spec: `docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md`. Expected values were computed
read-only on gold before the build (plan tasks 1 and 3); built values after the build of <date>.

## Billed statements by channel, invoices dated 2026-01-01 to 2026-08-31

| Channel | Invoices (expected) | SAR (expected) | Invoices (built) | SAR (built) |
|---|---|---|---|---|
| NPHIES | … | … | | |
| Manual | … | … | | |
| Not submitted | … | … | | |
| Unknown | 0 | 0 | | |

## Claim lines, statement end 2026-01-01 to 2026-08-31, latest not cancelled

| Amount | Expected (SAR) | Built (SAR) |
|---|---|---|
| Approved | … | |
| Rejected | … | |
| Lines not adding up (singular test) | 0 | |

## bsc.vw_rcm shift

Filled from `compare_bsc.ps1` after the build.
```

Replace each `…` with the recorded number; leave the "built" columns empty.

- [ ] **Step 2: Commit**

```bash
git add docs/reconciliation_claim_status.md
git commit -m "Record the expected claim status and claim line totals before the build

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Build, reconcile, deploy. Every server change waits for the user

**Files:**
- Modify: `docs/reconciliation_claim_status.md`, `docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md`

**Interfaces:**
- Consumes: everything above, merged to `main`.
- Produces: built models on `172.22.25.214`, the deployed SSAS model, the filled reconciliation.

- [ ] **Step 1: Merge to main**

Use superpowers:finishing-a-development-branch to merge `claim-status` into `main`; the receiving project copies from `main`.

- [ ] **Step 2: Ask the user, then build in the receiving project (dbt build on the server)**

The user copies `hnh_dwh/models/hnh/`, `hnh_dwh/macros/hnh/` and `hnh_dwh/tests/hnh/` into the receiving project (`docs/receiving_project_config.md`) and runs on the Ubuntu server:

`dbt build --select int_invoice_claim_status+ dim_claim_status+ fact_claim_line+ fact_invoice+`

Expected:
- All selected models build. This includes `ssas_dim_claim_status`, `ssas_fact_invoice`, `ssas_fact_claim_line`, `bsc_vw_rcm` and `rec_claims_monthly`, and their contracts pass.
- The unit tests pass:
  - `int_invoice_claim_status_sets_status_and_channel`
  - `dim_claim_status_lists_each_status_with_its_channels`
  - `fact_claim_line_applies_adjudication_rules`
  - `rec_claims_monthly_ignores_cancelled_claims_and_counts_recovery_once`
- `assert_claim_line_amounts_add_up`, the `relationships` tests to `dim_claim_status` and the `accepted_values` tests pass.

If a unit test fails, fix the model, re-run the matching read-only check of Tasks 1–3, commit, and ask for another build.

- [ ] **Step 3: Fill in the reconciliation (read-only)**

```powershell
Import-Module D:\new_dwh_modeling\scripts\HnhCh.psm1 -Force
Invoke-HnhSelect -Dsn HNH_Gold -Sql "SELECT submission_channel, count() AS invoices, round(sum(net_amount)) AS net_sar FROM gold.fact_invoice WHERE invoice_date_key BETWEEN 20260101 AND 20260831 GROUP BY submission_channel ORDER BY submission_channel" | Format-Table -AutoSize
Invoke-HnhSelect -Dsn HNH_Gold -Sql "SELECT round(sum(approved_amount)) AS approved_sar, round(sum(rejected_amount)) AS rejected_sar FROM gold.fact_claim_line WHERE is_latest_submission = 1 AND is_cancelled_claim = 0 AND statement_end_date_key BETWEEN 20260101 AND 20260831" | Format-Table -AutoSize
Invoke-HnhSelect -Dsn HNH_Gold -Sql "SELECT count() AS keys, countIf(claim_status_key NOT IN (SELECT claim_status_key FROM gold.dim_claim_status)) AS orphan_invoices FROM gold.fact_invoice" | Format-Table -AutoSize
```

Expected:
- the channel rows equal Task 1's to the invoice;
- approved and rejected equal Task 3's to the riyal;
- `orphan_invoices = 0`.

Fill the "built" columns. Any difference: stop and report it to the user with the rows.

- [ ] **Step 4: Re-run the bsc comparison (read-only)**

Run: `powershell -ExecutionPolicy Bypass -File scripts\compare_bsc.ps1`
Expected: `wrote ...\docs\reconciliation_bsc_differences.md`. In `docs/reconciliation_claim_status.md` → "bsc.vw_rcm shift", record how `approved_amount`, `rejections`, `rejection_rate_pct` and `approval_rate_pct` of `vw_rcm` moved against the old server for August 2026, by branch. These are expected changes, caused by the new rules.

- [ ] **Step 5: Ask the user, then deploy the SSAS model**

Ask the user to approve the deploy, then run:
`powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage All`
Expected: validate (BPA) passes, the test database processes the new and changed tables, all measure checks pass (including the new ones of Task 6), and the model is promoted to `HNH_Analytics`.

- [ ] **Step 6: Check production (read-only DAX)**

Run a DAX query on `HNH_Analytics`:

```
EVALUATE SUMMARIZECOLUMNS ( 'Claim Status'[Submission Channel], "Billed", [Billed Statements], "Rejected", [Claims Rejected] )
```

Expected: rows NPHIES, Manual, Not submitted and (if any) Unknown, with non-blank Billed. If the table is empty, ask the user before running `ssas\scripts\process.ps1 -Mode Daily`.

- [ ] **Step 7: Update the spec and commit**

In `docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md`, change the status line to:
`- **Status:** Approved 2026-10-14. Implemented 2026-MM-DD (plan docs/superpowers/plans/2026-10-14-claim-status-and-line-amounts.md); reconciliation in docs/reconciliation_claim_status.md.`
Use the real date.

```bash
git add docs/reconciliation_claim_status.md docs/reconciliation_bsc_differences.md docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md
git commit -m "Reconcile the claim status and claim line amounts after the build

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Hand over**

Tell the user:
- the Claim Status hierarchy and the four billed measures are live;
- the measures that changed meaning are `Claims Approved`, `Claims Rejected`, `Claim Rejection Rate %`, `First-pass Rejection Rate %`, `Resubmission Recovery` and `bsc.vw_rcm`, with the shift recorded;
- O-CS1 is still with the business: the Government purchasers flagged `N` hold SAR 375m of New invoices.
