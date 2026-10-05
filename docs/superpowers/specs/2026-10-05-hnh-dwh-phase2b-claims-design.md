# HNH Data Warehouse — Phase 2B Claims, Remittance and Pre-authorisation Responses

- **Date:** 2026-10-05
- **Status:** Draft for review
- **Parent specs:** `2026-10-01-hnh-dwh-gold-layer-design.md` (architecture, keys, conventions) and `2026-10-04-hnh-dwh-phase2-revenue-cycle-design.md` (Phase 2A, section 10 outlined this phase). Everything there applies unless this document says otherwise.
- **Trigger:** `oasis.api_pull_response_details` (NPHIES pull responses) was ingested on 2026-10-05.

---

## 1. Purpose and decisions

Complete the revenue cycle with what NPHIES returns: claim adjudication per service line, insurer remittance per claim, and structured adjudication for pre-authorisations. Replaces the claim content of the *claims* Power BI model and `bsc.vw_rcm`.

Decisions made in review (2026-10-05):

| # | Decision |
|---|---|
| B1 | NPHIES JSON bundles are parsed inside dbt with ClickHouse JSON functions (no external flattener, no ingestion change). |
| B2 | Claim-level insurer remittance (NPHIES payment reconciliation) is in scope as `fact_claim_payment`. Insurer AR ageing stays in Phase 3 (Fusion AR), because not every payer uses NPHIES. This narrows Phase 2 decision D3. |
| B3 | Every claim submission is kept; resubmissions are numbered and the latest is flagged. Default claim KPIs use the latest submission; first-pass KPIs use submission 1. |
| B4 | Pre-authorisation responses from the pull table enrich `fact_preauth_line` (reason codes, payer amounts, authorisation reference and validity). Payer-initiated advance authorisations are not in the fact; they are monitored from `stg_oasis__pull_responses`, not parsed. |

---

## 2. Findings that shape the design

Measured 2026-10-05; the load was still running (7.27M rows at the last count).

| # | Fact | Consequence |
|---|---|---|
| C1 | `api_pull_response_details` is a ReplacingMergeTree on `(branch_id, response_id)`. Columns of use: `response_id`, `api_trans_id`, `about_api_trans_id`, `response_type`, `res_status`, `status`, `creation_date`, `response_bundle` (FHIR JSON, Nullable String). Branches 1–6 from 2022 (branch 6 from 2024-11); branches 7 and 8 only from 2026-10-04. | Staging reads it with `final`; JSON functions must wrap the bundle in `ifNull(…, '{}')`. |
| C2 | Response types: claim-response (~2.6M), priorauth-response (~1.5M), payment-reconciliation (~211K), communication-request (~243K), advanced-authorization (55K), prescriber-response (1). | Only claim-response, priorauth-response and payment-reconciliation are parsed; advanced-authorization is monitored from staging (O-P2B-3). |
| C3 | A claim-response is about the claim visit's NPHIES transaction: `about_api_trans_id` = `claim_visit_detail.api_trans_id` = the ClaimResponse `request.identifier`. Items carry `itemSequence`, which matches `claim_service_detail.sequence_no` (36,839 of 36,839 items, branch 1, 1–7 June 2026). | Item adjudication joins on (branch, transaction, sequence). `about_api_trans_id` is null on some responses (about 92K claim and 40K pre-authorisation items); the transaction then comes from the ClaimResponse `request.identifier`. |
| C4 | ClaimResponse items carry adjudication categories `submitted`, `eligible`, `benefit`, `copay`, `deductible`, `tax`, `patientShare` (amounts) and `approved-quantity` (value); an `extension-adjudication-outcome` (approved, partial, rejected); reason codes in `adjudication[].reason.coding[]` (system `…/adjudication-reason`), possibly several per item (e.g. BE-1-7 and MN-1-1). | One parser for items, categories and reasons. |
| C5 | 11% of claim transactions have more than one claim-response (2.47M with one, 247K with two, 22K with three …). | Deterministic final response per transaction. |
| C6 | Resubmissions appear as several claim visits for one `claim_invoice_no` (11% of invoices since 2025 have two or more). `related_api_trans_id` almost never points to an earlier submission of the same invoice (2,241 of 317,443). | Submission number from visit order within the invoice. |
| C7 | `claim_service_detail` is keyed `(branch_id, visit_id, service_id, invoice_number, sequence_no)`. `service_id` is not unique (2,708,498 ids over 3,872,047 rows in 2026); `(branch_id, visit_id, sequence_no)` is. | Claim-line grain is (branch, visit, sequence). |
| C8 | Share of claim visits with a claim-response, by year, at the time of measurement: branch 1 71–93%, branch 2 67–94%, branch 3 30–66%. | Re-measured after the load completes; a warn monitor reports unanswered sent claims by branch and month. |
| C9 | PaymentReconciliation carries `paymentDate`, `paymentAmount`, `period`, `paymentIdentifier` and `detail[]`. Each detail has `request.identifier` (the claim transaction), `response.identifier` (payer claim-response id), `type` (payment, adjustment …), `date`, `amount`, and extensions `component-payment`, `component-early-fee`, `component-nphies-fee`. | Remittance is claim-level, not item-level. |
| C10 | priorauth-responses link to 77% of June 2026 pre-auth requests (`about_api_trans_id` = `api_pre_approval_req.api_trans_id`). Their ClaimResponse carries `preAuthRef`, `preAuthPeriod`, item `benefit`/`submitted`/`approved-quantity` and reason codes (47 of 86 partial/rejected items in a sample). | Pre-auth reasons become available; matched by transaction and item number. |
| C11 | Bundles also contain Patient, Coverage and Organization resources with names and identifiers. | Only ClaimResponse and PaymentReconciliation resources are parsed; the bundle text never leaves staging. |

