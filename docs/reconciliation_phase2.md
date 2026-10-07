# Phase 2A reconciliation

Run after a successful `dbt build --select tag:hnh`. Choose one closed month with finance (open item O-P2-6). Because of the known data findings below, choose an acceptance month before July 2026, and leave branch 2 out of outpatient billing checks for January to July 2026.

## Acceptance against the old server, August 2026 (2026-10-07)

Measured read-only on the old warehouse (DSN `chDWH`, 172.22.25.165) with the logic of the saved Power BI models (`powerbi_tmdl/Executive Dashboard`, `RCM Authorization`, `claims`), against the gold build of 2026-10-07.

**Revenue (O-P2-6): passes.** The Executive Dashboard's charge part of `mv_revenue_dataset_details` against `rec_revenue_monthly.legacy_charge_revenue`:

| Branch | Old charge part | New legacy charge revenue | Difference |
|---|---:|---:|---:|
| 1 Alrabwah | 28,742,558.56 | 28,742,558.56 | 0 |
| 2 Khamis | 32,407,166.42 | 32,407,166.42 | 0 |
| 3 Jazan | 40,534,386.07 | 40,534,456.74 | 70.67 (0.0002%) |
| 4 Unaizah | 21,698,444.50 | 21,698,444.50 | 0 |
| 5 Madinah | 18,858,588.05 | 18,881,486.01 | 22,897.96 (0.12%) |
| 6 Abha | 17,049,920.63 | 17,077,669.96 | 27,749.33 (0.16%) |
| 7 Ghirnata | 3,526,829.50 | 3,526,829.50 | 0 |
| 8 Muhayil | 444,511.03 | 444,511.03 | 0 |

The old discount part equals the new `adjustments` and `legacy_discount_documents` on every branch. The differences in branches 3, 5 and 6 are 199 charge lines delivered on 1–6 August that are superseded (`R`) or cancelled (`C`) on the old server but live in the new `stg_oasis__charges` copy, beside their live replacement row (example: delivery line 23834964, rows 57191087 and 57461347). This is an ingestion gap (cancel-flag updates not reaching the new Oasis copy), raised with the ingestion owner; it overstates new revenue by about 50.7K SAR in August. New `revenue` adds uninvoiced live lines (branch 6: 17,019.50) and moves 9,270.88 (branch 2) and 18,048.75 (branch 7) from IP to Day case.

**Pre-authorisation (O-P2-6, RCM Authorization): accepted on the bridge.** `legacy_approved` and `legacy_rejected` exceed the old report (+12.9% and +4.8% in August). Every old key (111,172) exists in the new fact; the extra lines are, in order of size: lines the old `vw_authorizations` drops because their only answers have `RESPONSE_TRANS_ID = REQ_API_TRANS_ID` (an old-report defect: 12,692 approved and 2,365 rejected lines), NPHIES items with no Oasis line (2,350 approved, 1,287 rejected; added by design), lines sent under another request or IOS (1,106 and 301), and lines whose last send ended in ERROR (60 and 37). The old report also counts duplicate rows from its order and delivery joins (1,553 in branch 1). The user accepted the bridge on 2026-10-07; the old defect is not reproduced. `nphies_approved_amount` now falls back to the payer benefit parsed from the pull-response JSON, because Oasis never fills `api_pre_approval_res_details.approved_amount`; approved quantities are kept as recorded (branch 4 has garbage values, e.g. 140,756,285 on authorisation 2982457, so `approved_estimated_amount` reaches 33.5bn SAR there).

**Claims (O-P2B-5): accepted after two fixes.** Source lines are identical on both servers. The old claims model and `bsc.vw_rcm` keep only claim lines whose invoice and NPHIES transaction are on an AR statement (`tr_ar_statements`); `fact_claim_line.legacy_in_scope` now reproduces that scope and `rec_claims_monthly.legacy_*` sum over it. August after the fix:

| Branch | Old submitted | New legacy submitted | Old rejected | New legacy rejected |
|---|---:|---:|---:|---:|
| 1 | 18,048,891.67 | 18,106,938.81 (+0.32%) | 2,325,584.62 | 2,325,996.78 (+0.02%) |
| 2 | 24,860,676.68 | 24,872,657.72 (+0.05%) | 2,593,824.53 | 2,593,824.53 (0) |
| 3 | 34,533,461.66 | 34,595,539.63 (+0.18%) | 8,166,374.02 | 8,167,842.01 (+0.02%) |
| 4 | 18,802,825.56 | 18,872,270.25 (+0.37%) | 1,489,113.50 | 1,489,113.50 (0) |
| 5 | 14,687,515.72 | 14,814,361.48 (+0.86%) | 1,588,456.70 | 1,590,092.90 (+0.10%) |
| 6 | 14,675,624.24 | 15,420,907.59 (+5.08%) | 1,115,163.73 | 1,115,510.71 (+0.03%) |
| 7 | 2,246,014.08 | 2,355,918.09 (+4.89%) | 481,293.02 | 481,576.09 (+0.06%) |
| 8 | 23,746.02 | 23,746.02 | 0 | 0 |

