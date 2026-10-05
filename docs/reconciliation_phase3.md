# Phase 3 reconciliation

Run after a successful `dbt build --select tag:hnh`.

## Fusion balances (`gold.rec_gl_balance_monthly`)

Posted journal debits and credits per branch and period beside Fusion's `fact_gl_balance`, and the number of accounts whose posted closing balance differs from Fusion's (begin + debits − credits). Acceptance: all differences 0 for every period Fusion has. Khamis and Alrabwah have no rows in Fusion's balance table (Alrabwah has no journals at all).

From January 2027 Fusion carries the 2026 result in the begin balance of the real retained-earnings combination, while gold keeps it on the synthetic prior-year roll account (excluded from the account comparison), so `accounts_with_closing_difference` will show the retained-earnings account(s) per branch from 2027. Before the 2027 build, compare retained earnings at branch level including the roll account.

## GL revenue against Oasis (`gold.rec_gl_revenue_monthly`)

GL revenue by care type (service location; Oasis feed and manual journals, including unposted, opening-balance journals excluded) less contractual discounts, beside Oasis recognised revenue from `fact_charge_line`. `warn_gl_revenue_gap` lists closed months more than 2% apart. Most Oasis-feed batches were unposted at 2026-10-05, so compare the including-unposted GL figures. Khamis August 2026 (ratio 6.76) is explained by open item O-P3-12 in the design spec: the go-live batch is not categorised as an opening balance.

## Budget subtotals (`gold.rec_income_statement_budget`)

The model computes every budget subtotal from detail lines with the same formulas as actuals (spec G12). `difference` against the budget file's subtotal rows must be 0 within 1 SAR (the file stores its subtotals rounded).

## Go-live tie to the old Financial Statements report

The old report reads the Oasis GL on the old server, so it is compared once per branch, at go-live: each branch's opening-balance journal (`is_opening_balance_journal = 1`) should equal the old report's closing balances for the month before go-live.

| Branch | Fusion go-live month | Old report month to export |
|---|---|---|
| 7 Ghirnata | January 2026 | December 2025 |
| 6 Abha | February 2026 | January 2026 |
| Head Office | April 2026 | March 2026 |
| 3 Jazan | June 2026 | May 2026 |
| 8 Muhayil | June 2026 | May 2026 |
| 4 Unaizah | July 2026 | June 2026 |
| 2 Khamis | August 2026 | July 2026 |
| 5 Madinah | September 2026 | August 2026 |

Khamis' go-live batch is not categorised MRC Open Balances (O-P3-12), so the opening-balance query returns no Khamis rows until finance re-categorises it; compare its Adjustment batch of August 2026 instead.

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

Old side: in the old Financial Statements model, filter the branch and the month before go-live and export `Balance` by AccountType, FSElement and FSCategory. `default.map_oasis_fs_account` (`stg.stg_ref__oasis_fs_account`) is the same mapping the old report used, for drilling into a category. Compare at category level: captions differ between the two vocabularies (Oasis splits revenue by care setting and has Medical Consumables; Oracle splits revenue by payer and has Cost of Medicines). Branch 5 code `1` is mapped twice in the Oasis mapping and is left out (spec O-P3-5).

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
