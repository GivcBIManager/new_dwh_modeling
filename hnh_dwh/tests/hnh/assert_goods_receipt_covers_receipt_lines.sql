-- fact_goods_receipt holds every receipt line in scope exactly once, with the same value (spec 8): the Oasis GRN and
-- return-to-supplier lines of int_oasis_stock_line (STOCKRCPT GRN, STOCKISS RFN) and the Fusion RECEIVE / RETURN TO
-- VENDOR transactions of branches from their first Fusion purchasing month.
with expected as (
    select 'oasis' as source_system, movement_type = 'Return to supplier' as is_return, count() as n,
           round(sum(cost_amount), 2) as value
    from {{ ref('int_oasis_stock_line') }}
    where movement_type in ('Goods receipt', 'Return to supplier')
    group by source_system, is_return
    union all
    select 'fusion' as source_system, r.transaction_type = 'RETURN TO VENDOR' as is_return, count() as n,
           round(sum(if(r.primary_quantity != 0, r.quantity * r.po_unit_price, r.amount)
                     * if(r.transaction_type = 'RETURN TO VENDOR', -1, 1)), 2) as value
    from {{ ref('stg_fusion__receipt_transactions') }} as r
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = r.organization_id
    inner join {{ ref('stg_ref__scm_cutover') }} as k on k.branch_id = o.branch_key
    where r.transaction_type in ('RECEIVE', 'RETURN TO VENDOR') and r.transaction_date is not null
      and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(r.transaction_date)) >= k.first_fusion_purchasing_month
    group by source_system, is_return
),
actual as (
    select source_system, receipt_type = 'RETURN TO VENDOR' as is_return, count() as n,
           round(sum(received_value), 2) as value
    from {{ ref('fact_goods_receipt') }}
    group by source_system, is_return
)
select e.source_system, e.is_return, e.n as expected_rows, a.n as fact_rows, e.value as expected_value, a.value as fact_value
from expected as e
full outer join actual as a on a.source_system = e.source_system and a.is_return = e.is_return
where e.n != a.n or abs(e.value - a.value) > 0.01
settings join_use_nulls = 0