---

## 3. Architecture

Same layers, tags and folders as Phases 1 and 2A.

```
models/hnh/staging/oasis/      + stg_oasis__claim_visits, stg_oasis__claim_services, stg_oasis__pull_responses
models/hnh/intermediate/revenue/ + int_nphies_adjudication, int_claim_payment, int_claim_submission
models/hnh/marts/conformed/    + dim_nphies_reason
models/hnh/marts/revenue/      + fact_claim_line, fact_claim_payment; fact_preauth_line extended
models/hnh/marts/reconciliation/ + rec_claims_monthly; rec_preauth_monthly extended
macros/hnh/hnh_rules_claims.sql
```

All models are full rebuilds. The JSON parse runs over ~4.3M bundles of the parsed types each night.

---

## 4. Staging

| Model | Source | Notes |
|---|---|---|
| `stg_oasis__claim_visits` | `claim_visit_detail` | One claim submission. Keys and dates (`visit_id`, `request_date`, `visit_date`, `stat_end_date`, `creation_date`), `claim_invoice_no`, `stat_invoice_no`, `patient_id`, `episode_no`, `purchaser_code`, `contract_no`, `claim_type`, `doctor_code`, `doctor_license`, `provider_department_code`, `api_trans_id`, `status`, `res_status`, `submit_claim_outcome`, `canceled`, `cancel_date`, totals. Patient names, identity numbers, mobile, passport, membership and policy-holder fields are not staged. |
| `stg_oasis__claim_services` | `claim_service_detail` | One claim line: `visit_id`, `sequence_no`, `service_id`, `invoice_number`, `ios`, `service_code`, `qty`, `line_claimed_amount`, `line_item_discount`, `net_amount`, `co_pay`, `co_insurance`, `net_vat_amount`, `patient_vat_amount`, `net_with_vat`, `outcome`, `approved_qunatity` (as `approved_qty_text`), `pre_auth_id`, `package_id`, `notes`. |
| `stg_oasis__pull_responses` | `api_pull_response_details` | `response_id`, `api_trans_id`, `about_api_trans_id`, `response_type`, `res_status`, `status`, `responded_at`, `response_bundle` (`ifNull(…,'{}')`). Filtered to the parsed types: claim-response, priorauth-response, advanced-authorization, payment-reconciliation. |

