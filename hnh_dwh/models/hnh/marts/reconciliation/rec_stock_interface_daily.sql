{{ config(order_by='(branch_key, line_date)') }}

-- Per branch and day from the first Fusion inventory month (spec 8): Oasis stock lines against the Fusion integration
-- transactions (count, quantity, cost) and the gap share from the go-live. Fusion rows before the go-live, integration
-- rows without a reference and Oasis batch postings from the go-live are shown here; they are not in fact_stock_movement.
-- fusion_out_of_scope_reversals counts the integration rows dropped as reversed invoices, creditar or package headers:
-- they are inside fusion_integration_transactions but never become lines, so subtract them to reconcile the gap figures.
{% set start = "toDate32('" ~ var('hnh_fusion_inventory_start') ~ "')" %}

with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }} where inventory_go_live_date is not null
),

fusion_refs as (
    select distinct branch_key as ref_branch_key, assumeNotNull(oasis_line_id) as ref_line_id
    from {{ ref('int_fusion_stock_line') }}
    where reference_status = 'oasis_line'
),

oasis_daily as (
    select o.branch_key as branch_key, o.line_date as line_date, count() as oasis_lines,
           sum(o.primary_quantity) as oasis_quantity, sum(o.cost_amount) as oasis_cost,
           countIf(f.ref_line_id is not null) as oasis_lines_in_fusion,
           countIf(o.is_batch_posting = 1 and k.go_live_date is not null and o.line_date >= k.go_live_date) as batch_lines_left_out
    from {{ ref('int_oasis_stock_line') }} as o
    left join fusion_refs as f on f.ref_branch_key = o.branch_key and f.ref_line_id = o.oasis_line_id
    left join cutover as k on k.branch_id = o.branch_key
    where o.line_date >= {{ start }}
    group by o.branch_key, o.line_date
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
),

fusion_daily as (
    select f.branch_key as branch_key, toDate32(f.transaction_date) as line_date,
           countIf(f.is_integration_type = 1) as fusion_integration_transactions,
           sumIf(f.primary_quantity, f.is_integration_type = 1) as fusion_quantity,
           sumIf(f.primary_quantity * ifNull(f.valuation_unit_cost, 0), f.is_integration_type = 1) as fusion_cost,
           countIf(f.reference_status = 'no_reference') as fusion_without_reference,
           countIf(k.go_live_date is null or f.transaction_date < k.go_live_date) as fusion_before_go_live,
           countIf(f.reference_status = 'oasis_out_of_scope'
                   and f.oasis_scope_reason in ('reversed_invoice', 'creditar', 'package_header')) as fusion_out_of_scope_reversals
    from {{ ref('int_fusion_stock_line') }} as f
    left join cutover as k on k.branch_id = f.branch_key
    group by f.branch_key, line_date
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

fact_daily as (
    select branch_key, toDate32(toDate(toString(date_key))) as line_date,
           countIf(oasis_line_id is not null and (source_system = 'fusion' or is_fusion_gap = 1)) as lines_from_go_live,
           countIf(is_fusion_gap = 1) as gap_lines
    from {{ ref('fact_stock_movement') }}
    where date_key >= toInt32(toYYYYMMDD({{ start }}))
    group by branch_key, line_date
),

spine as (
    select branch_key, line_date from oasis_daily
    union distinct select branch_key, line_date from fusion_daily
)

select
    s.branch_key                                            as branch_key,
    s.line_date                                             as line_date,
    {{ hnh_date_key('s.line_date') }}                       as date_key,
    toUInt8(k.go_live_date is not null and s.line_date >= k.go_live_date) as is_live,
    ifNull(o.oasis_lines, 0)                                as oasis_lines,
    ifNull(o.oasis_quantity, 0)                             as oasis_quantity,
    ifNull(o.oasis_cost, 0)                                 as oasis_cost,
    ifNull(o.oasis_lines_in_fusion, 0)                      as oasis_lines_in_fusion,
    ifNull(f.fusion_integration_transactions, 0)            as fusion_integration_transactions,
    ifNull(f.fusion_quantity, 0)                            as fusion_quantity,
    ifNull(f.fusion_cost, 0)                                as fusion_cost,
    ifNull(f.fusion_without_reference, 0)                   as fusion_without_reference,
    ifNull(f.fusion_before_go_live, 0)                      as fusion_before_go_live,
    ifNull(o.batch_lines_left_out, 0)                       as batch_lines_left_out,
    ifNull(d.lines_from_go_live, 0)                         as lines_from_go_live,
    ifNull(d.gap_lines, 0)                                  as gap_lines,
    if(ifNull(d.lines_from_go_live, 0) = 0, cast(null as Nullable(Float64)),
       ifNull(d.gap_lines, 0) / d.lines_from_go_live)       as gap_share,
    ifNull(f.fusion_out_of_scope_reversals, 0)              as fusion_out_of_scope_reversals
from spine as s
left join cutover as k on k.branch_id = s.branch_key
left join oasis_daily as o on o.branch_key = s.branch_key and o.line_date = s.line_date
left join fusion_daily as f on f.branch_key = s.branch_key and f.line_date = s.line_date
left join fact_daily as d on d.branch_key = s.branch_key and d.line_date = s.line_date
{{ hnh_settings() }}
