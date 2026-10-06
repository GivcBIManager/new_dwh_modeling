-- No Oasis line appears twice (as itself and through a Fusion transaction) and no Fusion transaction appears twice
-- (spec 8, S2).
select 'oasis line twice' as failure, toString(branch_key) as branch, toString(oasis_line_id) as id, count() as rows
from {{ ref('fact_stock_movement') }}
where oasis_line_id is not null
group by branch_key, oasis_line_id
having count() > 1

union all

select 'fusion transaction twice', toString(any(branch_key)), toString(fusion_transaction_id), count()
from {{ ref('fact_stock_movement') }}
where fusion_transaction_id is not null
group by fusion_transaction_id
having count() > 1