Uniqueness tests: visits on (branch, visit_id); services on (branch, visit_id, sequence_no); pull responses on (branch, response_id).

---

## 5. Rules (macros, `hnh_rules_claims.sql`)

| Macro | Rule |
|---|---|
| `hnh_nphies_outcome(outcome_code)` | `approved` → Approved, `partial` → Partially approved, `rejected` → Rejected, `pended`/`queued` → Pended, anything else → Unknown |
| `hnh_is_decision_status(res_status)` | `APPROVED`, `PARTIAL`, `REJECTED` (upper-cased) → 1, else 0 |
| `hnh_claim_adjudication_status(is_sent, has_response, final_status)` | not sent → Not sent; sent, no response → No response; decision status → Adjudicated; `PENDED`/`QUEUED` → Pended; `ERROR`/failed → Error |
| `hnh_reason_from_notes(notes)` | first NPHIES code matching `[A-Z]{2}-[0-9]+-[0-9]+` in the claim line's notes, else null |

---

## 6. Intermediate models

### 6.1 int_nphies_adjudication

**Grain:** one item of one ClaimResponse in one pull response — `(branch_id, response_id, item_sequence)`, with `response_kind` = Claim (claim-response) or Pre-authorisation (priorauth-response). Advanced-authorization bundles have no `item[]` and are not parsed.

