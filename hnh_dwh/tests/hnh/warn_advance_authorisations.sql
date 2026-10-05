{{ config(severity='warn') }}
-- Payer-initiated advance authorisations are staged but not reported (spec open item O-P2B-3).
select branch_id, toStartOfMonth(toDate(responded_at)) as month_start, uniqExact(response_id) as authorisations
from {{ ref('stg_oasis__pull_responses') }}
where response_type = 'advanced-authorization'
group by branch_id, month_start
