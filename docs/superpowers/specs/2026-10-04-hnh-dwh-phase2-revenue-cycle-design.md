# HNH Data Warehouse — Phase 2 Revenue Cycle Design

- **Date:** 2026-10-04
- **Status:** Draft for review
- **Parent spec:** `docs/superpowers/specs/2026-10-01-hnh-dwh-gold-layer-design.md`. Everything there (layers, keys, staging conventions, portability, security, testing policy) applies unless this document says otherwise.
- **Scope:** Phase 2A in full (charges, revenue, invoices, revenue adjustments, patient receipts, pre-authorisation). Phase 2B (claim lines) is outlined in section 10 and gets an addendum once its source is ingested.

---

## 1. Purpose and decisions

Replace the revenue logic of the old warehouse (`mv_revenue_dataset`, `_details`, `_pk`, `vw_discounts`, `vw_tr_ar_invoices*`, `vw_authorizations`, `bsc.vw_customer` revenue, `bsc.vw_rcm`) and the revenue content of the *Executive Dashboard*, *Outpatient Dashboard*, *Client Profile*, *claims* and *RCM Authorization* Power BI models with one set of facts, each KPI defined once.

Decisions made in review (2026-10-04):

| # | Decision |
|---|---|
| D1 | Phase 2 covers operational revenue, billing, claims, pre-authorisation, and collections. |
| D2 | Split: **2A** (this spec) is built now. **2B** (claim lines with adjudicated amounts) waits for the NPHIES pull-response table to be ingested into `oasis`; the user owns that ingestion. |
| D3 | Insurer collections and AR ageing move to **Phase 3 (Finance)**, sourced from Fusion AR. Oasis keeps only patient receipts (section 7.3). |
| D4 | Every charge line carries two payer keys: who the line is billed to, and the episode's payer. |
| D5 | Only the package header line is recognised revenue. Package component lines stay in the fact for charge analysis and package profitability. |
| D6 | `price_paid_purchaser` is the net amount. The line discount (`discount_given`) and the post-invoice discount are different things and are kept apart. |
| D7 | Medication revenue = product category in the medication list, or delivered by a pharmacy work entity. |
| D8 | Pre-authorisation follows the RCM Authorization report's KPI set, with its defects corrected and legacy fields kept. |

---

## 2. Findings that shape the design

Measured on 2026-10-04 against ClickHouse 26.5 (`172.22.25.214`).

### 2.1 Sources

| Concept | Oasis tables | Rows | Grain | History |
|---|---|---|---|---|
| Charges | `delivery_charge`, `delivery_lines`, `master_deliveries` | 108.6M / 96.4M / 25.9M | `delivery_charge_id` | 2017–2020 by branch; branches 6 from 2024-08, 7–8 from 2025-12 |
| AR documents | `doc` (`docl` not needed) | 126.8M (all types) | `doc_id` | — |
| Episode invoices | `ar_episode_invoices` | 3.82M (3.71M distinct) | `invoice_no` | 2015–2022 by branch |
| Statements | `ar_stat_of_invoices` | 576K | `stat_invoice_no` | 2022-01 |
| Pre-auth (Oasis) | `authorisations_master`, `authorisations` | 3.1M / 6.8M | `request_no` / `authorisation_no` | 2022-01 |
| Pre-auth (NPHIES) | `api_pre_approval_req(_details)`, `api_pre_approval_res(_details)` | 2.6M / 8.4M / 5.0M / 6.3M | `api_trans_id`, item | 2022-01 |
| Service catalogue | `ios_master_data`, `ios_main_data`, `policies` | 983K / 788K / 415K | `ios`, `ios_main`, `policy_code` | — |
| Claims (2B) | `claim_visit_detail`, `claim_service_detail` | 4.2M / 24.1M (2.7M distinct per 4.8M raw in 2026) | `visit_id`, `service_id` | 2022-01 |

`oasis` has no NPHIES pull-response table (`DEVDBA.API_PULL_RESPONSE_DETAILS`), so no approved or remitted claim amount exists in the warehouse today. Fusion AR (`fusion.fact_ar_*`) starts in April 2026 and covers some ledgers only.

### 2.2 Facts

