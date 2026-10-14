# HNH Data Warehouse — Claim Status Hierarchy and Claim Line Amounts

- **Date:** 2026-10-14
- **Status:** Draft for review
- **Parent specs:** `2026-10-05-hnh-dwh-phase2b-claims-design.md` (claim lines, KPI definitions in section 8) and `2026-10-07-hnh-ssas-tabular-model-design.md` (SSAS model). Everything there applies unless this document says otherwise.
- **Trigger:** business rules for claims analysis given on 2026-10-14.

---

## 1. Purpose and decisions

Analyse billed statements by the claim status of each invoice, then analyse the outcome of the NPHIES claim lines behind them. Two changes:

1. Every invoice and every claim line carries a claim status (validation, submission and detailed status from `stg_ref__claim_status`) and a submission channel (NPHIES, manual, not submitted), through one shared dimension.
2. The approved and rejected amounts of a claim line follow the line's NPHIES response outcome with the rules in section 4.

Business rules (2026-10-14):

| # | Rule |
|---|---|
| R1 | Billed statements = Σ `INVOICE_NET_AMOUNT` of `ar_episode_invoices` (`fact_invoice.net_amount`). |
| R2 | `ar_episode_invoices.approval_status` is mapped with `stg_ref__claim_status`; a null status is New. |
| R3 | Every status other than New, Valid and Invalid has been submitted to NPHIES and has lines in claim services. |
| R4 | A New invoice whose purchaser has `stg_ref__purchaser_mapping.manual_submission = 'Y'` was submitted manually, not through NPHIES. |
| R5 | The claim service lines of an invoice get their outcome (approved, partially approved, rejected) from the pull response, per line. |
| R6 | Approved amount: net amount if approved, the response benefit if partially approved, else 0. |
| R7 | Rejected amount: net amount if rejected, net amount − benefit if partially approved, else 0. |

Decisions made in review (2026-10-14):

| # | Decision |
|---|---|
| C1 | Approved and rejected amounts are worked out for every line with an NPHIES decision, whatever the invoice's status. Lines of New, Valid and Invalid invoices that have a decision are included; sliced by status, they show under that status. |
| C2 | The manual split is a column, Submission Channel, not a level of the status hierarchy. |
| C3 | Hierarchy: Validation Status → Submission Status → Detailed Status. |
| C4 | One shared dimension, `dim_claim_status`, related to both `fact_invoice` and `fact_claim_line`, so one slicer filters billed and line amounts together. |
| C5 | `fact_claim_line.approved_amount` and `rejected_amount` are redefined in place. `bsc_vw_rcm` and `rec_claims_monthly` follow; the `legacy_*` columns do not change. |
| C6 | On a partially approved line whose benefit exceeds net, rejected is 0 (not negative) and approved stays the benefit. |

---

## 2. Findings that shape the design

Read-only checks on gold, invoices dated 2026-01-01 to 2026-08-31 unless stated.

| Finding | Effect |
|---|---|
| `fact_invoice` already maps the approval status: an unset code becomes submission and validation status New ("Not set", 254,675 invoices, SAR 1.18bn since January). | The mapping is reused; the dimension adds the hierarchy and the channel. |
| Every invoice with an NPHIES status joins to claim lines on branch and `claim_invoice_no`; the net of the latest submission's lines is SAR 864.39m against an invoice net of SAR 864.46m. | Claim lines take the status of their invoice through this join. |
| 30,218 New invoices (SAR 44.8m) have claim lines, most with NPHIES decisions (SAR 28.7m approved, 9.2m partially approved, 5.0m rejected lines). Valid and Invalid invoices have a few. | Decision C1. |
| Of 117,180 New invoices (SAR 558m), purchasers flagged manual cover 17,040 (SAR 108m); purchasers flagged `N` cover 100,140 (SAR 450m), of which 7,247 Government invoices are SAR 375m. | Not a design change. The flags in `map_purchasers` are for the business to review (section 9). |
| Approved lines, statement end 2026-01-01 to 2026-08-31: benefit = net on 1,178,467 of 1,416,626 lines; Σ benefit SAR 544.74m against Σ net SAR 547.56m (−0.5%; 98.8% to 99.8% by month). Where they differ, the payer's submitted amount differs from our line net. | Rule R6 (approved = net) is kept: it reports what was billed; the benefit stays on the fact for detail. |
| Line net = claimed − discount − copay to the riyal (627.75m − 68.15m − 12.05m = 547.55m) and excludes VAT (75.11m). Benefit = net on 686,324 lines that have a copay. Deductible is negligible (3,724 lines, SAR 0.14m). | Net and benefit are on the same basis (payer share, before VAT), so R6 and R7 compare like with like. |
| 4,375 partially approved lines (SAR 4.2m) have a benefit above net. | Decision C6. |

