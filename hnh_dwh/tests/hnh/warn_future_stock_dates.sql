{{ config(severity='warn') }}
-- Oasis stock lines and bin transactions dated after today (spec F14: bintran dates reach 2299).
select 'stock line' as kind, branch_key, count() as rows, max(line_date) as latest
from {{ ref('int_oasis_stock_line') }}
where line_date > toDate32(today())
group by branch_key
union all
select 'bin transaction', branch_id, count(), max(transaction_date)
from {{ ref('stg_oasis__store_requisitions') }}
where transaction_date > toDate32(today())
group by branch_id
