-- Finance KPI targets; branch_id 0 = all hospitals (finance report design). default.map_finance_target is an insert-only change log: the latest row
-- per key wins and a latest row with is_deleted = 1 removes the key. watch_pct 0 means the default 0.05.
select
    kpi_code,
    branch_id,
    year,
    latest.1 as target_value,
    if(latest.2 = 0, 0.05, latest.2) as watch_pct,
    latest.4 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           branch_id,
           year,
           argMax(tuple(target_value, watch_pct, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_finance_target') }}
    group by kpi_code, branch_id, year
)
where latest.3 = 0
