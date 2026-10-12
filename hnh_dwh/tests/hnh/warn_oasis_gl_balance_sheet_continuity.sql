{{ config(severity='warn') }}
-- Oasis asset and liability accounts carry their December closing balance into January through the brought-forward
-- rows (bsc spec 5.2). Breaks are source data: 7 on 2026-10-12, 0.07M SAR in total.
with acct as (
    select branch_key, account_code, toYear(month_start) as yr, toMonth(month_start) as mo,
           sum(closing_balance) as close_bal, sum(opening_balance + opening_journal_amount) as open_bal
    from {{ ref('fact_gl_fs_monthly') }}
    where source_system = 'oasis' and fs_element in ('assets', 'liabilities') and toMonth(month_start) in (1, 12)
    group by branch_key, account_code, yr, mo
)
select d.branch_key, d.account_code, d.yr + 1 as year, d.close_bal as december_closing, ifNull(j.open_bal, 0) as january_opening
from (select * from acct where mo = 12) as d
left join (select * from acct where mo = 1) as j
  on j.branch_key = d.branch_key and j.account_code = d.account_code and j.yr = d.yr + 1
where d.yr < toYear(today()) and abs(d.close_bal - ifNull(j.open_bal, 0)) > 0.01
{{ hnh_settings() }}
