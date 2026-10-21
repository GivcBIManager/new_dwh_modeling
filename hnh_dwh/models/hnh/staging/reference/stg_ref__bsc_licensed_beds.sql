-- Licensed beds per hospital and year for KPI 60 (bsc ssas spec, further definitions of 2026-10-21).
-- default.map_bsc_licensed_beds is an insert-only change log: the latest row per key wins and a latest row with
-- is_deleted = 1 removes the key.
select
    branch_id,
    year,
    latest.1 as licensed_beds,
    latest.3 as last_changed_at
from (
    select branch_id,
           year,
           argMax(tuple(licensed_beds, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_licensed_beds') }}
    group by branch_id, year
)
where latest.2 = 0
