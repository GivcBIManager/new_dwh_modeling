# Claim status and claim line amounts: reconciliation

Spec: `docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md`. The expected values were computed
read-only on gold on 2026-10-14, before the build. Each model was rendered with its real macros and run against the
live tables, with `int_invoice_claim_status` inlined (plan tasks 1 and 3). The built values are from the build of
2026-10-15 12:27.

## Billed statements by channel, invoices dated 2026-01-01 to 2026-08-31

| Channel | Invoices (expected) | SAR (expected) | Invoices (built) | SAR (built) |
|---|---|---|---|---|
| NPHIES | 529,661 | 871,936,810 | 529,661 | 871,936,810 |
| Manual | 17,040 | 108,095,559 | 17,040 | 108,095,559 |
| Not submitted | 101,630 | 451,907,366 | 101,630 | 451,907,366 |
| Unknown | 0 | 0 | 0 | 0 |

## Claim lines, statement end 2026-01-01 to 2026-08-31, latest not cancelled

| Amount | Expected (SAR) | Built (SAR) |
|---|---|---|
| Approved | 774,937,478 | 775,004,410 |
| of which approved lines (net) | 547,552,688 | 547,615,230 |
| Rejected | 130,378,485 | 130,420,707 |
| Lines not adding up (singular test, all statuses) | 0 | 0 (all history, 2026-10-15) |

180,407 of the 3,459,062 claim lines in the window have a claim invoice number that is not in AR, so their claim
status is Unknown (the same count after the build). Every built invoice key is in `dim_claim_status`.

The built approved and rejected amounts are SAR 66,932 and 42,222 above the expected ones, with the same line count:
the gold data was refreshed between the two checks (NPHIES responses that arrived overnight). An independent query
that applies the rules directly to `stg_oasis__claim_services`, `int_claim_submission` and
`int_nphies_adjudication` (claim responses), without the model, gives exactly the built totals: approved 775,004,410,
rejected 130,420,707.

## bsc.vw_rcm shift

Filled from `compare_bsc.ps1` after the build.
