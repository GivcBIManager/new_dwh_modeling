{{ config(severity='warn') }}
-- Live charges of the last 365 days whose delivery line has no order line, or an order line
-- that is not in Oasis order_lines, by branch.
select c.branch_id as branch_id, count() as charges, sum(c.price_paid_purchaser) as amount
from {{ ref('stg_oasis__charges') }} as c
left join (select branch_id, delivery_line, order_line from {{ ref('stg_oasis__delivery_lines') }}) as d
    on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
left join (select branch_id, order_line from {{ ref('stg_oasis__order_lines') }}) as ol
    on ol.branch_id = c.branch_id and ol.order_line = d.order_line
where c.cancel_flag is null
  and c.delivered_at >= toDateTime(today() - 365, 'Asia/Riyadh')
  and (d.order_line is null or ol.order_line is null)
group by c.branch_id
settings join_use_nulls = 1
