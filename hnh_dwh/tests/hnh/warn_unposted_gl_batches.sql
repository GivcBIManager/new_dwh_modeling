{{ config(severity='warn') }}
-- Unposted journal batches by branch and period: they are in the including_unposted view only.
select branch_key, period_key, uniqExact(je_batch_id) as batches, count() as lines, round(sum(debit), 2) as debit
from {{ ref('hnh_fact_gl_journal_line') }}
where is_posted = 0
group by branch_key, period_key
