-- Scorecard parameters (bsc ssas spec 6.2, KPIs 22 and 28): clinic hours per day, patients per hour, ancillary target
-- share. default.map_bsc_parameter is an insert-only change log: the latest row per name wins and a latest row with
-- is_deleted = 1 removes the name.
select
    name,
    latest.1 as value,
    latest.3 as last_changed_at
from (
    select trimBoth(name) as name,
           argMax(tuple(value, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_parameter') }}
    group by name
)
where latest.2 = 0