The remaining submitted difference in branches 5 to 7 is invoices put on an August statement after month end (e.g. branch 6 statements 20829 and 20868 prepared on 12 September, 21721 on 29 September, all ending 31 August): the old server's `tr_ar_statements` has no branch 6 statement rows created after 31 August, so it never picks them up. The new scope is the complete one. The second fix: the partially approved line's rejected amount no longer counts VAT (submitted includes it, eligible and benefit exclude it, the payer returns it as `tax`); August new rejected fell by about 1.0M (branch 2), 1.35M (branch 3) and 0.61M (branch 4). The other differences between new and old KPIs are documented corrections (latest NPHIES response, unadjudicated lines carry no approval, outcome-aware rejected amount, rejection rate over adjudicated lines). The old models report no remittance, so `fact_claim_payment` has no old baseline. August is not settled: claims without a response are 84% of submitted for branch 6 and about 50% for branches 1 and 5 (O-P2B-1).

**Patient refunds (O-P2-7).** Negative patient receipts are classified by `fact_cash_receipt.receipt_kind`: a Cancellation matches an earlier receipt of the same patient, episode and amount; any other negative receipt is a Refund. 2026 to 2026-10-07: receipts 212.0M, cancellations −20.0M, refunds −15.1M (REC receipts −12.7M, AR cash receipts −2.3M, cashier −0.13M).

## Revenue (`gold.rec_revenue_monthly`)

1. Export the old `mv_revenue_dataset` charge part for the month (rows with `PACKAGE_DEAL_FLAG = 'N'`, `CANCEL_FLAG = 'X'`, `DOC_ID != 0`, summed by branch).
2. Compare with `legacy_charge_revenue`. Acceptance: within 0.5% per branch.
3. Explain the gap to the new `revenue` with the corrections in spec section 9: the old discount part (compare `legacy_discount_documents` with the old discount rows), package components, care-type mapping.

## Billing (`gold.rec_billing_monthly`, `gold.agg_episode_billing`)

1. Outpatient `claimable_charges` and `invoiced_net` should agree for closed months; `warn_op_billing_mismatch` lists exceptions.
2. `long_stay_overbilled` is the long-stay contract gap (open item O-P2-2). Take the largest episodes to finance.

## Pre-authorisation (`gold.rec_preauth_monthly`)

1. Refresh the RCM Authorization report for the same month.
2. Compare its Approved Services and Rejected Services with `legacy_approved` and `legacy_rejected`. Acceptance: within 0.5%. Lost Revenue (`legacy_lost_revenue`) is not expected to match, because the new model counts a delivery only on or after the request.
3. The new `approved`, `rejected` and `lost_revenue` differ by design (final response, sent-line denominator, latest request per service). The approval and rejection rates are `approved_final` and `rejected_final` over `final_responses`.

## Claims (`gold.rec_claims_monthly`)

1. Export the claims model's Submitted Claims Amount, Approved Amount and Rejections for a closed month, and the same month from `bsc.vw_rcm`.
2. Compare with `legacy_submitted`, `legacy_approved`, `legacy_rejected`. Acceptance: within 0.5% per branch.
3. Explain the gap to `submitted`, `approved`, `rejected` with the corrections in the Phase 2B spec, section 8.
4. Check `warn_claims_without_response` first: months with many unanswered claims are not comparable until the pull-response load is complete (open item O-P2B-1).

## Monitors at first build (2026-10-04)

Full build of `tag:hnh` after the final-review fixes: PASS=424 WARN=13 ERROR=0, 8 min 32 s. Rows is the number of rows the monitor returned (its grouping is in the Note column).

The six claims monitors come from the Phase 2B full build of `tag:hnh` after the final-review fixes on 2026-10-05: PASS=476 WARN=20 ERROR=0, 10 min 14 s (`int_nphies_adjudication` 199 s, `int_claim_payment` 131 s). That build's other new warning is the warn-severity relationship test `fact_claim_line.invoice_key` to `fact_invoice` (1,182,965 lines): claim invoice numbers are partly a different number space from the AR invoices, so it is not the invoice window.