---

## 3. Architecture

```
ar_episode_invoices ─┐
stg_ref__claim_status ┼─► int_invoice_claim_status ─┬─► fact_invoice.claim_status_key
stg_ref__purchaser_mapping ┘   (one row per invoice)  └─► fact_claim_line.claim_status_key  (branch + claim_invoice_no)
stg_ref__claim_status ──────► dim_claim_status ◄──── both facts (SSAS: table "Claim Status")
int_nphies_adjudication ────► fact_claim_line.approved_amount / rejected_amount (rules R6, R7)
```

---

## 4. Rules

### 4.1 Claim status and channel (per invoice)

- **Status.** `approval_status` → code type 5116 description → `stg_ref__claim_status.detailed_status` (as `fact_invoice` does today).
  - A null code is Detailed Status New, Submission Status New, Validation Status New (R2).
  - A code with no mapping row is Unknown at all three levels.
- **Submission Channel.**

| Channel | When |
|---|---|
| NPHIES | Submission Status is not New, Under Processing or Invalid, and not Unknown (R3; detailed status Valid maps to submission status Under Processing). |
| Manual | Submission Status New and the purchaser's `manual_submission = 'Y'` (R4). |
| Not submitted | Submission Status New with any other flag (including an unmapped purchaser), Under Processing or Invalid. |
| Unknown | Status Unknown. |

- **Key.** `claim_status_key = hnh_surrogate_key([detailed_status, submission_channel])`, in a macro `hnh_claim_status_key(detailed, channel)` in `hnh_rules_claims.sql` so that both facts and the dimension compute it the same way.

### 4.2 Line amounts (per claim line)

The outcome is the pull-response outcome of the line, used only when the line has an adjudicated response (`has_adjudication = 1`, as today). A fallback to the claim services `outcome` column does not count.

| Response outcome | `approved_amount` | `rejected_amount` |
|---|---|---|
| Approved | net | 0 |
| Partially approved | benefit (0 if missing) | greatest(net − benefit, 0) |
| Rejected | 0 | net |
| No decision (no response, error, pended, not sent) | 0 | 0 |

Net is `stg_oasis__claim_services.net_amount` (`fact_claim_line.claimed_amount`). Today's columns are null when there is no adjudication; the new ones are 0, so Σ approved + Σ rejected = Σ net of decided lines.

---

## 5. dbt models

### 5.1 int_invoice_claim_status (new, `intermediate/revenue/`)

One row per invoice from `stg_oasis__episode_invoices`, all history (no date filter, so claim lines of older invoices find their status).

- **Grain:** `branch_id`, `invoice_no`.
- **Columns:** `purchaser_code`, `detailed_status`, `submission_status`, `validation_status`, `is_status_mapped`, `manual_submission`, `submission_channel`, `claim_status_key`.
- **Sources:** the purchaser from `int_invoice_payer` (as `fact_invoice`), the flag from `stg_ref__purchaser_mapping` on branch and purchaser code.
- **Tests:** unique on `(branch_id, invoice_no)`, `not_null` on `claim_status_key`, `accepted_values` on `submission_channel`.

### 5.2 dim_claim_status (new, `marts/conformed/`)

One row per distinct detailed status of `stg_ref__claim_status` and each channel that status can have, plus New (from a null code) and Unknown / Unknown.

- **Columns:** `claim_status_key`, `validation_status`, `submission_status`, `detailed_status`, `submission_channel`, `is_submitted` (1 for NPHIES and Manual).
- **Combinations:** detailed statuses under submission status New get Manual and Not submitted; Under Processing and Invalid get Not submitted; the others get NPHIES.

### 5.3 fact_invoice (changed)

- Takes `claim_status_key` and `submission_channel` from `int_invoice_claim_status`.
- The existing status columns stay, so current reports keep working.

### 5.4 fact_claim_line (changed)

