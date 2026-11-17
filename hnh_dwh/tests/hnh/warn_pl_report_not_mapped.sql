{{ config(severity='warn') }}
-- Income-statement accounts on a Not mapped line of the P&L report from 2026: labels no rule of pl_report_line_rule
-- knows. One row per branch, month, source, account and labels (Fusion slicer values added up).
select r.branch_key as branch_key, r.month_start as month_start, r.source_system as source_system,
       r.account_code as account_code, r.fs_category as fs_category, r.fs_caption as fs_caption, r.fs_line as fs_line,
       round(sum(r.amount), 2) as amount
from {{ ref('fact_pl_report_monthly') }} as r
where r.month_start >= toDate('2026-01-01')
  and abs(r.amount) >= 0.01
  and r.pl_line_code in (select pl_line_code from {{ ref('dim_pl_report_line') }} where line_kind = 'not_mapped')
group by branch_key, month_start, source_system, account_code, fs_category, fs_caption, fs_line
