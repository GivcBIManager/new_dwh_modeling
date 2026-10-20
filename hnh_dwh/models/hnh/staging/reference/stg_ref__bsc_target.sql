-- Fixed KPI targets; branch_id 0 = every hospital, month 0 = the whole year (bsc ssas spec 6.2). default.map_bsc_target is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    kpi_code,
    branch_id,
    year,
    month,
    latest.1 as target_value,
    latest.2 as scale_with_months,
    latest.3 as source_basis,
    latest.5 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           branch_id,
           year,
           month,
           argMax(tuple(target_value, scale_with_months, trimBoth(source_basis), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_target') }}
    group by kpi_code, branch_id, year, month
)
where latest.4 = 0
