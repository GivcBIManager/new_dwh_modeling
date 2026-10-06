-- Conservation (spec 8): every in-scope Oasis line appears in fact_stock_movement exactly once (as itself or through
-- Fusion), except Oasis batch postings from the go-live; and every Fusion transaction that is a line of its own (not an
-- integration row, a reference Oasis does not hold, or a reference to an Oasis line that is out of scope for a reason
-- other than a reversed invoice, CREDITAR or a package header, from the go-live) appears exactly once. Per branch.
with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }} where inventory_go_live_date is not null
),

expected_oasis as (
    select o.branch_key as branch_key, count() as expected_lines
    from {{ ref('int_oasis_stock_line') }} as o
    left join cutover as k on k.branch_id = o.branch_key
    where not (k.go_live_date is not null and o.line_date >= k.go_live_date and o.is_batch_posting = 1)
    group by o.branch_key
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

expected_fusion as (
    select f.branch_key as branch_key, count() as expected_lines
    from {{ ref('int_fusion_stock_line') }} as f
    inner join cutover as k on k.branch_id = f.branch_key
    where f.transaction_date >= k.go_live_date
      and (f.reference_status in ('not_integration', 'not_in_oasis')
           or (f.reference_status = 'oasis_out_of_scope'
               and ifNull(f.oasis_scope_reason, '') not in ('reversed_invoice', 'creditar', 'package_header')))
    group by f.branch_key
),

actual as (
    select branch_key, countIf(oasis_line_id is not null) as oasis_lines, countIf(oasis_line_id is null) as fusion_lines
    from {{ ref('fact_stock_movement') }}
    group by branch_key
),

compared as (
    select branch_key, sum(e_oasis) as expected_oasis, sum(a_oasis) as actual_oasis, sum(e_fusion) as expected_fusion,
           sum(a_fusion) as actual_fusion
    from (
        select branch_key, toInt64(expected_lines) as e_oasis, toInt64(0) as a_oasis, toInt64(0) as e_fusion, toInt64(0) as a_fusion from expected_oasis
        union all
        select branch_key, 0, 0, toInt64(expected_lines), 0 from expected_fusion
        union all
        select branch_key, 0, toInt64(oasis_lines), 0, toInt64(fusion_lines) from actual
    )
    group by branch_key
)

select * from compared
where expected_oasis != actual_oasis or expected_fusion != actual_fusion
