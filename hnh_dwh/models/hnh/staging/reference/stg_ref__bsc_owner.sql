-- KPI owner and co-owners (information only); branch_id 0 = Corporate (bsc ssas spec 6.2). default.map_bsc_owner is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    kpi_code,
    branch_id,
    latest.1 as owner,
    latest.2 as co_owners,
    latest.4 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           branch_id,
           argMax(tuple(trimBoth(owner), trimBoth(co_owners), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_owner') }}
    group by kpi_code, branch_id
)
where latest.3 = 0
