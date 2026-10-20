-- Code lists the KPI measures filter on (ancillary_category, satisfaction_nps_role) (bsc ssas spec 6.2). default.map_bsc_code_list is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    list_name,
    code,
    latest.2 as last_changed_at
from (
    select trimBoth(list_name) as list_name,
           trimBoth(code) as code,
           argMax(tuple(is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_code_list') }}
    group by list_name, code
)
where latest.1 = 0
