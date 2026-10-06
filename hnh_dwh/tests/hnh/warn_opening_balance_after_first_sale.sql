{{ config(severity='warn') }}
-- Branches whose Fusion opening balance is dated after their first Fusion patient sale (spec O-P5-7, Muhayil).
with sales as (
    select branch_key, min(transaction_date) as first_sale
    from {{ ref('int_fusion_stock_line') }}
    where transaction_type_id = 300000012981827
    group by branch_key
),
openings as (
    select branch_key, min(transaction_date) as first_opening
    from {{ ref('int_fusion_stock_line') }}
    where is_opening_balance = 1 and transaction_type_id = 42
    group by branch_key
)
select o.branch_key, s.first_sale, o.first_opening
from openings as o
inner join sales as s on s.branch_key = o.branch_key
where o.first_opening > s.first_sale
