{{ config(order_by='hr_kpi_key') }}

-- HR dashboard KPI and metric catalogue: the latest config rows of map_hr_kpi. bsc_kpi_key is the key of the
-- matching dim_bsc_kpi row (same hash), or -1 when the KPI has no BSC code.
select
    toInt64(bitShiftRight(cityHash64(concat(k.kpi_code, '|')), 1))  as hr_kpi_key,
    k.kpi_code                                                      as kpi_code,
    k.kind                                                          as kind,
    k.kpi_name                                                      as kpi_name,
    k.short_label                                                   as short_label,
    k.area                                                          as area,
    k.definition                                                    as definition,
    k.formula                                                       as formula,
    k.source_system                                                 as source_system,
    k.grain                                                         as grain,
    k.caveats                                                       as caveats,
    k.direction                                                     as direction,
    k.value_format                                                  as value_format,
    k.display_order                                                 as display_order,
    k.measure_name                                                  as measure_name,
    k.bsc_kpi_code                                                  as bsc_kpi_code,
    k.target_source                                                 as target_source,
    k.needs_pay                                                     as needs_pay,
    k.is_home_tile                                                  as is_home_tile,
    k.status                                                        as status,
    k.last_changed_at                                               as last_changed_at,
    if(k.bsc_kpi_code = '', toInt64(-1),
       toInt64(bitShiftRight(cityHash64(concat(k.bsc_kpi_code, '|')), 1)))  as bsc_kpi_key
from {{ ref('stg_ref__hr_kpi') }} as k
{{ hnh_settings() }}
