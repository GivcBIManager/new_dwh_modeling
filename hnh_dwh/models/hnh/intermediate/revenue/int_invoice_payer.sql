{{ config(order_by='(branch_id, account_code)') }}

with policies as (
    -- Inner names differ from the output aliases so ClickHouse does not resolve them to the aggregates.
    select branch_id, assumeNotNull(account_no) as acct, policy_code, assumeNotNull(purchaser_code) as purch
    from {{ ref('stg_oasis__policies') }}
    where account_no is not null and purchaser_code is not null
)

select
    branch_id,
    acct                        as account_code,
    argMin(purch, policy_code)  as purchaser_code,
    uniqExact(purch)            as purchaser_count
from policies
group by branch_id, acct
