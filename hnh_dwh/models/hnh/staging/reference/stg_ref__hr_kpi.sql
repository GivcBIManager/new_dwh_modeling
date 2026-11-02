-- HR dashboard KPI and metric catalogue (HR dashboard design, model changes). default.map_hr_kpi is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    kpi_code,
    latest.1 as kind,
    latest.2 as kpi_name,
    latest.3 as short_label,
    latest.4 as area,
    latest.5 as definition,
    latest.6 as formula,
    latest.7 as source_system,
    latest.8 as grain,
    latest.9 as caveats,
    latest.10 as direction,
    latest.11 as value_format,
    latest.12 as display_order,
    latest.13 as measure_name,
    latest.14 as bsc_kpi_code,
    latest.15 as target_source,
    latest.16 as needs_pay,
    latest.17 as is_home_tile,
    latest.18 as status,
    latest.20 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           argMax(tuple(trimBoth(kind), trimBoth(kpi_name), trimBoth(short_label), trimBoth(area), trimBoth(definition), trimBoth(formula), trimBoth(source_system), trimBoth(grain), trimBoth(caveats), trimBoth(direction), trimBoth(value_format), display_order, trimBoth(measure_name), trimBoth(bsc_kpi_code), trimBoth(target_source), needs_pay, is_home_tile, trimBoth(status), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_hr_kpi') }}
    group by kpi_code
)
where latest.19 = 0
