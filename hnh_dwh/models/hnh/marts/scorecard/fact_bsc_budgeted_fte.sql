{{ config(order_by='(branch_key, year_date_key)') }}

-- Budgeted FTE per hospital and year, entered by the BI manager: the job vacancy rate denominator (bsc ssas spec,
-- Appendix B, KPI 47). The year is keyed on 1 January.
select
    toUInt8(branch_id)                                  as branch_key,
    toInt32(toUInt32(year) * 10000 + 101)               as year_date_key,
    toFloat64(budgeted_fte)                             as budgeted_fte
from {{ ref('stg_ref__bsc_budgeted_fte') }}
where branch_id between 1 and 8
