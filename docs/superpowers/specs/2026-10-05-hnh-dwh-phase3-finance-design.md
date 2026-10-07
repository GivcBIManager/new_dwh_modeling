# HNH Data Warehouse — Phase 3 Finance: General Ledger, Budget and Payables

- **Date:** 2026-10-05
- **Status:** Draft for review
- **Parent spec:** `2026-10-01-hnh-dwh-gold-layer-design.md` (architecture, keys, conventions, security, portability). Everything there applies unless this document says otherwise. Section 13 of the parent outlined this phase.
- **Inputs from the user (2026-10-05):** `abha_fs_mapping_oracle.xlsx` (sheets `abha`, `ghirnata`: financial-statement position per Oracle natural account) and `static_mappings/fs_mapping.csv` (the old warehouse's Oasis chart mapping behind `vw_account_tree`).

---

## 1. Purpose and decisions

Build the financial statements from Oracle Fusion: trial balance, balance sheet and income statement per branch and for the group, the income statement against budget, and supplier payables. Replaces the *Financial Statements updated* Power BI model and the budget part of `bsc.vw_financial`.

Decisions made in review (2026-10-05):

| # | Decision |
|---|---|
| F1 | **Fusion only.** Statements start at each branch's Fusion go-live. The legacy Oasis GL is not ingested; prior-year comparisons become available from 2027. |
| F2 | **Scope:** GL statements, budget against actual, payables. Insurer AR ageing is deferred: Fusion AR holds no insurer invoices (finding G9), so it would have to be built from Oasis statements less NPHIES remittance in a later phase. |
| F3 | **One group-wide FS mapping.** The Abha and Ghirnata sheets are merged; the natural account (segment 2) carries one FS position in every branch. Unmapped accounts of the same kind in other branches take the line of their mapped siblings (section 4.1). |
| F4 | **Posted and unposted journals are both kept, flagged.** Statements default to posted (ties to the Fusion trial balance); a second measure set includes unposted lines. |
| F5 | **Budget revenue by care type from the GL service location** (segment 4). Revenue without a location is Unallocated. |
| F6 | **Head Office is its own branch** (`branch_key` 100). Group = plain sum of all nine ledgers; no intercompany elimination. The intercompany segment is kept and monitored. |
| F7 | **Architecture A:** a journal-line fact plus a monthly balance fact derived from it in dbt (not Fusion's balance table, not cumulative DAX). |

---

## 2. Findings that shape the design

Measured 2026-10-05 on `fusion` (ClickHouse 172.22.25.214).

| # | Fact | Consequence |
|---|---|---|
| G1 | All nine ledgers (Head Office and eight hospitals) use chart of accounts 2001. Segments: 1 entity (branch), 2 natural account, 3 specialty (324 values), 4 service location (OPD, IPD, LTC, OPD-PH, IPD-PH, ER, HHC, Telemedicine, Endoscopy, Cath, Kidney Dialysis, Academy on-site/online), 5 service group (Consultation, Lab, Medication, Radiology, Procedures, OR/Admission), 6 intercompany, 7–8 future. `dim_gl_account` has 9,500 code combinations. | One FS mapping on segment 2 serves the group; specialty and service location give department and care type. |
| G2 | Fusion GL starts in 2026 and per branch: Ghirnata January, Abha February, Head Office April, Jazan and Muhayil June, Unaizah July, Khamis late August, Madinah September. **Alrabwah (102) has no journal lines.** Periods are defined from Jan-24. | Statements begin at go-live (F1). Alrabwah shows nothing until it posts. |
| G3 | Each branch's go-live month has a large Spreadsheet journal, category *MRC Open Balances*, carrying the year-to-date and balance-sheet position from before go-live (e.g. revenue: Abha April 103M, Jazan June 247M, Unaizah July 234M, Khamis August 326M SAR). | Flag it; monthly trends can exclude it, year-to-date includes it. |
| G4 | `fact_gl_journal_line` read with `final` (the table holds unmerged versions: 10.29M rows, 9.72M distinct lines): 9,722,782 actual lines, header status P (posted) 1,766,863 and U (unposted) 7,955,919; no other statuses after `final`. The integration source `300000007046804` (the Oasis feed) supplies almost all lines; most of its batches since May are unposted (Ghirnata revenue unposted since May, Abha since June, Jazan, Unaizah, Muhayil throughout). Khamis' and Jazan's opening-balance batches are unposted. | F4. A posted-only view would show Khamis empty and most recent revenue missing. |
| G5 | Posted journal debits equal `fusion.fact_gl_balance` period debits per ledger and period to the riyal (Ghirnata, every period including `Adj-Q2-26`). `fact_gl_balance` has no rows for Khamis and Alrabwah. | Balances can be derived from journals and reconciled to Fusion's table. |
| G6 | Periods: monthly, plus quarterly adjustment periods (`Adj-Qn-yy`, start = end = quarter end, `adjustment_period_flag = 'Y'`), and one stray yearly period `2026` (`period_year` 1). | `dim_gl_period` keeps monthly and adjustment periods; drops the yearly one. |
| G7 | FS mapping: Abha 205 accounts, Ghirnata 111; 77 shared, all identical; 34 Ghirnata-only. Merged 239. After sibling inference (section 4.1) 336 accounts. Share of journal value (debits + credits) on mapped accounts: Ghirnata 100%, Madinah 100%, Muhayil 100%, Abha 97.8%, Khamis 97.5%, Unaizah 97.3%, Jazan 97.0%, Head Office 62.2%. 69 posted accounts remain unmapped, 54 of them Head Office only (loans, investments, equity, CWIP). | Unmapped accounts are kept on a "Not mapped" line and monitored. |
| G8 | The Oasis `fs_mapping` (19,400 rows, 8 branches) uses the same five FS levels, keyed by branch and Oasis sub-account (`MAIN_ACC‖SUB_ACC`); 18,931 of its keys exist in `oasis.gl_code`. Oasis and Oracle numbers are different spaces (9 coincidental overlaps, 8 on different lines). Vocabulary differs: Oasis splits revenue by care setting and has *Medical Consumables*, *Cost of Goods Sold*; Oracle splits revenue by payer and has *Cost of Medicines*. One conflicting duplicate: branch 5 code `1`. | Loaded as `default.map_oasis_fs_account` for the go-live reconciliation (section 9.3), not as a lookup for Oracle accounts. |
| G9 | Fusion AR: 1,209 invoice lines and 211 receipts (April–September 2026, 5 business units). Insurer receivables exist only as GL balances (e.g. *Claimed A/R – Insurance Companies* 768M SAR from 120 opening lines). | F2: no insurer AR ageing from Fusion. |
| G10 | Fusion AP (with `final`): 5,899 invoices (5,545 standard, 63 credit, 291 prepayment), 1,269 suppliers, 37,421 distributions from March 2026; 1,293 payments; 5,930 payment-schedule rows, one per invoice (the table is keyed by `invoice_id` only), with 199M SAR remaining. Line types ITEM, ACCRUAL, IPV, TRV, PREPAY, REC_TAX, NONREC_TAX; cancelled invoices carry reversing distributions. | AP facts in section 7. Open payables exist only as a current snapshot. |
| G11 | Revenue lines (natural accounts 411…) carry a service location on 5.03M of 5.03M integration lines; SAR 553M of revenue on 13K lines (opening and manual journals) has location `00`. | F5 with an Unallocated bucket. |
| G12 | `default.income_statement_budget`: 576 rows, branches 1–6, FY2026, scenarios `most_likely` and `worst_case`, 48 line codes, months 1–12. Subtotals are consistent: REV_SUB = OP+IP+ER; DIS_REJECTION = INS+MOH; DIS_SETTLEMENT = REJECTION+EARLY_PAY+VOLUME; REV_NET = REV_SUB − DIS_SETTLEMENT; TOTAL_DC = Σ DC_*; TOTAL_GA = Σ GA_*; GROSS_PROFIT = REV_NET − TOTAL_DC; EBITDA = GROSS_PROFIT − TOTAL_GA + OTHER_INCOME; NET_PROFIT = EBITDA − DEPRECIATION − FINANCE_COST − ZAKAT; TOTAL_COMP_INCOME = NET_PROFIT + OCI. | Subtotals are recomputed, never summed (section 6.3). |
| G13 | The old *Financial Statements* model reads the legacy Oasis GL (`tr_gl_distribution`, `master_gl_codes`, `fs_mapping`) on the old server, which is not in this ClickHouse. Its opening balance double counts when two years are open and is zero for closed periods; lines sort alphabetically; no budget, EBITDA or sign handling. `bsc.vw_financial` excludes other income from EBITDA and never matches ROU depreciation (`'depreciation On Rou'` against lower-cased captions). | Section 8 lists the corrections. |

---

## 3. Architecture

Same layers, tags and folders as earlier phases.

```
models/hnh/staging/fusion/       _fusion__sources.yml, _fusion__models.yml, stg_fusion__*
models/hnh/staging/reference/    + stg_ref__fs_account, stg_ref__oasis_fs_account, stg_ref__fs_line_order,
                                   stg_ref__budget_fs_line, stg_ref__fusion_specialty_unified,
                                   stg_ref__income_statement_budget
models/hnh/intermediate/finance/ int_gl_journal_line, int_gl_balance_monthly
models/hnh/marts/conformed/      hnh_dim_branch (Head Office member), hnh_dim_gl_period, hnh_dim_gl_account,
                                 dim_fs_line, dim_budget_line, hnh_dim_supplier
models/hnh/marts/finance/        hnh_fact_gl_journal_line, fact_gl_balance_monthly, fact_income_statement_monthly,
                                 fact_budget_monthly, fact_ap_invoice_line, hnh_fact_ap_payment, fact_ap_open_item
models/hnh/marts/reconciliation/ rec_gl_balance_monthly, rec_gl_revenue_monthly, rec_income_statement_budget
macros/hnh/hnh_rules_finance.sql
```

All models are full rebuilds (the journal fact is about 9.7M rows). Five model names exist in the receiving project's own Fusion models (`dim_gl_period`, `dim_gl_account`, `dim_supplier`, `fact_gl_journal_line`, `fact_ap_payment`), so those models carry the `hnh_` prefix and an `alias` to the gold table name, as `hnh_dim_branch` does. In the receiving project the `fusion` database is itself built by dbt, so Fusion tables are read through `hnh_fusion_source()`, which switches between `source()` and `ref()` like `hnh_oasis_source()`. The parent spec's portability rule ("sources only in the `_sources.yml` files") now covers three source files: Oasis, reference and Fusion.

---

## 4. Reference data

Loaded once into `default` by `scripts/load_reference_data.py`; not seeds, not in git.

### 4.1 Loaded on 2026-10-05

| Table | Rows | Content |
|---|---|---|
| `default.map_fs_account` | 336 | `ORACLE_CODE` (natural account) → `FS_TYPE`, `FS_ELEMENT`, `FS_CATEGORY`, `FS_CAPTION`, `FS_LINE`, `MAPPED_IN` (`abha` 128, `ghirnata` 34, `abha,ghirnata` 77, `inferred` 97). Source CSV `static_mappings/fs_account_mapping.csv`. |
| `default.map_oasis_fs_account` | 19,400 | The Oasis `fs_mapping`: `BRANCH_ID`, `CODE`, `TYPE`, five FS levels. Source `static_mappings/fs_mapping.csv`. |

**Inference rule (`MAPPED_IN = 'inferred'`).** An account with postings and no supplied line takes the FS position of its 6-digit parent group (first six digits of the natural account) when at least two supplied accounts in that group exist and all of them share one FS position. 97 accounts qualified: 49 bank and clearing accounts, 39 petty-cash accounts, 3 trade receivables, 2 VAT/withholding, 1 each cash, rental, sub-store inventory, depreciation. Groups with one supplied sibling or mixed lines were not inferred. The worklist of the 69 remaining posted accounts, with a suggestion where one exists, is `static_mappings/fs_account_unmapped.csv` (for the BI manager and finance).

### 4.2 To be drafted in this phase (reviewed by the user, then loaded)

| Table | Content |
|---|---|
| `default.map_fs_line_order` | One row per FS level value: `level` (type, element, category, caption, line), `value`, `sort_order`, and for categories the `statement_group` used for subtotals (Revenue, Revenue discounts, Direct cost, G&A, Selling and marketing, Other income, Depreciation and amortisation, Finance cost, Zakat, Charges from head office, OCI). Drafted in standard statement order. |
| `default.map_budget_fs_line` | Budget detail code → FS position. Columns `line_item_code`, `match_level` (`account`, `line`, `caption` or `category`), `match_value`, `care_type` (revenue codes only). The most specific match wins (account over line over caption over category). Drafted from G12 and the old `bsc.vw_financial` pairings, with its defects fixed. |
| `default.map_fusion_specialty_unified` | GL specialty segment value → unified department (`map_unified_department_v2` vocabulary). Drafted by name matching for the BI manager to review; the proposal promised in parent spec section 13. |

---

## 5. Conformed dimensions

### 5.1 dim_branch (extended)
Adds a Head Office member: `branch_key` 100, name *Head Office*, city Riyadh, Fusion branch code 101, Fusion ledger 300000005003375, no beds, clinics or Press Ganey code. Built inside the model, like the Group row (`0`); the crosswalk table is unchanged. Group continues to mean all members. `sec_user_access` gives admins a row for branch 100; non-admin users see Head Office only if granted it (fail closed).

### 5.2 dim_gl_period
One row per Fusion period of type month, plus adjustment periods; the yearly `2026` period is excluded. Key `period_key` = `period_year × 100 + period_num` (e.g. 202608 = Adj-Q2-26). Attributes: period name, start and end date, `month_date_key` (end date), fiscal year, quarter, calendar month, `is_adjustment`, `period_seq` (running order: an adjustment period follows its quarter's last month).

### 5.3 dim_gl_account
One row per code combination, plus Unknown (`-1`).
- Segment codes and descriptions: `branch_segment`, `natural_account`, `natural_account_name`, `specialty_code`/`name`, `service_location_code`/`name`, `service_group_code`/`name`, `intercompany_segment`; `intercompany_branch_key` (from segment 6, `-1` for 000).
- `account_type` (A, L, O, R, E) and its label.
- `fs_line_key` → `dim_fs_line`; `fs_mapping_source` (`supplied`, `inferred`, `not mapped`).
- `revenue_care_type` from the service location by `hnh_gl_care_type`: OPD, OPD-PH, HHC, Telemedicine → OP; IPD, IPD-PH, LTC → IP; ER → ER; Endoscopy, Cath, Kidney Dialysis → OP (proposed, O-P3-6); Academy on-site and online → Other; 00 and 99 → Unallocated. A plain attribute, not a key to `dim_care_type`, because the GL location is not the Oasis eligibility care type.
- `unified_department` from `map_fusion_specialty_unified` (Unknown until mapped).

### 5.4 dim_fs_line
One row per distinct FS position in `map_fs_account`, plus one *Not mapped* line per account type (Assets, Liabilities, Equity, Revenue, Expenses). Columns: the five levels with labels trimmed and capitalised consistently (also fixing the source spelling *Deprecition*), `sort_order` per level from `map_fs_line_order`, `statement_group`, and `display_sign`: −1 for Revenue, Other income, Liabilities and Equity; +1 otherwise. Unmapped accounts land on the Not mapped line of their account type, so balance sheet and income statement totals still balance.

### 5.5 dim_budget_line
One row per budget code (48) plus two synthetic detail codes: code, name, statement group, `sort_order`, `is_subtotal`, `natural_side` (`credit` for REV_*, REV_UNALLOCATED and OTHER_INCOME; `debit` for DIS_*, DC_*, GA_*, DEPRECIATION, FINANCE_COST, ZAKAT; OCI as delivered), `subtotal_formula` (documentation). Subtotal codes: REV_SUB, DIS_REJECTION, DIS_SETTLEMENT, REV_NET, TOTAL_DC, TOTAL_GA, GROSS_PROFIT, EBITDA, NET_PROFIT, TOTAL_COMP_INCOME. Synthetic codes: `REV_UNALLOCATED` (revenue whose care type is Unallocated or Other; rolls into REV_SUB) and `UNBUDGETED` (income-statement FS lines that no budget code matches; see 6.3).

### 5.6 dim_supplier
One row per Fusion supplier site (`vendor_site_id`), plus Unknown: supplier number, name, type, status, country, business unit.

---

## 6. Facts

### 6.1 fact_gl_journal_line
**Grain:** one Fusion actual journal line (`actual_flag = 'A'`), key (`je_header_id`, `je_line_num`). About 9.7M rows.

**Keys:** `gl_journal_line_key`; `branch_key` (from the account's segment 1; 101 → 100); `gl_account_key`; `period_key`; `accounting_date_key`; `posted_date_key` (`-1` when unposted); `intercompany_branch_key`.

**Attributes:** `ledger_id`, `je_batch_id`, `journal_name`, `doc_sequence_value`, `je_source` and `je_source_label` (the integration id decoded as *Oasis feed*; other sources as delivered), `je_category`, `line_description`, `header_status`.

**Flags:** `is_posted` (header status P); `is_opening_balance_journal` (category *MRC Open Balances*); `is_oasis_feed`.

**Measures:** `debit`, `credit` (accounted SAR, nulls as 0), `amount` = debit − credit.

### 6.2 fact_gl_balance_monthly
**Grain:** code combination × period × `balance_view` (`posted`, `including_unposted`). Densified from the account's first period with a posting in that view to the current period, so a closing balance exists in every period.

**Keys:** `branch_key`, `gl_account_key`, `period_key`.

**Measures:** `opening_balance`, `period_debit`, `period_credit`, `period_movement`, `closing_balance`; `period_movement_excl_opening` (movement without opening-balance journals).

**Rules:**
- Running order is `period_seq`.
- Balance-sheet accounts (`FS_TYPE` BS, or account type A, L, O when not mapped) accumulate from their first period.
- Income-statement accounts reset at the start of each fiscal year. At a year start, the previous year's income-statement closing total of the ledger is added to the opening balance of retained earnings (natural account 36101101) in that ledger, so the balance sheet balances across years. Applies from 2027.

### 6.3 fact_income_statement_monthly
**Grain:** branch × month × budget code × `revenue_care_type` × `statement_group`. Revenue is split by care type: OP → REV_OP, IP → REV_IP, ER → REV_ER, Unallocated and Other → REV_UNALLOCATED. Every other code carries care type `All`. `statement_group` is the group of the FS line (it matters only for `UNBUDGETED`). Month = calendar month of the period; adjustment periods fold into their quarter's last month.

**Measures:** `actual_posted`, `actual_including_unposted`, `actual_excl_opening` (including unposted, without opening-balance journals), `budget_most_likely`, `budget_worst_case`. Actuals are income-statement movements assigned to budget codes through `map_budget_fs_line` and expressed on the code's `natural_side` (credit codes: credit − debit; debit codes: debit − credit), so every detail value is normally positive, as in the budget file. Budget comes from the latest published version (`is_latest = 1`).

**Subtotals** are computed in the model from detail codes, for actuals and budget alike, with the G12 formulas; REV_UNALLOCATED counts in REV_SUB. Budget-file subtotal rows are not used for values; `rec_income_statement_budget` checks them against ours. `UNBUDGETED` rows join the subtotal of their statement group, signed by that group's side: Revenue → REV_SUB (credit); Revenue discounts → DIS_SETTLEMENT (debit); Direct cost → TOTAL_DC; G&A, Selling and marketing, Charges from head office → TOTAL_GA; Other income → EBITDA (credit, beside OTHER_INCOME); Depreciation and amortisation, Finance cost, Zakat → NET_PROFIT (debit); OCI → TOTAL_COMP_INCOME. The model's net profit therefore equals the statement's.

Branches 1–6 have budgets; Ghirnata (7), Muhayil (8) and Head Office (100) have actuals only.

### 6.4 fact_budget_monthly
**Grain:** branch × budget code × month × scenario (detail and subtotal rows as delivered, `is_subtotal` from `dim_budget_line`). Latest published version. For budget-only views (phasing, full year).

---

## 7. Payables facts

### 7.1 fact_ap_invoice_line
**Grain:** one AP invoice distribution (`invoice_distribution_id`), 38K rows.

**Keys:** `branch_key` (distribution account segment 1), `supplier_key`, `gl_account_key`, `invoice_date_key`, `accounting_date_key`, `period_key`.

**Attributes:** `invoice_id`, `invoice_num`, `invoice_type` (Standard, Credit memo, Prepayment), `line_type`, `is_posted`, `is_cancelled`, `is_reversal`, `is_po_matched`.

**Measures:** `amount` (accounted); `spend_amount` (line types ITEM, ACCRUAL, IPV, TRV, ERV, FREIGHT, MISCELLANEOUS); `tax_amount` (REC_TAX, NONREC_TAX); `prepayment_amount` (PREPAY). Cancelled invoices keep original and reversing distributions; they net to zero.

### 7.2 fact_ap_payment
**Grain:** one invoice payment (`invoice_payment_id`), 1,293 rows.

**Keys:** `branch_key` (ledger), `supplier_key`, `payment_date_key` (accounting date), `bank_account_id`.

**Attributes:** `payment_num`, `check_number`, `payment_method`, `payment_status`, `is_voided`, `is_posted`.

**Measures:** `amount`; `days_invoice_to_payment`; `days_after_due` (payment date − due date of the paid instalment; negative = early).

### 7.3 fact_ap_open_item
**Grain:** one invoice (`invoice_id`; the source keeps one schedule row per invoice, `payment_num` is an attribute), 5,930 rows. **As-of-build snapshot** (Fusion keeps only the current remaining amount).

**Keys:** `branch_key` (business unit → ledger), `supplier_key`, `invoice_date_key`, `due_date_key`.

**Attributes:** `invoice_num`, `invoice_type`, `approval_status`, `payment_status`, `is_on_hold`, `is_cancelled`, `ageing_bucket` (Not due, 1–30, 31–60, 61–90, 91–180, over 180 days past due, measured at the build date), `snapshot_date`.

**Measures:** `gross_amount`, `amount_remaining`, `days_overdue`.

---

## 8. KPI definitions (for SSAS)

| KPI | Definition | Fact |
|---|---|---|
| Account balance | Σ `closing_balance` × `display_sign`, view `posted` by default | `fact_gl_balance_monthly` |
| Movement | Σ `period_movement` × `display_sign` | `fact_gl_balance_monthly` |
| Movement, trend | Σ `period_movement_excl_opening` × `display_sign` | `fact_gl_balance_monthly` |
| Including unposted | the same measures with `balance_view = including_unposted` | `fact_gl_balance_monthly` |
| Balance last year, change, change % | balance at the same period of the prior fiscal year; change % = change ÷ abs(last year), blank when last year is blank | `fact_gl_balance_monthly` |
| Revenue, cost lines, subtotals | Σ actual by budget code; subtotals from the model | `fact_income_statement_monthly` |
| EBITDA, gross profit, net profit | the subtotal codes of `fact_income_statement_monthly` (G12 formulas) | `fact_income_statement_monthly` |
| EBITDA margin | EBITDA ÷ REV_NET | `fact_income_statement_monthly` |
| Budget variance, variance % | actual − budget; ÷ abs(budget) | `fact_income_statement_monthly` |
| Supplier spend | Σ `spend_amount` | `fact_ap_invoice_line` |
| Open payables, overdue | Σ `amount_remaining`; where `days_overdue > 0` | `fact_ap_open_item` |
| Days to pay | median `days_invoice_to_payment` | `fact_ap_payment` |
| On-time payment rate | payments with `days_after_due ≤ 0` ÷ payments, voided excluded | `fact_ap_payment` |

### Corrections relative to the old logic

| Old behaviour | New rule |
|---|---|
| Opening balance = brought-forward postings up to the end date plus open-period movements before the start: double counts with two open years, zero for closed periods (G13) | Opening and closing balances are stored per period in `fact_gl_balance_monthly` |
| Debit and credit split from amounts already netted per account and month | Real debit and credit from journal lines |
| Revenue and credit balances shown negative; change % 100% when last year is blank and wrong-signed for credit lines | `display_sign`; change % divides by the absolute prior value and is blank without one |
| FS lines sort alphabetically | `map_fs_line_order` |
| EBITDA excludes other income; ROU depreciation stays in opex because the filter never matches; consumables compared against medicines plus consumables | One subtotal rule set for actual and budget (G12); depreciation by statement group, not by name |
| Budget months without actuals dropped (`ANY LEFT JOIN`) | Budget and actual on one grain; either may be zero |

---

## 9. Testing and reconciliation

### 9.1 Tests that fail the build
- Unique and not-null on every grain key; relationships from every fact key to its dimension.
- Conservation: `fact_gl_journal_line` rows and Σ debit, Σ credit equal staged actual lines per ledger and period.
- Trial balance: per ledger and period, Σ `closing_balance` over all accounts = 0 for `balance_view = posted` (tolerance 0.01 SAR).
- Every `fact_income_statement_monthly` subtotal equals its formula over detail codes.
- Macro tests with literal inputs: `hnh_gl_care_type`, `hnh_fs_display_sign`, `hnh_gl_balance_side`, budget subtotal rules.
- Unit tests: balance densification over a period with no movement; adjustment-period ordering; income-statement reset at a year start with the retained-earnings roll; an unposted line counted only in `including_unposted`; a cancelled AP invoice netting to zero.

### 9.2 Reconciliation models
- `rec_gl_balance_monthly` (ledger × period): posted debits, credits and net from journals beside `fusion.fact_gl_balance` (`actual_flag = 'A'`, `currency_balance_type = 'TOTAL'`); difference columns. Acceptance: 0 for every ledger and period Fusion has.
- `rec_gl_revenue_monthly` (branch × month × care type): GL revenue (FS element Revenue, including unposted, excluding opening-balance journals) beside Oasis recognised revenue from `fact_charge_line`; difference and ratio. Answers whether all Oasis revenue reaches the GL.
- `rec_income_statement_budget` (branch × budget code × scenario): computed budget subtotals beside the file's subtotal rows. Acceptance: equal to 0.01 SAR (measured equal for branch 1).

### 9.3 Go-live tie to the old report
The old report cannot be reproduced from this server (G13), so no `legacy_*` fields are added. Instead, `docs/reconciliation_phase3.md` describes the go-live tie: for each branch, the opening-balance journal by FS line (Oracle vocabulary) should equal the old Financial Statements closing balance for the month before go-live by FS line (Oasis vocabulary, through `map_oasis_fs_account`), exported from the old server. Lines that differ only by vocabulary (revenue by care setting versus by payer, consumables versus medicines) are compared at category level.

### 9.4 Warning monitors
| Monitor | Rows |
|---|---|
| `warn_unmapped_fs_accounts` | posted accounts on a Not mapped line, by branch, with value |
| `warn_unposted_gl_batches` | unposted batches by branch and period, with lines and value |
| `warn_unbalanced_journals` | journal headers whose debits ≠ credits |
| `warn_intercompany_mismatch` | branch pairs whose due-from and due-to balances differ |
| `warn_revenue_without_location` | revenue lines with service location 00, by branch and month (opening journals excluded) |
| `warn_gl_revenue_gap` | branch-months where GL revenue differs from Oasis recognised revenue by more than 2% |
| `warn_ap_without_supplier` | AP distributions or payments whose supplier site is not in `dim_supplier` |

---

## 10. SSAS handoff additions
- Statement measures multiply by `dim_fs_line.display_sign`; the default `balance_view` is `posted`, with an *including unposted* measure set beside it.
- Monthly trend visuals use the `_excl_opening` measures; year-to-date and balances use the full ones.
- EBITDA, gross profit and net profit come from `fact_income_statement_monthly` only; no DAX re-derivation.
- `fact_ap_open_item` is labelled "as at last refresh".
- Head Office is branch 100 in the branch role filter.
- The FS hierarchy (type → element → category → caption → line → natural account) sorts by the `sort_order` columns.

---

## 11. Open items

| # | Item | Needed before | Default if unresolved |
|---|---|---|---|
| O-P3-1 | 69 posted accounts without an FS line (54 Head Office only); worklist `fs_account_unmapped.csv` | Statement sign-off | Not mapped line, monitored. 2026-10-07: 70 accounts (11105801 Unidentified Receipts Control, Unaizah, added to the worklist); the user decided finance fills the worklist. Largest income-statement items: 41501102 Corp. Other Disc., Insurance Companies (60.0M debit), 43102801 HO Supervising Revenue (20.0M), interest and rental income |
| O-P3-2 | Review of the 97 inferred mappings; one is borderline: Withholding Tax Payables on the *VAT Payable* line (caption correct) | Statement sign-off | Used as inferred |
| O-P3-4 | Alrabwah's Fusion go-live date | Alrabwah statements | Branch shows no GL |
| O-P3-5 | `fs_mapping` branch 5 code `1` maps to two positions | Go-live tie for branch 5 | **Closed 2026-10-07:** the duplicate joins no posted account (branch 5 has 20,671 rows and 20,671 unique keys in the old `vw_account_tree`), so it has no effect |
| O-P3-6 | Care type of Endoscopy, Cath and Kidney Dialysis revenue | Revenue against budget by care type | **Closed 2026-10-07:** the user ruled they can be either, determined by the episode's care type. Fusion has no Endoscopy, Cath or Dialysis service location: their revenue posts under the OPD, IPD and ER locations that the Oasis feed takes from the encounter, so the GL care type already follows the episode. Locations 07–11 are unused; if they appear, their care type must come from the episode (not a fixed OP) |
| O-P3-7 | Contractual discounts (Cash, Credit, Package discount) have no budget code: are budget revenue lines net of them? | Revenue against budget | **Closed 2026-10-07 (default kept):** assigned to the revenue code of their care type (actual revenue net of contractual discounts) |
| O-P3-8 | DC_CONSUMABLES and DC_MEDICINES against Oracle's single *Cost of Medicines* caption | Direct cost against budget | **Closed 2026-10-07:** the user ruled DC_CONSUMABLES is medical consumables, not cost of medicines. DC_MEDICINES compares with the Cost of Medicines caption only; Fusion has no medical-consumables account yet, so DC_CONSUMABLES actual is 0 until finance maps one (with the O-P3-1 worklist) |
| O-P3-9 | Review of the drafted `map_fs_line_order`, `map_budget_fs_line`, `map_fusion_specialty_unified` | Build | Drafts used |
| O-P3-10 | Old-server export of the Financial Statements report for each go-live month | Go-live tie | **Closed 2026-10-07:** validated directly on the old server (DSN `chDWH`) with the saved TMDL model's logic; Abha, Jazan (after mapping) and Unaizah tie, Khamis does not (about 26M insurance discount and 4.8M accruals/end of service only in Fusion), Madinah has no opening balance yet. Follow-ups with finance; results in `docs/reconciliation_phase3.md` |
| O-P3-11 | Insurer AR ageing (Oasis statements less NPHIES remittance) | Later phase | Not built |
| O-P3-12 | Khamis' go-live batch (`je_batch_id` 248206, "OB_TB_Khamis Aug-26 Adjustment", source Spreadsheet, category Adjustment, 521 lines, about 1.37bn SAR debits, 195.7M SAR revenue, unposted, August 2026) is not categorised MRC Open Balances | Khamis monthly trend | **Closed 2026-10-07:** the user chose an override list. `default.map_opening_balance_batch` lists batches that are opening balances whatever their category; `is_opening_balance_journal` = category MRC Open Balances or a listed batch. The row becomes redundant once finance re-categorises the batch |

---

## 12. Changes during implementation (2026-10-05)

- ClickHouse applies a SETTINGS clause after `union all` only to the last branch, so models whose left joins sit in CTEs feeding a union end those CTEs with `hnh_settings()` (`hnh_dim_gl_account`, `fact_gl_balance_monthly`, `fact_income_statement_monthly`, `rec_gl_balance_monthly`, `rec_gl_revenue_monthly`).
- `rec_income_statement_budget`'s tolerance is 1 SAR, not 0.01: the budget file stores its subtotal rows rounded (differences up to 0.12 SAR measured on 2026-10-05).
- `warn_intercompany_mismatch` evaluates every unordered branch pair once (least/greatest), so a flow booked on one side only is reported.
- `rec_gl_revenue_monthly` includes Oasis-only months from each branch's first GL month onward, so a month with Oasis revenue and no GL revenue is visible.
- The draft specialty mapping proposes a unified department for 206 of 324 Fusion specialties; administrative departments are left blank (Unknown).
- 2026-10-07 (O-P3-12): `hnh_fact_gl_journal_line.is_opening_balance_journal` is also 1 for a batch listed in `default.map_opening_balance_batch` (`stg_ref__opening_balance_batch`; one row, Khamis batch 248206). Khamis then has no GL revenue outside opening balances (it has no Oasis-feed journals for August or September 2026), so it has no rows in `rec_gl_revenue_monthly`.
