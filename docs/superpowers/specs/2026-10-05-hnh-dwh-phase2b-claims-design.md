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
| `stg_oasis__pull_responses` | `api_pull_response_details` | `response_id`, `api_trans_id`, `about_api_trans_id`, `response_type`, `res_status`, `status`, `responded_at`, `response_bundle` (`ifNull(…,'{}')`). Filtered to the types used: claim-response, priorauth-response and payment-reconciliation (parsed) and advanced-authorization (monitored only). |

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

**Grain:** one detail of one PaymentReconciliation — `(branch_id, reconciliation_id, detail_index)`. The payer re-sends the same reconciliation on every pull (up to about 1,848 times; 3.01bn of payment details loaded against 0.63bn distinct), so only the latest pull of each reconciliation is kept (latest `responded_at`, then `response_id`). `reconciliation_id` is the reconciliation's content, not its `fullUrl` or resource `id`: some payers (Tawuniya, Al Rajhi) issue a new `fullUrl` and `id` on every pull of the same payment, Bupa reuses one numeric id for different payments, and one TPA sends a payment in pages of 50 details under one id. With a `paymentIdentifier`: `'pid:' || paymentIdentifier.value || '|' || paymentDate (first 10 characters) || '|' || paymentAmount.value`; without one: `'hash:' || paymentDate || '|' || paymentAmount.value || '|' || cityHash64(sorted detail request identifier ':' amount)`. No two pulls under one identity carry different details (checked on the 2026-10-05 data). One pull holds one PaymentReconciliation. The detail identifier is an attribute.

**Columns:** `reconciliation_id`, `claim_api_trans_id` (detail `request.identifier.value`, as Int64), `payer_claim_response_id`, `detail_type`, `detail_date`, `amount`, `payment_component`, `early_fee`, `nphies_fee`, and from the reconciliation `payment_date`, `payment_amount_total`, `period_start`, `period_end`, `payment_reference`.

### 6.3 int_claim_submission

**Grain:** one claim visit. `submission_number` = rank of the visit within `(branch_id, claim_invoice_no)` by `request_date`, then `visit_id`; `is_latest_submission` (the last submission of the invoice, whether cancelled or not; KPIs also filter `is_cancelled_claim = 0`); `is_sent` (`api_trans_id` present); the final claim response for the visit's transaction, matched on `about_api_trans_id`, else on the ClaimResponse `request.identifier` (latest by `responded_at`, then `response_id`, among decision statuses; else latest of any status) with its `response_id`, `final_status`, `responded_at`, `response_count`. The status of a response is its `res_status`; when that is null (early-2022 pulls), the decision in the ClaimResponse: its adjudication-outcome extension (approved, partial, rejected, pended, in upper case), else its `outcome` (queued → QUEUED, error → ERROR). The bundle is parsed only for those rows.

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

A Rejected line keeps the payer's benefit in `approved_amount` when the payer sends one (9,635 lines, about 123K SAR in total): the amount is reported as received and the line still counts as rejected in full.

Response reasons (`reason_codes`, `primary_reason_code`, `nphies_reason_key`, `reason_source`) apply only to adjudicated lines; the claim-line notes reason still applies to the others.

**Legacy fields:** `legacy_submitted_amount` (`net_amount`, every line); `legacy_approved_amount` (`multiIf(outcome='REJECTED',0, outcome='PARTIAL', benefit of the reason-bearing adjudication or 0, net_amount)`); `legacy_rejected_amount` (`greatest(net_amount - legacy_approved_amount, 0)`).

### 7.3 fact_claim_payment

**Grain:** one row of `int_claim_payment` with `payment_date` in the fact window (from `history_start_date` to the end of the year after next). 213 details (about 144K SAR) carry payer payment dates in 2078 and 2115 and are dropped.

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
| Days to payment | Median `days_to_payment` per payment month, by payer (bulk back-settlements in 2025-05 and 2026-04 skew averages and yearly figures) | `fact_claim_payment` |
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
- Unit tests: JSON parse of a fixture bundle (two items, several categories, two reason codes, a Patient resource that must be ignored); final response pick (PENDED then PARTIAL; PARTIAL then ERROR; a null status with a decision in the bundle); submission numbering for an invoice with two visits; rejected amount for approved, partial and rejected items; payment detail parse with fee components, a re-pull under a new `fullUrl` and a no-identifier pair with identical details (one reconciliation each).
- Warn monitors: sent, non-cancelled claims with no response by branch and month; claim-response items with no matching claim line; payment details (other than advances) whose transaction matches no claim; the same payment detail in more than one kept reconciliation; reason codes not in `dim_nphies_reason`; advance authorisations (count by branch and month, read from `stg_oasis__pull_responses`).
- `rec_claims_monthly` (branch × statement month): legacy submitted, approved, rejected (from the legacy fields) beside new submitted, approved, rejected, adjudicated submitted, first-pass rejected and adjudicated submitted, resubmission recovery, pending, remitted, and the two signed fee columns `remitted_early_fee` and `remitted_nphies_fee`. Approved, rejected, adjudicated submitted and pending exclude cancelled claims; the `first_pass_*` columns include cancelled claims (submission 1 as sent, an exception to the `is_cancelled_claim = 0` rule). Acceptance: legacy columns match the claims model and `bsc.vw_rcm` for a closed month within 0.5%.
- `rec_preauth_monthly` gains rejected count by reason category, `rejected_reason_not_given` and `rejected_reason_unknown` (key -1), so the reason columns sum to rejected.

