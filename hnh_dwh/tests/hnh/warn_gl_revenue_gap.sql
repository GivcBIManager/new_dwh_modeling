{{ config(severity='warn') }}
-- Closed months where GL net revenue differs from Oasis recognised revenue by more than 2%.
select branch_key, month_start, round(gl_net_revenue, 2) as gl_net_revenue, round(oasis_revenue_total, 2) as oasis_revenue,
       round(ratio, 4) as ratio
from {{ ref('rec_gl_revenue_monthly') }}
where month_start < toStartOfMonth(today()) and oasis_revenue_total != 0 and abs(difference) / abs(oasis_revenue_total) > 0.02
