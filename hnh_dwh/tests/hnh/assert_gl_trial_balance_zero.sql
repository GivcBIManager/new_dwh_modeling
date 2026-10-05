-- Posted balances of a branch sum to zero in every period (prior-year roll included).
select branch_key, period_key, round(sum(closing_balance), 2) as out_of_balance
from {{ ref('fact_gl_balance_monthly') }}
where balance_view = 'posted'
group by branch_key, period_key
having abs(sum(closing_balance)) > 0.01
