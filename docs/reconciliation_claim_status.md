# Claim status and claim line amounts: reconciliation

Spec: `docs/superpowers/specs/2026-10-14-hnh-claim-status-and-line-amounts-design.md`. The expected values were computed
read-only on gold on 2026-10-14, before the build. Each model was rendered with its real macros and run against the
live tables, with `int_invoice_claim_status` inlined (plan tasks 1 and 3). The built values are filled in after the
build.

## Billed statements by channel, invoices dated 2026-01-01 to 2026-08-31

| Channel | Invoices (expected) | SAR (expected) | Invoices (built) | SAR (built) |
|---|---|---|---|---|
| NPHIES | 529,661 | 871,936,810 | | |
| Manual | 17,040 | 108,095,559 | | |
| Not submitted | 101,630 | 451,907,366 | | |
| Unknown | 0 | 0 | | |

## Claim lines, statement end 2026-01-01 to 2026-08-31, latest not cancelled

| Amount | Expected (SAR) | Built (SAR) |
|---|---|---|
| Approved | 774,937,478 | |
| of which approved lines (net) | 547,552,688 | |
| Rejected | 130,378,485 | |
| Lines not adding up (singular test, all statuses) | 0 | |

180,407 of the 3,459,062 claim lines in the window have a claim invoice number that is not in AR, so their claim
status is Unknown.

## bsc.vw_rcm shift

Filled from `compare_bsc.ps1` after the build.