- `claim_status_key`: from `int_invoice_claim_status` on `branch_id` and `claim_invoice_no`. A line without an invoice number, or whose invoice is not found, gets the Unknown / Unknown key.
- `approved_amount` and `rejected_amount`: section 4.2.
- Other response columns (`submitted_amount`, `eligible_amount`, `copay_amount`, …) and the `legacy_*` columns do not change.
- Add `response_benefit_amount` (the benefit as returned, null without adjudication), so the payer's figure stays visible once approved = net. It goes into `ssas_fact_claim_line`'s `decimals`.

### 5.5 Downstream

- `bsc_vw_rcm` and `rec_claims_monthly` read `approved_amount` and `rejected_amount` unchanged and so follow the new rules (C5).
- `ssas_fact_invoice` and `ssas_fact_claim_line` pass the new key through; `ssas_dim_claim_status` is new. Contracts are regenerated with `scripts/gen_view_contracts.py`.

---

## 6. SSAS

### 6.1 Table Claim Status

- Generated from `ssas_dim_claim_status`: `Table(..., "Claim Status", "dim", ...)` in `model_config.py`, and `"claim_status_key": ("Claim Status", "claim_status_key")` in `DIM_KEYS`, so `Invoices` and `Claim Lines` relate to it.
- Hand-written hierarchy **Claim Status**: Validation Status → Submission Status → Detailed Status.
- In the perspectives Executive, Revenue Cycle and Claims & Pre-auth.

### 6.2 Measures

New measures, display folder `Revenue Cycle\Billing`:

| Measure | Definition |
|---|---|
| `Billed Statements` | Σ `Invoices[Net Amount]` (R1; same value as `Billed Amount`, named for the claims analysis). |
| `Billed Submitted to NPHIES` | `Billed Statements` where Submission Channel = NPHIES. |
| `Billed Manual` | `Billed Statements` where Submission Channel = Manual. |
| `Billed Not Submitted` | `Billed Statements` where Submission Channel = Not submitted. |

Changed measures:

| Measure | New definition |
|---|---|
| `Claims Approved`, `Claims Rejected` | Unchanged DAX; they follow the new columns. |
| `Claim Rejection Rate %` | `Claims Rejected` ÷ (`Claims Approved` + `Claims Rejected`), latest not cancelled submission, adjudicated lines. |
| `First-pass Rejection Rate %` | The same ratio on submission 1, cancelled claims included (the exception of the Phase 2B spec stays). |

Descriptions of the changed measures name this spec. Each new or changed measure gets a check in `tests/measures/revenue_cycle.json` or `claims_preauth.json`. Then run `measure_guards.py` and `sync_perspectives.py`.

The line outcome for slicing stays the existing column `Claim Lines[Item Outcome]`.

---

## 7. Testing and reconciliation

- **dbt unit tests**
  - `int_invoice_claim_status`: one invoice per channel; a null status; an unmapped status code; a New invoice on an unmapped purchaser.
  - `fact_claim_line`: one line per outcome; a partial line whose benefit exceeds net; a line with a claim services outcome but no response (0 / 0); a line whose invoice is not found (Unknown key).
  - `rec_claims_monthly`: the existing unit tests are updated to the new amounts.
- **dbt data tests**
  - `relationships` from both facts' `claim_status_key` to `dim_claim_status`.
  - A singular test that on decided lines approved + rejected = net, except partial lines whose benefit exceeds net.
- **Read-only reconciliation (August 2026)**
  - Billed Statements by hierarchy and channel against `fact_invoice`.
  - Claims Approved and Claims Rejected against a direct query on the pull-response items.
  - The bsc comparison (`compare_bsc.ps1`) re-run; the shift of `vw_rcm` approved and rejected is recorded.
- **SSAS offline**: BPA (`-A`), `python -m pytest ssas/tools`, Pester.

---

## 8. Rollout (each step asks before it runs on the server)

1. dbt build of the changed models and their downstream (`+fact_invoice+`, `+fact_claim_line+`, `int_invoice_claim_status`, `dim_claim_status`).
2. `deploy.ps1 -Stage All` (adds the Claim Status table and the measures).
3. `process.ps1 -Mode Daily` if the deploy does not reload the changed tables.

---

## 9. Open items

| # | Item |
|---|---|
| O-CS1 | The business reviews `manual_submission` in `map_purchasers`: the Government purchasers flagged `N` hold SAR 375m of New invoices (Jan–Aug 2026). A fixed flag needs only a reload of the mapping and a dbt run. |
