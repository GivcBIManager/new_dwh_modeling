{{ config(severity='warn') }}
-- Outpatient invoices equal claimable charges (100% of a May 2026 sample). Mismatches in closed months
-- mean a billing rule changed; invoice_month shows when it started.
select branch_key, intDiv(last_invoice_date_key, 100) as invoice_month,
       count() as episodes, sum(abs(claimable_amount - invoiced_net_amount)) as difference
from {{ ref('agg_episode_billing') }}
where care_type_key = 1 and invoice_count > 0
  and last_invoice_date_key < toInt32(toYYYYMMDD(toStartOfMonth(today())))
  and abs(claimable_amount - invoiced_net_amount) >= 1
group by branch_key, invoice_month
