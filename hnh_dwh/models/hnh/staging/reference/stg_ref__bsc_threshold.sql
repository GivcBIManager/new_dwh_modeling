-- Score thresholds; kpi_code '*' is the default (bsc ssas spec 6.2). default.map_bsc_threshold is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    kpi_code,
    latest.1 as score_base,
    latest.2 as score_slope,
    latest.3 as good_from,
    latest.4 as watch_from,
    latest.6 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           argMax(tuple(score_base, score_slope, good_from, watch_from, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_threshold') }}
    group by kpi_code
)
where latest.5 = 0