---

## 10. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P2B-1 | The pull-response load was still running; coverage by branch (C8) to be re-measured when it completes | Acceptance | Warn monitor shows the gap. **Closed 2026-10-07:** known source behaviour, monitored |
| O-P2B-2 | Branches 7 and 8 start late in the pull table: branch 7 claim responses from 2026-04-07 and pre-authorisation responses from 2026-02-14 (remittance 2026-06-08 to 2026-09-29); branch 8 claim responses 2026-04-07 to 2026-05-07 only (86 pulls), pre-authorisation responses 2026-02-14 to 2026-10-04 (measured 2026-10-05) | Their claim KPIs | Earlier claims show No response. **Closed 2026-10-07:** known source behaviour, monitored |
| O-P2B-3 | How to report payer-initiated advance authorisations (55K); their bundles have no `item[]` (35.6K have `addItem[]` without `itemSequence`) | Pre-auth reporting | **Closed 2026-10-07:** parsed at header level into `fact_preauth_line` as `Payer advance` rows (section 12; section 11, item 18) |
| O-P2B-4 | Payment detail types other than `payment` (adjustments, recoupments) and their sign | Remittance totals | **Closed 2026-10-07:** kept as delivered (summed signed, type kept as an attribute) |
| O-P2B-5 | Closed month and exports of the claims model and `bsc.vw_rcm` | Reconciliation sign-off | **Closed 2026-10-07:** August 2026 validated on the old server; `legacy_in_scope` reproduces the old statement scope and the VAT fix applied (section 11, items 16–17; `docs/reconciliation_phase2.md`) |
| O-P2B-6 | Resolved for null statuses: early-2022 claim responses with a null `res_status` take the decision from the ClaimResponse (section 6.3); 518,368 latest live 2022 lines (46.3M SAR claimed) moved from Error to Adjudicated and 1,898 to Pended. Remaining 2022 Error (latest live): 55,144 lines with a real ERROR status (7.2M SAR) and 11,645 lines whose final status is SENT or ADJUDICATION (1.06M SAR), which also carry a decision in the bundle | Claim KPIs for 2022 | SENT and ADJUDICATION left as Error |
| O-P2B-7 | Claim-level answers without items show "Not adjudicated" (about 26K lines) | Claim KPIs | Left as is. **Closed 2026-10-07:** known source behaviour, monitored |
| O-P2B-8 | Legacy `N-DC-0xx` reason codes (2022 to October 2023) are not in `dim_nphies_reason` and map to Unknown (`-1`): 2,133,373 `fact_claim_line` lines (97.5% of the 2022 latest live rejected value, 54.1% of 2023) and 237,346 pre-authorisation lines (193,980 rejected). The user decided on 2026-10-05 to leave them unmapped | Claim and pre-auth reasons for 2022–2023 | Closed: left as Unknown by decision |
| O-P2B-9 | Branch 6 has claim-response pulls every month from 2025-06 to 2026-10 (first 2025-04-28), so it has no gap; branch 8's last claim-response pull is 2026-05-07 while its pre-authorisation pulls continue to 2026-10-04. The user confirmed on 2026-10-05 that ingestion is complete, so branch 8 has received no claim responses since then | Branch 8 claim KPIs | Closed: source behaviour; warn monitor shows it |
| O-P2B-10 | Meaning of negative early fees (positive in 2024–25, negative in 2026); the user is asking finance | Remittance fee reporting | Open: reported signed as received |
| O-P2B-11 | Branch 8 February–March 2026 claim visits duplicate branch 7's: 811 visits (86 in February, 725 in March) carry the same `visit_id` and `api_trans_id` in both branches. The user confirmed on 2026-10-05 that this is a source problem, to be left as is | Branch 7 and 8 claim KPIs for 2026-02 and 2026-03 | Closed: counted in both branches (source) |
| O-P2B-12 | Some payers re-issue a revised reconciliation for the same payment date with a different total, so earlier details appear again (mostly payers without a payment identifier: Al Rajhi Takaful, GIG, SAICO; also one TPA page set); `warn_duplicate_claim_payments` lists them (2,661 details, about 0.98M SAR repeated in branches 1–5 at the 2026-10-05 build) | Remittance totals | Both versions counted. **Closed 2026-10-07:** known source behaviour, monitored |

