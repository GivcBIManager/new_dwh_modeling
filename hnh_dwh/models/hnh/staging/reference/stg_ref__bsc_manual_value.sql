-- Monthly KPI values entered by the BI manager (bsc ssas spec 6.2). default.map_bsc_manual_value is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    kpi_code,
    branch_id,
    year,
    month,
    latest.1 as numerator,
    latest.2 as denominator,
    latest.3 as note,
    latest.5 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           branch_id,
           year,
           month,
           argMax(tuple(numerator, denominator, trimBoth(note), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_manual_value') }}
    group by kpi_code, branch_id, year, month
)
where latest.4 = 0
