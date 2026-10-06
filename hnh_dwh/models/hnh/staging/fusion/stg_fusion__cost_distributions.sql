select
    distribution_line_id,
    ledger_id,
    cost_organization_id,
    inventory_item_id,
    {{ hnh_code('accounting_line_type') }}  as accounting_line_type,
    {{ hnh_code('accounted_flag') }}        as accounted_flag,
    toDate(gl_date)                         as gl_date,
    toFloat64(ifNull(ledger_amount, 0))     as ledger_amount
from {{ hnh_fusion_source('fact_cost_distribution') }} final