**Columns:** `about_api_trans_id` (the column, else the ClaimResponse `request.identifier`), `responded_at`, `res_status`, `response_type`, `item_sequence`; outcome (from the item's adjudication-outcome extension); amounts `submitted`, `eligible`, `benefit`, `copay`, `deductible`, `tax`, `patient_share`; `approved_qty`; `reason_codes` (Array(String), all adjudication reason codings of the item, in order); `primary_reason_code` (first); for pre-authorisation also `preauth_reference`, `preauth_valid_from`, `preauth_valid_to` (dates parsed from the first 10 characters; payers send ISO datetimes).

Parse path: `JSONExtractArrayRaw(bundle, 'entry')` → resource where `resourceType = 'ClaimResponse'` → `item[]` → `adjudication[]` aggregated per item (category code → amount; `approved-quantity` → value).

### 6.2 int_claim_payment

**Grain:** one detail of one PaymentReconciliation — `(branch_id, reconciliation_id, detail_index)`. The payer re-sends the same reconciliation on every pull (up to about 1,848 times; 3.01bn loaded against 0.64bn distinct), so only the latest pull of each reconciliation is kept (latest `responded_at`, then `response_id`). `reconciliation_id` is the entry `fullUrl`, else the resource `id`. The detail identifier is an attribute.

**Columns:** `reconciliation_id`, `claim_api_trans_id` (detail `request.identifier.value`, as Int64), `payer_claim_response_id`, `detail_type`, `detail_date`, `amount`, `payment_component`, `early_fee`, `nphies_fee`, and from the reconciliation `payment_date`, `payment_amount_total`, `period_start`, `period_end`, `payment_reference`.

### 6.3 int_claim_submission

**Grain:** one claim visit. `submission_number` = rank of the visit within `(branch_id, claim_invoice_no)` by `request_date`, then `visit_id`; `is_latest_submission` (the last submission of the invoice, whether cancelled or not; KPIs also filter `is_cancelled_claim = 0`); `is_sent` (`api_trans_id` present); the final claim response for the visit's transaction, matched on `about_api_trans_id`, else on the ClaimResponse `request.identifier` (latest by `responded_at`, then `response_id`, among decision statuses; else latest of any status) with its `response_id`, `final_status`, `responded_at`, `response_count`.

---

## 7. Gold

### 7.1 dim_nphies_reason
Key `hnh_surrogate_key([reason_code])` (group-wide; codes are national). From `stg_ref__nphies_reason`: code, reason, category. Extra members: `-1` Unknown (a code not in the list), `0` Not given.

### 7.2 fact_claim_line

**Grain:** `(branch_id, visit_id, sequence_no)` for claim visits with `stat_end_date >= history_start_date`. Every submission is kept.

**Keys:** `claim_line_key`; `branch_key`; `statement_end_date_key`, `submitted_date_key` (request date), `response_date_key`; patient, episode, payer (visit purchaser), service (`ios`), care type (episode, else `claim_type`), `invoice_key` (`fact_invoice` key of `claim_invoice_no`, `-1` when absent; a warn relationship, see section 9), `nphies_reason_key`.

**Attributes:** `claim_invoice_no`, `stat_invoice_no`, `service_code`, `submission_number`, `is_latest_submission`, `is_sent`, `adjudication_status`, `item_outcome` (response item, else the claim line's `outcome`), `reason_codes`, `primary_reason_code`, `reason_source` (`NPHIES response` / `Claim notes` / `Not given`), `is_cancelled_claim` (visit `canceled = 'Y'`).

**Measures:**

| Column | Rule |
|---|---|
| `claimed_amount` | claim line `net_amount` |
| `submitted_amount`, `eligible_amount`, `approved_amount` (benefit), `copay_amount`, `deductible_amount`, `patient_share_amount`, `tax_amount`, `approved_qty` | final response item; null unless `adjudication_status = 'Adjudicated'`. `submitted_amount` falls back to `claimed_amount` when the response omits it, so the rejection-rate numerator and denominator cover the same lines. |
| `rejected_amount` | when adjudicated, by outcome: Rejected: `submitted_amount` (or `claimed_amount`); Approved: 0; otherwise (partial) `submitted − coalesce(nullIf(eligible, 0), benefit + patient share/copay)`, floored at 0; null when not adjudicated. Payers omit `eligible` on approved items and send `eligible = submitted` on rejected ones, so `submitted − eligible` is not usable. |

Response reasons (`reason_codes`, `primary_reason_code`, `nphies_reason_key`, `reason_source`) apply only to adjudicated lines; the claim-line notes reason still applies to the others.

**Legacy fields:** `legacy_submitted_amount` (`net_amount`, every line); `legacy_approved_amount` (`multiIf(outcome='REJECTED',0, outcome='PARTIAL', benefit of the reason-bearing adjudication or 0, net_amount)`); `legacy_rejected_amount` (`greatest(net_amount - legacy_approved_amount, 0)`).

### 7.3 fact_claim_payment

**Grain:** one row of `int_claim_payment` with `payment_date >= history_start_date`.

**Keys:** `claim_payment_key` (branch, `reconciliation_id`, `detail_index`); `branch_key`; `payment_date_key`; the claim visit's patient, episode, payer and `invoice_key`; `claim_api_trans_id` and `visit_id` as attributes (`-1`/null when the transaction matches no claim visit).

**Measures:** `payment_amount` (detail amount), `payment_component`, `early_fee`, `nphies_fee`; `days_to_payment` (claim request date → payment date).

### 7.4 fact_preauth_line (extended)

Matched to `int_nphies_adjudication` (pre-authorisation kind) on the line's final response transaction and item number. New columns: `nphies_reason_key`, `primary_reason_code`, `reason_codes`, `payer_eligible_amount`, `payer_approved_amount`, `preauth_reference`, `preauth_valid_from_date_key`, `preauth_valid_to_date_key`. Existing columns and KPIs are unchanged; lines without a parsed response keep the new columns empty.

---

## 8. KPI definitions

| KPI | Definition | Fact |
|---|---|---|
| Claims submitted (value) | Σ `claimed_amount`, `is_sent`, `is_latest_submission`, not cancelled | `fact_claim_line` |
| Approved | Σ `approved_amount`, latest submission, not cancelled | `fact_claim_line` |
| Rejected | Σ `rejected_amount`, latest submission, not cancelled | `fact_claim_line` |
| Rejection rate | Rejected ÷ Σ `submitted_amount` of adjudicated lines, latest submission, not cancelled | `fact_claim_line` |
| First-pass rejection rate | Same, `submission_number = 1` | `fact_claim_line` |
| Resubmission recovery | Σ `approved_amount` of the latest non-cancelled submission where `submission_number > 1` (earlier resubmissions of the same invoice are superseded and not counted) | `fact_claim_line` |
| Pending adjudication | Σ `claimed_amount` sent, latest submission, not cancelled, `adjudication_status` in (No response, Pended) | `fact_claim_line` |
| Rejections by reason | Rejected by `dim_nphies_reason` category and code | `fact_claim_line` |
| Remitted | Σ `payment_amount` | `fact_claim_payment` |
| Payment fees | Σ `early_fee` and Σ `nphies_fee`, reported as two signed columns (`remitted_early_fee`, `remitted_nphies_fee`), never netted: the early fee is a payer component that adds to the paid amount (positive in 2024–25, negative in 2026; meaning to be confirmed by finance) | `fact_claim_payment` |
| Days to payment | Average and median `days_to_payment`, by payer | `fact_claim_payment` |
| Pre-auth rejections by reason | Rejected pre-auth lines by `nphies_reason_key` | `fact_preauth_line` |

### Corrections relative to the old logic

| Old behaviour | Correction | Legacy field |
|---|---|---|
| "Submitted" summed every line, including New, Invalid, Failed, Queued and cancelled claims | Sent, non-cancelled lines of the latest submission | `legacy_submitted_amount` |
| Unadjudicated lines counted as fully approved | No approved or rejected amount until a decision | `legacy_approved_amount` |
| Partial approvals without a reason code dropped out (claims model) or counted as fully rejected (`bsc.vw_rcm`) | Partial lines keep their benefit; reason `Not given` | `legacy_approved_amount` |
| Rejected = net − benefit, so the patient co-pay counted as a rejection | Outcome-aware rejected amount (section 7.2): the full submitted amount for Rejected lines, 0 for Approved, the unapproved remainder net of the patient share for partial lines | `legacy_rejected_amount` |
| Reason chosen by `argMax` over exploded adjudications; adjudication category ignored | All reason codes kept; primary = first coding; category-aware amounts | — |
| Resubmissions double counted in submitted totals | One latest submission per claim line | `legacy_submitted_amount` |

---

## 9. Testing and reconciliation

- Uniqueness and not-null on every grain key; relationships from every fact key to its dimension, including `invoice_key` to `fact_invoice` (warn: claim invoice numbers are partly a different number space from the AR invoices; about 25K claim invoices are absent from AR and about 22K match only another branch's numbers, so the warn is not the invoice window).
- Conservation: `fact_claim_line` = staged claim lines of visits in the window; uniqueness of `(branch_id, response_id, item_sequence)` in `int_nphies_adjudication` plus the multi-item unit test (see the plan's refinements).
- Macro tests with literal inputs for every macro in section 5.
- Unit tests: JSON parse of a fixture bundle (two items, several categories, two reason codes, a Patient resource that must be ignored); final response pick (PENDED then PARTIAL; PARTIAL then ERROR); submission numbering for an invoice with two visits; rejected amount for approved, partial and rejected items; payment detail parse with fee components.
- Warn monitors: sent, non-cancelled claims with no response by branch and month; claim-response items with no matching claim line; payment details whose transaction matches no claim; reason codes not in `dim_nphies_reason`; advance authorisations (count by branch and month, read from `stg_oasis__pull_responses`).
- `rec_claims_monthly` (branch × statement month): legacy submitted, approved, rejected (from the legacy fields) beside new submitted, approved, rejected, adjudicated submitted, first-pass rejected and adjudicated submitted, resubmission recovery, pending, remitted, and the two signed fee columns `remitted_early_fee` and `remitted_nphies_fee`. Approved, rejected, adjudicated submitted and pending exclude cancelled claims. Acceptance: legacy columns match the claims model and `bsc.vw_rcm` for a closed month within 0.5%.
- `rec_preauth_monthly` gains rejected count by reason category, `rejected_reason_not_given` and `rejected_reason_unknown` (key -1), so the reason columns sum to rejected.

---

## 10. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P2B-1 | The pull-response load was still running; coverage by branch (C8) to be re-measured when it completes | Acceptance | Warn monitor shows the gap |
| O-P2B-2 | Branches 7 and 8 have pull responses only from 2026-10-04 | Their claim KPIs | Earlier claims show No response |
| O-P2B-3 | How to report payer-initiated advance authorisations (55K); their bundles have no `item[]` (35.6K have `addItem[]` without `itemSequence`) | Pre-auth reporting | Not parsed; monitored from `stg_oasis__pull_responses` |
| O-P2B-4 | Payment detail types other than `payment` (adjustments, recoupments) and their sign | Remittance totals | Summed as delivered, type kept as an attribute |
| O-P2B-5 | Closed month and exports of the claims model and `bsc.vw_rcm` | Reconciliation sign-off | — |
| O-P2B-6 | Jan–Jul 2022 claim responses with a null `res_status` but a decision in the bundle show as Error (about 288K lines); a header-level parser would fix it | Claim KPIs for early 2022 | Left as Error |
| O-P2B-7 | Claim-level answers without items show "Not adjudicated" (about 26K lines) | Claim KPIs | Left as is |
| O-P2B-8 | Legacy `N-DC-0xx` pre-authorisation reason codes (2022 to October 2023, about 194K rejected lines) are not in `dim_nphies_reason` and map to Unknown | Pre-auth reasons for 2022–2023 | Left as Unknown; map or leave |
| O-P2B-9 | Branch 6 has no claim-response pulls since 2025-11; branch 8's last pull response is 2026-05-07 (ingestion gap) | Their claim KPIs | Warn monitor shows the gap |
| O-P2B-10 | Meaning of negative early fees (positive in 2024–25, negative in 2026); finance to confirm | Remittance fee reporting | Reported signed as received |

---

## 11. Changes during implementation (2026-10-05)

1. `fact_claim_line.rejected_amount` is outcome-aware (Rejected: submitted or claimed; Approved: 0; otherwise submitted − coalesce(nullIf(eligible, 0), benefit + patient share/copay), floored at 0), because payers omit `eligible` on approved items and send `eligible = submitted` on rejected ones.
2. `submitted_amount` falls back to `claimed_amount` for adjudicated lines, and response reasons apply only to adjudicated lines.
3. `int_claim_payment` keeps only the latest pull of each PaymentReconciliation (`reconciliation_id` = entry `fullUrl`, else resource `id`); `claim_payment_key` = (branch, `reconciliation_id`, `detail_index`), because the same reconciliation was re-pulled up to about 1,848 times (3.01bn loaded, 0.64bn distinct).
4. Claim responses (`int_claim_submission`, `int_nphies_adjudication`) match their transaction by `about_api_trans_id`, falling back to the ClaimResponse `request.identifier`.
5. Pre-authorisation validity dates parse the first 10 characters, because payers send ISO datetimes.
6. `rec_claims_monthly`: approved, rejected, adjudicated submitted and pending exclude cancelled claims; `resubmission_recovery` is approved on the latest non-cancelled submission with `submission_number > 1`; remittance fees are two signed columns `remitted_early_fee` and `remitted_nphies_fee`. `rec_preauth_monthly` also has `rejected_reason_unknown`.
7. `is_latest_submission` is the last submission whether cancelled or not; KPIs also filter `is_cancelled_claim = 0`.
8. The `invoice_key` warn is not the invoice window: claim invoice numbers are partly a different number space (about 25K invoices absent from AR, about 22K matching only another branch's numbers); section 9 and the column description are corrected.
9. Advance authorisations are monitored from `stg_oasis__pull_responses` and not parsed.
10. Open items O-P2B-6 to O-P2B-10 added: early-2022 null statuses, claim-level answers without items, legacy `N-DC-0xx` reason codes, branch 6 and 8 pull gaps, and negative early fees.
