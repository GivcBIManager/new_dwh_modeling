-- Balanced-scorecard KPI catalogue (bsc ssas spec 6.2). default.map_bsc_kpi is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    kpi_code,
    latest.1 as kpi_num,
    latest.2 as kpi_name,
    latest.3 as short_label,
    latest.4 as objective_code,
    latest.5 as kpi_type,
    latest.6 as direction,
    latest.7 as value_format,
    latest.8 as chart_hint,
    latest.9 as display_order,
    latest.10 as definition,
    latest.11 as status,
    latest.12 as target_source,
    latest.13 as value_source,
    latest.14 as detail_page,
    latest.16 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code,
           argMax(tuple(kpi_num, trimBoth(kpi_name), trimBoth(short_label), trimBoth(objective_code), trimBoth(kpi_type), trimBoth(direction), trimBoth(value_format), trimBoth(chart_hint), display_order, trimBoth(definition), trimBoth(status), trimBoth(target_source), trimBoth(value_source), trimBoth(detail_page), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_kpi') }}
    group by kpi_code
)
where latest.15 = 0