| Monitor | Rows | Note |
|---|---|---|
| warn_unmapped_product_category | 4 | Branches with unmapped category codes on live charges; negligible revenue |
| warn_invoice_without_payer | 4 | Branches with invoices whose account has no payer |
| warn_invoice_account_many_purchasers | 3 | Accounts with more than one purchaser; the lowest policy code decides the payer |
| warn_unmapped_invoice_approval_status | 0 | |
| warn_preauth_outcome_unknown | 0 | |
| warn_op_billing_mismatch | 160 | Branch and invoice-month groups: 2 to 10 episodes a month from January to June 2026, then the July to September 2026 surge (finding 1) |
| warn_excluded_receipt_accounts | 84 | Branch and account-prefix groups of payer and contract receipts left out of `fact_cash_receipt` (23,096 documents, 4.84 billion SAR; finding 6) |
| warn_unresolved_charge_encounter | 5 | Branch and care-type groups above 2% unresolved over the last 90 days: branches 7 and 8 (finding 2); branch 2 is about 1.5% since August |
| warn_claims_without_response | 310 | Branch and statement-month groups of sent, non-cancelled latest-submission claim lines with no NPHIES answer (current month excluded; branch 7 claim responses start 2026-04-07 and branch 8's stop at 2026-05-07, O-P2B-2 and O-P2B-9) |
| warn_unknown_nphies_reason | 317 | Branch and reason-code groups of claim lines whose reason code is not in `dim_nphies_reason`; mostly legacy `N-DC-0xx` codes (O-P2B-8) |
| warn_unmatched_claim_response_items | 5 | Branches with claim-response items that match no claim line of the visit that sent the transaction |
| warn_unmatched_claim_payments | 2 | Branches with remittance lines (advances excluded) whose transaction matches no claim visit |
| warn_duplicate_claim_payments | 5 | Branches with the same remittance detail (claim transaction, payer claim response, payment reference, payment date and amount) in more than one kept reconciliation: revised re-issues of a payment (O-P2B-12) |
| warn_advance_authorisations | 200 | Branch and month groups of payer-initiated advance authorisations, counted from the staged pull responses (not parsed; O-P2B-3) |

The build's other warnings come from Phase 1 monitors and `warn_unexpected_charge_cancel_flag` (3 groups, the 14 `I`/`F` rows of finding 4).

## Data findings at first build (2026-10-04)

1. **Outpatient episodes invoiced on more than one statement from July 2026.** Outpatient episodes whose invoiced amount differs from the claimable amount were 2 to 10 a month from January to June 2026, then 1,115 (July), 12,684 (August) and 25,497 (September). Almost all are invoiced above charges by an exact factor of 2 to 5. Example: a branch 3 episode appears on statements 173312 (26 August, statement never approved) and 173605 (3 September); both statements exist in Oasis. Billed amounts for those months are overstated until finance confirms whether re-issued statements should replace earlier ones, or whether Oasis deletions are not reaching the warehouse.
2. **Branch 2 outpatient encounters.** `int_encounter` has almost no outpatient encounters for branch 2 in January to July 2026, so 42 to 100% of those months' outpatient charges cannot link to a visit; from August it is about 1.5%. Branches 7 and 8 show a similar 23 to 26% over the last 90 days. This points to appointments missing from the Oasis ingestion.
3. **Product categories.** 254 of 899 category codes are not in `map_product_category`. Only 4 branches have unmapped codes on live charges, with negligible revenue (`warn_unmapped_product_category`).
4. **Unexpected cancel flags.** 14 charge rows carry cancel flags `I` or `F` (about 125 SAR). They are kept with status Unknown and zero revenue.
5. **Test data in cancelled charges.** About 10 cancelled charge rows have units of 4,444,444,444 and net amounts up to 310 billion SAR (test data in Oasis). `rec_revenue_monthly.cancelled_charges` is meaningless for their months.
6. **Patient collections.** `fact_cash_receipt` holds patient receipts only (patient receipts: account CASHACC, none, or the patient's own account), net of reversals (`is_reversal = 1`, 5.5% of its documents); about 985 million SAR since 2022. Insurer and contract receipts (DIR-, INS, GOV, MOHSP and other accounts) are excluded (Phase 3, Fusion AR) and listed by `warn_excluded_receipt_accounts`.
7. **Post-invoice discounts without a charge line.** 17% of post-invoice discount documents have no live charge line on their base invoice (episode, patient and payer unknown in fact_revenue_adjustment).
8. **Pre-authorisation counting.** Lost Revenue uses the latest request per service; the unutilised and delivered-without-approval counts include every request.
9. **Last-status naming.** Spec 7.6 calls the old report's last status `legacy_last_service_status`; in the fact it is `nphies_last_status`.
10. **Discounts on superseded invoices.** Post-invoice discounts whose base invoice has only superseded lines (about 9,900 documents, 554K SAR) have unknown episode, patient and payer.
11. **Branch 8 claim visits duplicate branch 7's (Phase 2B, 2026-10-05).** 811 branch 8 claim visits with statement dates in February (86) and March (725) 2026 carry the same `visit_id` and `api_trans_id` as branch 7 visits, so they are counted in both branches (open item O-P2B-11). Branch 8's later visits (July to September 2026) do not overlap.
