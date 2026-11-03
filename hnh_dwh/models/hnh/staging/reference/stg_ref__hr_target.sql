-- HR KPI targets; branch_id 0 = every branch (hospitals 1-8 and Head Office 100), month 0 = the whole year (HR dashboard design, model changes). default.map_hr_target is an insert-only
-- change log: the latest row per key wins and a latest row with is_deleted = 1 removes the key. is_placeholder marks a target HR has not yet confirmed.
select
    kpi_code,
    branch_id,
    year,
    month,
    latest.1 as target_value,
    latest.2 as watch_value,
    latest.3 as scale_with_months,
    latest.4 as source_basis,
    toUInt8(startsWith(latest.4, 'Placeholder')) as is_placeholder,
    latest.6 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           branch_id,
           year,
           month,
           argMax(tuple(target_value, watch_value, scale_with_months, trimBoth(source_basis), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_hr_target') }}
    group by kpi_code, branch_id, year, month
)
where latest.5 = 0
