{{ config(order_by='(bsc_kpi_key, branch_key, month_date_key)') }}

-- Monthly KPI values entered by the BI manager (bsc ssas spec 6.2): numerator and denominator per hospital and month.
-- A denominator of 0 means the KPI measure supplies its own denominator (complaints over visits).
select
    toInt64(bitShiftRight(cityHash64(concat(kpi_code, '|')), 1))  as bsc_kpi_key,
    toUInt8(branch_id)                                            as branch_key,
    toInt32(toUInt32(year) * 10000 + toUInt32(month) * 100 + 1)   as month_date_key,
    toFloat64(numerator)                                          as numerator,
    toFloat64(denominator)                                        as denominator,
    note                                                          as note
from {{ ref('stg_ref__bsc_manual_value') }}
where branch_id between 1 and 8 and month between 1 and 12