---

## 11. Changes during implementation (2026-10-05)

1. `fact_claim_line.rejected_amount` is outcome-aware (Rejected: submitted or claimed; Approved: 0; otherwise submitted − coalesce(nullIf(eligible, 0), benefit + patient share/copay), floored at 0), because payers omit `eligible` on approved items and send `eligible = submitted` on rejected ones.
2. `submitted_amount` falls back to `claimed_amount` for adjudicated lines, and response reasons apply only to adjudicated lines.
3. `int_claim_payment` keeps only the latest pull of each PaymentReconciliation, identified by content (payment identifier, date and amount; without an identifier, date, amount and a hash of the sorted detail claim ids and amounts), because payers re-issue a new `fullUrl` per pull, reuse ids across payments and page large payments; `claim_payment_key` = (branch, `reconciliation_id`, `detail_index`). The same reconciliation was re-pulled up to about 1,848 times (3.01bn of payment details loaded, 0.63bn distinct). Remitted totals at the 2026-10-05 build: payment 634.4M SAR and advance 188.4M SAR (the earlier `fullUrl` identity gave 644.0M and 372.4M).
4. Claim responses (`int_claim_submission`, `int_nphies_adjudication`) match their transaction by `about_api_trans_id`, falling back to the ClaimResponse `request.identifier`.
5. Pre-authorisation validity dates parse the first 10 characters, because payers send ISO datetimes.
6. `rec_claims_monthly`: approved, rejected, adjudicated submitted and pending exclude cancelled claims; `resubmission_recovery` is approved on the latest non-cancelled submission with `submission_number > 1`; remittance fees are two signed columns `remitted_early_fee` and `remitted_nphies_fee`. `rec_preauth_monthly` also has `rejected_reason_unknown`.
7. `is_latest_submission` is the last submission whether cancelled or not; KPIs also filter `is_cancelled_claim = 0`.
8. The `invoice_key` warn is not the invoice window: claim invoice numbers are partly a different number space (about 25K invoices absent from AR, about 22K matching only another branch's numbers); section 9 and the column description are corrected.
9. Advance authorisations are monitored from `stg_oasis__pull_responses` and not parsed.
10. Open items O-P2B-6 to O-P2B-10 added: early-2022 null statuses, claim-level answers without items, legacy `N-DC-0xx` reason codes, branch 6 and 8 pull gaps, and negative early fees.
11. Claim responses with a null `res_status` take their status from the ClaimResponse adjudication-outcome extension, else its `outcome` (section 6.3), for the final-response choice, `final_status` and `adjudication_status`.
12. `int_nphies_adjudication` reads claim-response and priorauth-response pulls only; advanced-authorization pulls are not parsed (section 6.1).
13. `warn_unmatched_claim_payments` leaves out advance lines; `warn_duplicate_claim_payments` added (O-P2B-12); `fact_claim_payment.patient_key` has a relationships test.
14. `fact_claim_payment` drops 213 details with payment dates in 2078 and 2115 (outside the window); Rejected lines may keep a token benefit in `approved_amount` (section 7.2); days to payment is reported as medians per payment month; `rec_claims_monthly.first_pass_*` include cancelled claims.
15. Open items O-P2B-2, O-P2B-6, O-P2B-8 and O-P2B-9 re-measured; O-P2B-11 (branch 8 visits duplicating branch 7) and O-P2B-12 (revised reconciliations) added.
16. 2026-10-07 (O-P2B-5): `fact_claim_line.rejected_amount` for partially approved lines subtracts the payer's `tax`: submitted includes VAT while eligible and benefit exclude it, so VAT was counted as rejected (August 2026: about 1.0M in branch 2, 1.35M in branch 3, 0.61M in branch 4).
17. 2026-10-07 (O-P2B-5): `fact_claim_line.legacy_in_scope` = the line's invoice and NPHIES transaction are on an AR statement (`stg_oasis__episode_invoices.api_trans_id` and `stat_invoice_no` joined to `stg_oasis__invoice_statements`), the scope of the old claims model and `bsc.vw_rcm`; `rec_claims_monthly.legacy_*` sum over it.
18. 2026-10-07 (O-P2B-3, section 12): advance authorisations are parsed in `int_nphies_advance_authorisation` and reach `int_preauth_line` and `fact_preauth_line` as `Payer advance` rows; items 9 and 12 no longer hold for them. Details settled in implementation:
    - Outcome: when the ClaimResponse has no `adjudication-outcome` extension (1,485 authorisations whose latest pull is `COMPLETE`), the `addItem[]` outcomes are used (all equal: that outcome; differing: partial); 117 remain Unknown. Statuses are the outcome code upper-cased (`APPROVED`, `PARTIAL`, ...), and final and last response times are the kept pull's time; `response_count` = `pull_count`.
    - `payer_eligible_amount` is parsed like the other amounts (`total[]`, else the `addItem[]` sum). `created` and `preAuthPeriod` are read as KSA wall clock from the first 19 / 10 characters (payers send offsets such as `+03:03`).
    - Episode by reference only among candidates of the linked patient (a `preAuthRef` value matched several patients' episodes for 2,033 of the 4,601 authorisations with a reference match); the earliest-starting candidate is linked and `episode_match_count` counts the reference candidates when one matched, else the episodes in the validity period. Without a linked patient there is no episode. `episode_link_method` (Reference, Validity period) is kept. `stg_oasis__preauth_api_requests` gains `referral_pre_auth_ref`.
    - `fact_preauth_line`: for advance rows care type comes from `subType` (op, ip, emr to OP, IP, ER) even when an episode is linked; `is_delivered` and `is_approved_not_delivered` are 0 and `total_turnaround_minutes` is null; `is_latest_request_for_service` and `legacy_is_last_request` are 0 and computed in a separate window partition so hospital lines keep their flags.
    - Monitors: `warn_advance_authorisations` now lists branch-months with advance authorisations that have no patient or an Unknown outcome (with episode counts); `warn_preauth_outcome_unknown` leaves advance rows out.
    - Measured at the 2026-10-07 build: 46,622 authorisations (2026: 16,416, 1,537,860 SAR); patient linked 77.5% (2026: 73.1%; 2,102 identity values held by several patients, 8,409 by none); episode linked 63.6% (4,258 by reference, 25,377 by validity period; 11,290 with more than one candidate). `rec_preauth_monthly` hospital columns unchanged for every branch and month.

---

## 12. Payer advance authorisations (O-P2B-3, decided 2026-10-07)

**Decision (user).** Payer-initiated advance authorisations (pull `response_type = 'advanced-authorization'`) are parsed at header level and added to `fact_preauth_line` as rows with `line_source = 'Payer advance'`. The Oasis-stored copies that already reach `int_preauth_line` as responses to hospital requests (about 7,075 rows) are kept as they are.

**Findings (measured 2026-10-07).** 55,232 pulls are 46,622 authorisations (16,416 in 2026, 1.54M SAR approved). Every bundle has a MessageHeader (event `advanced-authorization`), a ClaimResponse (`use = preauthorization`, outcome `complete`, never `item[]`; 35,727 have `addItem[]` whose sequence is in `extension-sequence`), a Patient and Organizations. `request` cannot link to an Oasis transaction. One branch 6 authorisation was pulled 3,470 times. In 2026, 39% carry a zero amount and Tawuniya sends many 1-SAR placeholders. 58% overlap with the hospital's own requests for the same patient in the validity window.

**Rules.**
1. One authorisation per (branch, payer licence, `preAuthRef`); the latest pull (by `responded_at`, then `response_id`) wins; `pull_count` is kept. Payer licence = the insurer Organization's identifier, else the MessageHeader sender.
2. `line_natural_id` = `V` + payer licence + `-` + `preAuthRef`; `requested_at` = ClaimResponse `created`; `preauth_reference`, `preauth_valid_from/to` from `preAuthRef` and `preAuthPeriod`; outcome from the `adjudication-outcome` extension; `advance_reason` from `advancedAuth-reason` (referral, authorization, refill, non-network); `referring_provider_name` from `referringProvider`; care type from `subType` (op, ip, emr).
3. Amounts: `payer_approved_amount` (and `nphies_approved_amount`) = the `total[]` benefit, else the sum of `addItem[]` benefit; submitted likewise into `estimated_amount`. Amounts are kept as sent (0 and 1-SAR placeholders included).
4. Patient: the Patient identifier is matched to `stg_oasis__patient_ids` of the branch, unique match only. The identity value is used for the join inside intermediate only and never reaches gold.
5. Episode: first by reference (a claim line whose `pre_auth_id` or an Oasis request whose referral pre-auth reference equals `preAuthRef`), else the patient's first episode starting inside the validity period; `episode_match_count` keeps the number of candidates so ambiguous links can be filtered. The purchaser comes from the linked episode.
6. KPIs: payer advance rows carry no request, send or turnaround and are excluded from the existing pre-authorisation KPIs (services, requests, approval and rejection rates, lost revenue); they are reported as their own count and amount (`line_source = 'Payer advance'`). `rec_preauth_monthly` adds the count and approved amount of payer advance authorisations per branch and month.
