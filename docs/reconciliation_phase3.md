# Phase 3 reconciliation

Run after a successful `dbt build --select tag:hnh`.

## Fusion balances (`gold.rec_gl_balance_monthly`)

Posted journal debits and credits per branch and period beside Fusion's `fact_gl_balance`, and the number of accounts whose posted closing balance differs from Fusion's (begin + debits − credits). Acceptance: all differences 0 for every period Fusion has. Khamis and Alrabwah have no rows in Fusion's balance table (Alrabwah has no journals at all).

From January 2027 Fusion carries the 2026 result in the begin balance of the real retained-earnings combination, while gold keeps it on the synthetic prior-year roll account (excluded from the account comparison), so `accounts_with_closing_difference` will show the retained-earnings account(s) per branch from 2027. Before the 2027 build, compare retained earnings at branch level including the roll account.

## GL revenue against Oasis (`gold.rec_gl_revenue_monthly`)

GL revenue by care type (service location; Oasis feed and manual journals, including unposted, opening-balance journals excluded) less contractual discounts, beside Oasis recognised revenue from `fact_charge_line`. `warn_gl_revenue_gap` lists closed months more than 2% apart. Most Oasis-feed batches were unposted at 2026-10-05, so compare the including-unposted GL figures. Khamis' go-live batch (248206) is categorised Adjustment, not MRC Open Balances; it is listed in `default.map_opening_balance_batch` (O-P3-12, closed 2026-10-07), so it counts as an opening-balance journal. Before that, Khamis August 2026 showed a ratio of 6.76. Khamis has no Oasis-feed journals in Fusion for August or September 2026, so it has no rows here.

## Budget subtotals (`gold.rec_income_statement_budget`)

The model computes every budget subtotal from detail lines with the same formulas as actuals (spec G12). `difference` against the budget file's subtotal rows must be 0 within 1 SAR (the file stores its subtotals rounded).

## Go-live tie to the old Financial Statements report

The old report reads the Oasis GL on the old server (`default.tr_gl_distribution` through `mv_gl_transactions` and `vw_account_tree`, DSN `chDWH`, 172.22.25.165), so it is compared once per branch, at go-live. Each Fusion opening balance is dated the last day of its month and equals the Oasis close **of that same month** (measured 2026-10-07; the first draft of this table said the month before). Up to that month Fusion has only balance-sheet lines that net to zero and no P&L, so nothing is counted twice.

| Branch | Opening-balance batch (date) | Old report month to compare | Result (2026-10-07) |
|---|---|---|---|
| 6 Abha | 123045 + 104010 (April 2026) | April 2026 | Ties within about 1.3M per line (Fusion accrual, lease and end-of-service adjustments) |
| 3 Jazan | 161095 (30 June 2026, unposted) | June 2026 | Ties after mapping, apart from about 12M of Fusion-only balance-sheet adjustments (lease gross-up 6.46M, end of service 5.43M, prepaid 4.25M); equity within 1.49M, P&L within 0.23M |
| 4 Unaizah | 232206 (31 July 2026) | July 2026 | Ties: every asset difference is mapping; one 1.42M reclass between end-of-service indemnities and equity |
| 2 Khamis | 248206 (31 August 2026, unposted) | August 2026 | Does not tie: the batch carries about 26M of insurance discount against receivables plus about 3.7M accruals and 1.1M end of service not in Oasis; equity within 1.33M |
| 5 Madinah | none yet | August 2026 (if dated 31 August) | No Fusion opening balance loaded |
| 7 Ghirnata, 8 Muhayil | none | — | Nothing to tie: the Oasis GL starts in the same month as Fusion (2026-01 and 2026-06) |
| Head Office | — | — | No Oasis counterpart; tie to Fusion's own opening balance only |

Method: the old `Balance` measure (open-period non-BFWD/RETINCOME rows before the month, BFWD/RETINCOME up to month end, and the month's rows) per FS caption, against Σ `amount` of `is_opening_balance_journal = 1` per FS caption. Oasis has not closed 2025 (its only BFWD is dated 2025-01-01), so Oasis equity is compared with the 2025 P&L added. `map_oasis_fs_account` equals the old `fs_mapping` on all 19,400 rows; the branch 5 code `1` duplicate (O-P3-5) joins no account. Most caption differences are Fusion accounts on the *Not mapped* line (ECL provision 11308106, PPE sub-accounts, 21501105 Employee Cost Accrual, 11502105 Intra-Company Inventory Control), which are in the O-P3-1 worklist. O-P3-10 closed 2026-10-07; the Khamis and Jazan adjustments and Madinah's opening balance are with finance.

Khamis' go-live batch is categorised Adjustment in Fusion (O-P3-12). Filter on `is_opening_balance_journal = 1` (which includes the batches listed in `default.map_opening_balance_batch`), not on the category, to find it.

Head Office has no counterpart in the old report's Oasis mapping (`map_oasis_fs_account` covers branches 1–8); tie it to Fusion's own opening balance only.

New side, per branch and FS category (debit positive):

```sql
select j.branch_key, f.fs_type, f.fs_element, f.fs_category, round(sum(j.amount), 2) as opening_amount
from gold.fact_gl_journal_line as j
join gold.dim_gl_account as a on a.gl_account_key = j.gl_account_key
join gold.dim_fs_line as f on f.fs_line_key = a.fs_line_key
where j.is_opening_balance_journal = 1
group by j.branch_key, f.fs_type, f.fs_element, f.fs_category
order by j.branch_key, f.fs_type, f.fs_element, f.fs_category
```

Old side: in the old Financial Statements model, filter the branch and the opening balance's own month (see the table above) and export `Balance` by AccountType, FSElement and FSCategory. `default.map_oasis_fs_account` (`stg.stg_ref__oasis_fs_account`) is the same mapping the old report used, for drilling into a category. Compare at category level: captions differ between the two vocabularies (Oasis splits revenue by care setting and has Medical Consumables; Oracle splits revenue by payer and has Cost of Medicines). Branch 5 code `1` is mapped twice in the Oasis mapping and is left out (spec O-P3-5).

## Monitors at first build

| Monitor | Rows | Note |
|---|---|---|
| warn_unmapped_fs_accounts | 52 | Posted accounts on a Not mapped line; worklist `static_mappings/fs_account_unmapped.csv` (O-P3-1); rows are branch × natural account with posted lines; the 69 accounts of O-P3-1 count accounts with any posting, posted or not, across branches |
| warn_unposted_gl_batches | 31 | Branch-periods with unposted batches |
| warn_unbalanced_journals | 19 | 19 unposted headers at 2026-10-05 |
| warn_intercompany_mismatch | 20 | |
| warn_revenue_without_location | 20 | |
| warn_gl_revenue_gap | 23 | |
| warn_ap_without_supplier | 0 | |
| warn_fs_levels_without_order | 0 | |