| # | Fact | Consequence |
|---|---|---|
| R1 | `delivery_charge.cancel_flag`: null = live, `C` = cancelled (with `status_reason_code`), `R` = a superseded version. Every delivery line has exactly one live row; `R` rows always carry a credit document (`crd_doc_id`), and those credit notes equal Σ `R` lines to the cent (episode 1-902748-1: −976,581.77). `R` rows are ~40% of a month's charge value. | Revenue uses live rows only. `R` rows are excluded from the fact. |
| R2 | `price_paid_purchaser` is net. Per invoice document, Σ `price_paid_purchaser` = `doc.total_doc_price` and Σ `discount_given` = `doc.total_doc_disc` (18,022 of 18,070 documents). | Gross = net + line discount, at line level. No fan-out possible. |
| R3 | `delivery_charge.invoice_no` = `doc.doc_no` of `doc_id` (100% of rows sampled). Prefix by bill-to: `CRD` = 1 (purchaser), `PAT` = 2, `CSH` = 3. These are billing documents, not episode invoices. | Charges reach episode invoices through the episode, not by key. |
| R4 | Live charges are invoiced almost immediately: uninvoiced live value is below 0.01% in every month May–September 2026. | Revenue is dated on the delivery date. The legacy `doc_id != 0` filter is immaterial. |
| R5 | What the payer is billed (Alrabwah, episodes invoiced 1–7 May 2026, all invoices of each episode): OP 1,994 of 1,994 episodes and IP 207 of 244 have invoice net = Σ live, non-component, bill-to-1 `price_paid_purchaser`. Including package components, IP matches drop to 66. | Confirms D5 and the claimable-revenue rule. |
| R6 | The 37 IP mismatches in R5 are all long-stay contract episodes (`DIR-` accounts, 20–50 fixed monthly invoices). Invoices exceed charges (episode 902748-1: 1,994,622 invoiced vs 1,797,479 charged). The gap is not `R` lines. About 6% of the sample's IP invoiced value. | `fact_invoice` is the source for billed amounts; the gap is shown by reconciliation (open item O-P2-2). |
| R7 | The patient's co-pay is on bill-to **3** (`CSH`) for OP and bill-to **2** (`PAT`) for IP. | Patient share is identified by a sibling bill-to-1 row on the same delivery line, not by bill-to value alone. |
| R8 | No delivery line spans more than one delivery date (0 of 220,120 lines, branches 1 and 4, 1–14 June 2026). | A co-pay and its purchaser row always share a delivery date. |
| R9 | Post-invoice discounts are `CREDITAR` documents numbered `<invoice doc_no>D` (Alrabwah June 2026: 1,667 documents, −50,141). `SYSDPRC` documents also end in `D` but are fixed-asset depreciation. | Only `CREDITAR …D` documents whose base is a charge invoice are revenue adjustments. |
| R10 | Package components (`package_deal_flag = 'Y'`) carry item prices (~74M SAR in June 2026) and are invoiced on their own documents; headers and components never share a document. | Component value is kept as `package_content_amount`. |
| R11 | Statements: `cancelled_flag` is never `Y`; `unalloc_amount` ≈ `stat_total` in every branch and year except branch 5. Insurer payments are not allocated in Oasis. | No insurer AR from Oasis (D3). |
| R12 | Patient receipts: `doc_type = 'RECEIPT'`, `CSH…` (cashier) and `RCT…` (AR cash). `ext_ref` = patient id, `ext_acc_doc_no` = episode. | `fact_cash_receipt` keys come from the document. |
| R13 | Invoice approval status uses `codes_data` code type 5116, matched on `user_code`, identical in all 8 branches (A, PARTIAL, S, R, V, E, I, PAID, F, C, IR, QUEUED, N, P, D, PAY_NOTED, PARSE_FAIL). | One decode; `map_claim_status` maps the description to a submission status. |
| R14 | Invoice `account_code` → `policies.account_no` → purchaser matches 25,725 of 25,741 accounts. Matching on `purchasers.account_code` matches 1. | Invoice payer is resolved through the policy. |
| R15 | Pre-auth: NPHIES request items link to the Oasis authorisation line for 96% (`authorisation_no`) and to a response for 98% (`api_trans_id`). June 2026 had 597K responses for 324K requests. Response line `outcome_reason_code` is never filled; payer comments are free text in `error_text`. `authorisations.amount_authorised` sums to 1.58B SAR for June requests (implausible). | Deterministic final-response pick; no reason codes for pre-auth; the NPHIES `approved_amount` is used. |
| R16 | `authorised_flag` values: `Y`, `N`, `R`, `Z`, `C`, `H`, null. The legacy CASE handles only `S`+Y/H/N/R, `P`+N, `O`+N. | `Z` and `C` meanings to be confirmed (open item O-P2-1). |
| R17 | Pharmacy work entities are entity type `P`. | Used by the medication rule. |
| R18 | `delivery_charge.encounter_id` is the Oasis encounter id, which (Oasis view `PATIENT_VALID_ENCOUNTERS`) is the `appointment_id` (type `O`), the `admission_no` (the admission's attendance type) or the `er_visit_id` (type `E`) — the same three ids Phase 1 keys encounters on. Alrabwah live charges, 1–2 June 2026, same patient required: inpatient 14,890 of 14,890 match an admission; type `E` 145 of 145 an ER visit; type `O` 2,022 of 2,046 an appointment; untyped outpatient 9,507 of 9,676 an appointment (8,133) or ER visit (1,374). On outpatient charges `admission_no` usually holds the encounter id (9,279 of 9,676), not an admission. | Charges carry `encounter_key`; the admission and LTC flag come from the resolved inpatient encounter, never from `admission_no`. |

---

## 3. Architecture

Same layers, tags and folders as Phase 1 (parent spec 3.1–3.6).

```
models/hnh/
  staging/oasis/        + 13 models (section 4)
  staging/reference/    + stg_ref__product_category, stg_ref__claim_status, stg_ref__nphies_reason
  intermediate/revenue/ int_invoice_payer, int_preauth_line
  marts/conformed/      + dim_service, dim_product_category, dim_preauth_outcome
  marts/revenue/        fact_charge_line, fact_revenue_adjustment, fact_invoice, agg_episode_billing,
                        fact_cash_receipt, fact_preauth_line
  marts/reconciliation/ + rec_revenue_monthly, rec_billing_monthly, rec_preauth_monthly
macros/hnh/hnh_rules_revenue.sql
tests/hnh/              + revenue singular tests; intermediate/revenue/_revenue_unit_tests.yml
```

**Exception to parent spec 3.1.** `fact_charge_line` (about 66M rows after superseded rows are dropped) reads staging directly, with no `int_charge_line`: a 105M-row intermediate rebuilt every night would double the heaviest work of the build. The rules live in `hnh_` macros, so they are still defined once.

**Build.** `fact_charge_line` is rebuilt in full every night like the other Phase 2 models. It was planned as incremental, but a full build measured about 2.5 minutes (66M rows) and an incremental build cannot stay equal to a full refresh: the LTC flag of open stays changes daily and episodes can arrive after their charges.

---

## 4. Staging

Conventions as parent spec 3.4 (`FINAL`, `Int64` ids, KSA wall-clock re-labelling, `Y`/`N` → `UInt8`).

| Model | Source | Notes |
|---|---|---|
| `stg_oasis__charges` | `delivery_charge` | All rows; `cancel_flag`, `bill_to`, `package_deal_flag`, `patient_share_type` kept raw. `staff_id` cast to `Int64` (null when not numeric). |
| `stg_oasis__delivery_lines` | `delivery_lines` | `master_delivery_no`, `order_line`, `product_code` |
| `stg_oasis__master_deliveries` | `master_deliveries` | `delivery_work_entity` |
| `stg_oasis__ar_documents` | `doc` | `doc_type IN ('INVOICEAR','CREDITAR','DEBITAR','RECEIPT')` and `doc_status = 'P'`. This is a filter on a 126.8M-row table holding GL, stock and payroll documents; it is the only row filter in staging, justified by size. |
| `stg_oasis__episode_invoices` | `ar_episode_invoices` | |
| `stg_oasis__invoice_statements` | `ar_stat_of_invoices` | |
| `stg_oasis__ios_master` | `ios_master_data` | |
| `stg_oasis__ios_main` | `ios_main_data` | Selected columns only (description, product category, type, accommodation flag). |
| `stg_oasis__policies` | `policies` | |
| `stg_oasis__authorisation_requests` | `authorisations_master` | Request date `1900-01-01` → null. |
| `stg_oasis__authorisations` | `authorisations` | |
| `stg_oasis__preauth_api_requests`, `stg_oasis__preauth_api_request_items` | `api_pre_approval_req`, `_details` | Member name, mobile, iqama and free-text clinical fields excluded. `estimated_cost` cast with `toFloat64OrNull(replace(x, ',', '.'))`. |
| `stg_oasis__preauth_api_responses`, `stg_oasis__preauth_api_response_items` | `api_pre_approval_res`, `_details` | Member name and identifiers excluded. |

Reference sources (already loaded in `default`, declared in `_reference__sources.yml`): `map_product_category`, `map_claim_status`. New: `default.map_nphies_reason` (code, description, category) with the 73 NPHIES rejection codes currently embedded in the claims Power BI model, loaded once by `scripts/load_reference_data.py`. Used by 2B; created in 2A so the dimension and loader are tested early.

---

## 5. Rules (macros, `hnh_rules_revenue.sql`)

| Macro | Rule |
|---|---|
| `hnh_charge_status(cancel_flag)` | null → `Live`, `C` → `Cancelled`, `R` → `Superseded`, else `Unknown` |
| `hnh_is_recognised_revenue(cancel_flag, package_deal_flag)` | live and `ifNull(package_deal_flag,'N') != 'Y'` |
| `hnh_is_medication(product_category_code, delivery_entity_type)` | category in `MD, MED, PH, CSM, RTL, MLK` (the list used identically by `vw_pharmacy_revenue`, `mv_pharmacy_revenue`, `vw_pharmacy_consumption` and both incentive views) or entity type `P` |
| `hnh_billed_payer(bill_to, purchaser_code, has_purchaser_sibling)` | bill-to `1` → purchaser (0 or null → 9999); bill-to `2`/`3` with a live bill-to-`1` row on the same delivery line → `8888`; otherwise purchaser (0 or null → 9999) |
| `hnh_charge_care_type(episode_care_type, attendance_type)` | episode care type; if missing, `I` → IP, `O` → OP, else Unknown |
| `hnh_preauth_outcome(nphies_status, authorised_flag, request_status)` | section 8 |

---

## 6. Dimensions

### dim_service
Key `(branch_id, ios)`. IOS user code, description, IOS type, IOS category, service department; IOS main code and description, accommodation flag; product category code with `group`, `unified_category`, `department`, `high_level_dept` from `map_product_category` (`Not Mapped` when absent). Unknown member `-1`.

### dim_product_category
Key `(branch_id, category_code)`. From `map_product_category`, plus every category code found on charges (`Not Mapped` attributes). Unknown member `-1`.

### dim_preauth_outcome
Static: `Approved`, `Partially approved`, `Not required`, `Rejected`, `Pended`, `Error`, `Cancelled`, `Not sent`, `Unknown`, with `is_approved` (first three).

### Existing dimensions reused
`dim_branch`, `dim_date`, `dim_time`, `dim_patient`, `dim_staff`, `dim_department`, `dim_payer` (unchanged; synthetic `9999` Cash and `8888` Deductible already exist), `dim_care_type`.

`int_invoice_payer`: grain `(branch_id, account_code)` → `purchaser_code` through `policies.account_no`. If an account maps to several purchasers, the lowest `policy_code` wins (deterministic; a warn test lists such accounts).

---

## 7. Facts

All facts carry `branch_key`, `_loaded_at`, never-null dimension keys (`-1` for missing), and honour `history_start_date`.

### 7.1 fact_charge_line

**Grain:** one `(branch_id, delivery_charge_id)` with `delivery_date >= history_start_date` and `cancel_flag` null or `C`. `R` rows are excluded.

**Keys:** `charge_line_key`; `delivery_date_key`, `delivery_time_key`; patient, episode, encounter, admission; ordering staff (`staff_id`); performing department (`master_deliveries.delivery_work_entity`); service (`ios`); product category (line `product_category_code`); `billed_payer_key`, `episode_payer_key` (from `int_episode`); care type.

**Encounter resolution (R18).** `encounter_id` is looked up in `int_encounter` on branch, `source_id = encounter_id` and the same patient. The encounter type is chosen from the charge: an inpatient charge (`attendance_type = 'I'`) → `IP`; `encounter_type = 'E'` → `ER`; `encounter_type = 'O'` → `OP`; no type → `OP` if an appointment matches, else `ER`. `encounter_key = hnh_surrogate_key([branch_id, resolved type, encounter_id])`, the Phase 1 key; unresolved → `-1`. `admission_key`, `admission_no` and `is_ltc` (from `int_admission`) are set only when the resolved type is `IP`. Facts are not related to each other in SSAS (receiving notes), so `encounter_key` serves SQL analysis and later aggregates such as revenue per visit.

**Attributes:** `charge_status`, `cancel_reason_code`, `bill_to`, `invoice_doc_no`, `package_id`, `encounter_id`, `encounter_type` (as charged), `resolved_encounter_type`, `is_package_component`, `is_patient_share`, `is_cash_billed` (bill-to 2 or 3 without a purchaser sibling — patient-paid with no insurer on the line, outpatient or inpatient), `is_medication`, `is_ltc`.

**Measures:**

| Column | Rule |
|---|---|
| `units` | `units_delivered` |
| `net_amount` | `price_paid_purchaser` |
| `line_discount_amount` | `discount_given` |
| `gross_amount` | `net_amount + line_discount_amount` |
| `vat_amount` | `vat_value` |
| `is_recognised_revenue` | `hnh_is_recognised_revenue` |
| `revenue_amount` | `net_amount` if recognised, else 0 |
| `package_content_amount` | `net_amount` if live package component, else 0 |
| `is_claimable` | recognised and bill-to `1` |
| `claimable_amount` | `net_amount` if claimable, else 0 |

**Legacy fields:** `legacy_in_revenue` (`ifNull(package_deal_flag,'N')='N'` and `ifNull(cancel_flag,'X')='X'` and `doc_id != 0`), `legacy_revenue_amount` (`price_paid_purchaser` when `legacy_in_revenue`), `legacy_trans_purchaser`, `legacy_patient_purchaser` (the old 8888/insurer logic of `mv_revenue_dataset`), `legacy_care_type` (`O` → OP, `E` → ER, else IP).

### 7.2 fact_revenue_adjustment

**Grain:** one `CREDITAR` document whose `doc_no` ends in `D` and whose base number equals the `doc_no` of an `INVOICEAR` charge document.
**Keys:** `adjustment_date_key` (document date); patient, episode, billed payer, care type — taken from the base document's live lines (the most frequent value; ties broken by lowest key).
**Measures:** `adjustment_amount` (`total_doc_price`, negative), `base_invoice_net_amount`.

Net revenue after adjustments = Σ `fact_charge_line.revenue_amount` + Σ `fact_revenue_adjustment.adjustment_amount`.

### 7.3 fact_cash_receipt

**Grain:** one patient receipt: a `doc_type = 'RECEIPT'` document on account `CASHACC`, with no account, or on the patient's own account (account code equal to the patient number in `ext_ref`) (`CSH…` cashier receipts, `RCT…` AR cash receipts, `REC…` receipts), `receipt_type` from the prefix. Receipts on insurer, contract and other accounts are excluded (D3) and listed by `warn_excluded_receipt_accounts`.
**Keys:** `receipt_date_key`; patient (`ext_ref`), episode (`ext_acc_doc_no`), user.
**Measures:** `receipt_amount` (`-total_doc_price`, so receipts are positive).
`CSH…` `CREDITAR` documents are not treated as refunds: cash charges are also re-billed (`R` rows with bill-to 3), so these credit notes are at least partly reversals of superseded charges (open item O-P2-7). Insurer collections are out of scope (D3).

### 7.4 fact_invoice

**Grain:** one `(branch_id, invoice_no)` from `ar_episode_invoices` with `invoice_creation_date >= history_start_date`, joined to its statement on `stat_invoice_no`.
**Keys:** patient, episode, care type (episode; else `attendance_type`), payer (`int_invoice_payer`); `invoice_date_key`, `service_start_date_key`, `service_end_date_key`, `statement_end_date_key`, `statement_sent_date_key`, `statement_approved_date_key`. `stat_invoice_no` and `account_code` as degenerate attributes.
**Measures:** `gross_amount`, `discount_amount`, `net_amount` (billed to the payer), `vat_amount`, `total_amount`.
**Status:** `approval_status_code`, `approval_status` (code type 5116 on `user_code`), `submission_status` and `validation_status` (`map_claim_status` on the description; unmatched → `New`), `is_verified` (statement `approved_by` present), `is_sent` (statement send date present), `is_cancelled_statement`, `claim_type`.
**Legacy:** `legacy_is_verified` (`APPROVED_BY != ''`, the Client Profile filter).

### 7.5 agg_episode_billing

**Grain:** one episode with any claimable charge or any invoice.
**Measures:** `claimable_amount` (Σ `fact_charge_line.claimable_amount`), `invoiced_net_amount` (Σ `fact_invoice.net_amount`), `unbilled_amount` (difference, floored at 0), `overbilled_amount` (negative difference, floored at 0), `invoice_count`, `first_invoice_date_key`, `last_invoice_date_key`, `is_long_stay_contract` (any invoice account starting `DIR-` and more than 12 invoices).
Replaces the claims model's "Not Billed" and makes the R6 gap visible.

### 7.6 int_preauth_line and fact_preauth_line

**Grain:** one Oasis authorisation line `(branch_id, authorisation_no)` with request date `>= history_start_date`, plus NPHIES request items with no Oasis line (natural key `(branch_id, api_trans_id, item_no)`, `authorisation_no` null).

**Responses.** All responses for the request item's `api_trans_id`, matched to the item by `item_no`. **Final response:** the latest by `creation_date`, then highest response item id, whose status is not `PENDED`, `QUEUED` or an error; if none, the latest of any status. First response and last raw response are kept separately.

**Keys:** patient, episode, payer (request purchaser), service (`ios`), requesting department (`service_dept`), requesting staff, care type; `request_date_key`, `first_sent_date_key`, `final_response_date_key`.

**Attributes:** `preauth_outcome` (section 8), `nphies_final_status`, `nphies_first_status`, `nphies_last_status`, `oasis_line_status`, `authorised_flag`, `is_status_override` (Oasis line approved and NPHIES final rejected, or the reverse), `payer_comment` (`error_text`), `is_transfer`, `has_communication_request`, `treatment_type`, `service_type`, `diagnosis_code`.

**Measures and flags:**

| Column | Rule |
|---|---|
| `requested_qty`, `approved_qty`, `used_qty` | `no_requested`, `no_authorised`, `no_used` |
| `estimated_amount` | request item `estimated_cost` |
| `approved_estimated_amount` | `estimated_amount / requested_qty * approved_qty` (null when `requested_qty = 0`) |
| `nphies_approved_amount` | final response item `approved_amount` |
| `request_send_count`, `response_count` | counts across the request's transactions |
| `is_resubmitted` | `request_send_count > 1` |
| `is_first_response_approved` | first response status is APPROVED |
| `request_to_sent_minutes` | request date → first sent |
| `sent_to_response_minutes` | first sent → final response |
| `total_turnaround_minutes` | request date → final response |
| `is_delivered` | a live charge with the same patient, episode and `ios`, delivered on or after the request date |
| `is_approved_not_delivered` | approved outcome (`Approved` only, as the report) and not delivered |
| `is_delivered_not_approved` | delivered and outcome `Rejected` |
| `is_latest_request_for_service` | the highest `request_no` for the same patient, episode and `ios` |

Durations use the parent spec's guard (below 0 or above 1,440 minutes → null, raw value in `*_raw`).

**Legacy fields:** `legacy_line_status` (the old CASE on request status and `authorised_flag`), `legacy_last_service_status` (last response status, any), `legacy_is_last_request` (highest `request_no` per patient and episode), `legacy_sent_to_response_minutes` (first sent → last response).

---

## 8. Pre-authorisation outcome

`preauth_outcome` from the final NPHIES status when the item was sent:

| NPHIES final status | Outcome |
|---|---|
| `APPROVED`, `approved`, `ALL LISTED SERVICES ARE APPROVED`, `ACCEPT.`, texts starting `APPROVED` | Approved |
| `PARTIAL` | Partially approved |
| `NOT-REQUIRED` | Not required |
| `REJECTED` | Rejected |
| `PENDED`, `QUEUED BY NPHIES` | Pended |
| `ERROR`, `ERROR BY NPHIES` | Error |

When nothing was sent, from the Oasis line: request status `S`/`P` with `authorised_flag` `Y` → Approved, `R` → Rejected, `Z` → Not required, `C` → Cancelled, `H` → Pended; request status `O` or flag `N` with no transaction → Not sent. Anything else → Unknown (warn test).

---

## 9. KPI definitions

| KPI | Definition | Fact |
|---|---|---|
| Revenue | Σ `revenue_amount` | `fact_charge_line` |
| Net revenue after adjustments | Revenue + Σ `adjustment_amount` | both |
| Gross charges | Σ `gross_amount` where recognised | `fact_charge_line` |
| Line discount | Σ `line_discount_amount` where recognised | `fact_charge_line` |
| Post-invoice discount | Σ `adjustment_amount` | `fact_revenue_adjustment` |
| VAT | Σ `vat_amount` where recognised | `fact_charge_line` |
| Claimable revenue | Σ `claimable_amount` | `fact_charge_line` |
| Patient share (deductible) | Revenue where `is_patient_share` | `fact_charge_line` |
| Cash revenue | Revenue where `is_cash_billed` | `fact_charge_line` |
| Revenue by payer | Revenue by `billed_payer_key` | `fact_charge_line` |
| Revenue from a payer's patients incl. co-pay | Revenue by `episode_payer_key` | `fact_charge_line` |
| Medication revenue | Revenue where `is_medication` | `fact_charge_line` |
| Package content value | Σ `package_content_amount` | `fact_charge_line` |
| Cancelled charges | Σ `net_amount` where `charge_status = 'Cancelled'` | `fact_charge_line` |
| Billed amount | Σ `net_amount` | `fact_invoice` |
| Verified billed amount | Billed where `is_verified` | `fact_invoice` |
| Unbilled amount | Σ `unbilled_amount` | `agg_episode_billing` |
| Patient collections | Σ `receipt_amount` | `fact_cash_receipt` |
| Pre-auth services | Count of lines | `fact_preauth_line` |
| Pre-auth requests | Distinct `(branch, request_no)` | `fact_preauth_line` |
| Pre-auth approval rate | Lines with `is_approved` **and** `has_final_response` ÷ lines with `has_final_response` (sent with a final non-pended, non-error response) | `fact_preauth_line` |
| Pre-auth rejection rate | `Rejected` and `has_final_response` ÷ the same denominator | `fact_preauth_line` |
| Approved first time | `is_first_response_approved` ÷ approved lines | `fact_preauth_line` |
| Resubmission rate | Requests with `is_resubmitted` ÷ requests | `fact_preauth_line` |
| Transfer rate | `is_transfer` ÷ lines | `fact_preauth_line` |
| Turnaround | Average and median of `request_to_sent_minutes`, `sent_to_response_minutes`, `total_turnaround_minutes` | `fact_preauth_line` |
| Unutilised approvals | `is_approved_not_delivered` count ÷ lines | `fact_preauth_line` |
| Lost revenue | Σ `approved_estimated_amount` where `is_approved_not_delivered` and `is_latest_request_for_service` | `fact_preauth_line` |
| Rejected revenue | Σ `estimated_amount` where `Rejected` and `is_latest_request_for_service` | `fact_preauth_line` |
| Delivered without approval | `is_delivered_not_approved` count and Σ `estimated_amount` | `fact_preauth_line` |

### Corrections relative to the old logic

| Old behaviour | Correction | Legacy field |
|---|---|---|
| Invoice discount joined to every charge line and repeated once per dimension combination (`mv_revenue_dataset*`, `test.vw_revenue`) | Line discount on the line; post-invoice discount in its own fact | `legacy_revenue_amount` |
| Discount part ignored cancellation and packages | Only `CREDITAR …D` documents on charge invoices | — |
| Co-pay attributed to the insurer in some reports and to Deductible in others; trigger differs between views; deductible match can duplicate lines | Two payer keys; one sibling rule for OP (bill-to 3) and IP (bill-to 2) | `legacy_trans_purchaser`, `legacy_patient_purchaser` |
| Four different care-type mappings for revenue | Episode care type | `legacy_care_type` |
| `MD` override for four IOS codes | Dropped; the line's category | — |
| LTC flag from LOS to `now()`, joined by episode (duplicates multi-admission episodes) | `is_ltc` from the charge's resolved inpatient encounter | — |
| Medication lists differ between views | One macro | — |
| LTC ICU revenue split (`icu_services`) | Dropped (parent spec 13) | — |
| Pre-auth: last response wins even when PENDED or ERROR | Final non-pended response | `legacy_last_service_status` |
| Pre-auth: approval and rejection rates over all lines, including unsent | Sent lines with a final response | `legacy_last_service_status` |
| Pre-auth: lost revenue on the last request of the episode | Last request for the same service | `legacy_is_last_request` |
| Pre-auth: turnaround to the last response, averages cut at 480 min, median uncut | Final response, one guard for all statistics | `legacy_sent_to_response_minutes` |
| Pre-auth: "delivered" matched charges before the request | Charges on or after the request date | — |
| Statement → payer join loaded with `DISTINCT` | Deterministic `int_invoice_payer` | — |
| `Posted` approval status mapped to New; Power BI adds its own `Naphis Status` column | One mapping from `map_claim_status` | — |

---

## 10. Phase 2B outline (claims)

Starts when `DEVDBA.API_PULL_RESPONSE_DETAILS` is ingested into `oasis` (with `api_trans_id`, `about_api_trans_id`, `response_type`, `res_status`, `response_bundle`).

- Staging: `stg_oasis__claim_visits`, `stg_oasis__claim_services`, `stg_oasis__pull_responses`.
- `int_claim_adjudication`: the response bundle exploded with `LEFT ARRAY JOIN` into item × adjudication category (submitted, eligible, benefit, copay, tax) with reason codes, so items without a reason are kept. Final response per item chosen deterministically.
- `fact_claim_line`: grain `(branch_id, service_id)`. Submitted, approved and rejected amounts from the adjudication; NPHIES reason code key to `dim_nphies_reason`; visit, invoice and statement links (`claim_invoice_no`, `stat_invoice_no`); outcome. Corrections: "submitted" counts only submitted statuses; unadjudicated lines are not treated as approved; partial approvals without a reason code keep their benefit amount and get reason `Not given`.
- `rec_claims_monthly` against `bsc.vw_rcm` and the claims Power BI model.

---

## 11. Testing and reconciliation

### 11.1 dbt tests
- `unique`, `not_null` on every new grain and dimension key; `relationships` for every fact foreign key.
- `accepted_values`: `charge_status`, `bill_to`, `preauth_outcome`, `submission_status`, `receipt_type`.
- Conservation (singular): `fact_charge_line` rows = staged rows with `cancel_flag` null or `C` in the window, and every staged row left out has `cancel_flag = 'R'`; `fact_invoice` = de-duplicated `ar_episode_invoices` in the window; `fact_preauth_line` = authorisation lines in the window plus unmatched NPHIES items.
- Warn monitors: product category `Not Mapped`; invoice account without a payer; account mapping to several purchasers; `preauth_outcome = 'Unknown'`; OP episodes where invoice net ≠ claimable charges (expected 0); live charges of the last 90 days without an encounter above 2% for a care type.

### 11.2 Rule tests
Macro tests with literal inputs for every macro in section 5. Unit tests (`_revenue_unit_tests.yml`): deductible sibling match for OP (bill-to 3) and IP (bill-to 2) and for pure cash; encounter resolution, including an outpatient charge whose `admission_no` holds its appointment id (resolves to the OP encounter, no admission); final-response selection (PENDED then APPROVED; APPROVED then ERROR); `is_latest_request_for_service` with two services in one episode; post-invoice discount matched to its base document and not to `SYSDPRC`.

### 11.3 Reconciliation
- `rec_revenue_monthly` (branch × month): legacy charge revenue (Σ `legacy_revenue_amount`), legacy discount documents, new revenue, adjustments, medication revenue, revenue by care type. **Acceptance:** for a closed month agreed with the business, the legacy charge revenue matches the charge part of the old `mv_revenue_dataset` export within 0.5%; the difference between old and new totals is attributed to the corrections in section 9.
- `rec_billing_monthly` (branch × month × care type): claimable charges, invoiced net, unbilled, overbilled, long-stay contract gap.
- `rec_preauth_monthly` (branch × month): services, approved, rejected, unutilised, lost revenue — new and legacy side by side. **Acceptance:** legacy columns match the RCM Authorization report (`powerbi_tmdl/RCM Authorization/`) for the same month within 0.5%.

---

## 12. SSAS handoff additions

`fact_charge_line` relates to `dim_payer` twice (billed payer active, episode payer inactive or as a role-playing copy; decided in the SSAS design). Security as parent spec section 9: every new fact relates to `dim_branch`; facts with staff relate to `dim_staff`, missing staff → Unknown member visible to all.

---

## 13. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P2-1 | Meaning of `authorised_flag` `Z` and `C` | `fact_preauth_line` acceptance | `Z` = Not required, `C` = Cancelled |
| O-P2-2 | Long-stay contract episodes are invoiced more than their charges (R6) | Billing reconciliation sign-off | Shown in `agg_episode_billing` and `rec_billing_monthly`; finance to explain the billing method |
| O-P2-3 | Ingestion of `DEVDBA.API_PULL_RESPONSE_DETAILS` into `oasis` (user) | Phase 2B | 2B not started |
| O-P2-4 | Fusion AR covers some ledgers from April 2026 only | Phase 3 collections | Insurer AR not reported |
| O-P2-5 | Medication category list confirmed as `MD, MED, PH, CSM, RTL, MLK` | Medication revenue | As listed |
| O-P2-6 | Closed month and old-server exports (`mv_revenue_dataset`, RCM Authorization) for acceptance | Reconciliation sign-off | — |
| O-P2-7 | How patient cash refunds are recorded (`CSH…` `CREDITAR`, `PAYMENT` documents, or both) | Refunds in `fact_cash_receipt` | Receipts only; refunds not reported |

---

## 14. Decision log

| Decision | Chosen | Rejected |
|---|---|---|
| Phase shape | 2A now, 2B after pull-response ingestion, insurer AR to Phase 3 | One phase blocked on ingestion; insurer AR from Oasis statement balances (would show ~2.7B SAR outstanding for 2026) |
| Remittance amounts | Ingest pull responses | Build claims without approved amounts; estimate from approved quantity |
| Payer on a charge | Billed payer and episode payer | Billed only; episode only |
| Packages | Header is revenue; components kept as package content | Components as revenue |
| Revenue amount | `price_paid_purchaser` (net), dated on delivery | Gross; invoice date |
| Charge intermediate | Rules in macros, fact reads staging | 105M-row `int_charge_line` |
| Pre-auth grain | Oasis authorisation line plus unmatched NPHIES items | NPHIES item only; request header |
