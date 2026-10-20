-- Budgeted FTE per hospital and year (job vacancy rate denominator) (bsc ssas spec 6.2). default.map_bsc_budgeted_fte is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    branch_id,
    year,
    latest.1 as budgeted_fte,
    latest.3 as last_changed_at
from (
    select branch_id,
           year,
           argMax(tuple(budgeted_fte, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_budgeted_fte') }}
    group by branch_id, year
)
where latest.2 = 0
