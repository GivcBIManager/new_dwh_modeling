{{ config(severity='warn') }}
-- Journal headers whose debits and credits differ (all were unposted at 2026-10-05: 19 headers).
select je_header_id, any(branch_key) as branch_key, any(is_posted) as is_posted, round(sum(amount), 2) as out_of_balance
from {{ ref('hnh_fact_gl_journal_line') }}
group by je_header_id
having abs(sum(amount)) > 0.005
