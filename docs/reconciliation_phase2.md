# Phase 2A reconciliation

Run after a successful `dbt build --select tag:hnh`. Choose one closed month with finance (open item O-P2-6). Because of the known data findings below, choose an acceptance month before July 2026, and leave branch 2 out of outpatient billing checks for January to July 2026.

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

## Monitors at first build (2026-10-04)

Full build of `tag:hnh` after the final-review fixes: PASS=424 WARN=13 ERROR=0, 8 min 32 s. Rows is the number of rows the monitor returned (its grouping is in the Note column).

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
