-- Every branch must have the Cash (9999) and Deductible (8888) members,
-- and the Unknown member must exist exactly once.
select branch_key, countIf(purchaser_code = 9999) as cash, countIf(purchaser_code = 8888) as deductible
from {{ ref('dim_payer') }}
where branch_key between 1 and 8
group by branch_key
having cash != 1 or deductible != 1

union all

select toUInt8(0), toUInt64(count()), toUInt64(0)
from {{ ref('dim_payer') }}
where payer_key = -1
having count() != 1
