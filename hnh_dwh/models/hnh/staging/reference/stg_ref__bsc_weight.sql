-- KPI weight inside its pillar per profile ('corporate' or 'branch:<id>') (bsc ssas spec 6.2). default.map_bsc_weight is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    profile,
    kpi_code,
    latest.1 as weight,
    latest.3 as last_changed_at
from (
    select trimBoth(profile) as profile,
           trimBoth(kpi_code) as kpi_code,
           argMax(tuple(weight, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_weight') }}
    group by profile, kpi_code
)
where latest.2 = 0
