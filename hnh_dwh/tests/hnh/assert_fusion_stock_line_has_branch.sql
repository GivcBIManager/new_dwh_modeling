-- Every Fusion inventory transaction resolves to a branch through its posting organisation: no row is on branch 0.
select fusion_transaction_id, organization_id
from {{ ref('int_fusion_stock_line') }}
where branch_key = 0
