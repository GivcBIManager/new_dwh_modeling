{{ config(severity='warn') }}
-- Sent claims (latest submission) with no NPHIES answer, by branch and statement month; the current month is excluded.
select branch_key, intDiv(statement_end_date_key, 100) as statement_month, count() as lines, sum(claimed_amount) as claimed
from {{ ref('fact_claim_line') }}
where is_sent = 1 and is_latest_submission = 1 and adjudication_status = 'No response'
  and statement_end_date_key < toInt32(toYYYYMMDD(toStartOfMonth(today())))
group by branch_key, statement_month
