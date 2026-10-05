{{ config(order_by='(branch_key, month_start)') }}

-- New measures follow the KPI default (non-inpatient); legacy measures use the old report's scope.
-- Scope units leave out unit outliers (ordered in ml or mg, delivered in packs); they are counted apart.
select
    branch_key,
    toStartOfMonth(YYYYMMDDToDate(toUInt32(order_date_key)))                         as month_start,
    countIf(legacy_in_scope = 1)                                                     as legacy_lines,
    countIf(legacy_is_lost = 1)                                                      as legacy_lost,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0)                               as lines,
    countIf(is_lost = 1 and is_inpatient = 0)                                        as lost,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0
            and fulfilment_status = 'Delivered by alternative')                      as delivered_by_alternative,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0
            and fulfilment_status = 'Delivered by substitute')                       as delivered_by_substitute,
    countIf(is_excluded_package = 1 and is_inpatient = 0)                            as excluded_package_lines,
    sumIf(units_ordered, is_in_leak_scope = 1 and is_inpatient = 0 and is_unit_outlier = 0) as scope_units_ordered,
    sumIf(units_delivered, is_in_leak_scope = 1 and is_inpatient = 0 and is_unit_outlier = 0) as scope_units_delivered,
    avgIf(unit_fulfilment_ratio, is_in_leak_scope = 1 and is_inpatient = 0)         as avg_unit_fulfilment_ratio,
    countIf(is_in_leak_scope = 1 and is_inpatient = 0 and is_unit_outlier = 1)       as unit_outlier_lines
from {{ ref('fact_order_line') }}
group by branch_key, month_start
