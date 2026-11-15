{{ config(severity='warn') }}
-- Hospitals whose KPI weights do not add up to 1 (100% of the scorecard), as their profile (own, category or
-- corporate) gives them (bsc ssas spec 6.2). The overall score still averages the scored pillars by their shares.
select branch_key, sum(weight) as total
from {{ ref('fact_bsc_weight') }}
group by branch_key
having abs(total - 1) > 0.0001
