-- Scorecard category of each hospital (bsc ssas spec 6.2). default.map_bsc_hospital_category is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    branch_id,
    latest.1 as category,
    latest.3 as last_changed_at
from (
    select branch_id,
           argMax(tuple(trimBoth(category), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_hospital_category') }}
    group by branch_id
)
where latest.2 = 0
