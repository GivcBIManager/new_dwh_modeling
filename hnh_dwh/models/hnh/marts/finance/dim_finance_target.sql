{{ config(order_by='(kpi_code, branch_id, year)') }}

-- Finance KPI targets of the BI manager's config table (map_finance_target through stg_ref__finance_target), one row
-- per KPI, branch and year. branch_id 0 = all hospitals. A hospital's own row and the branch 0 row both stay here: the
-- measure takes the hospital row first and the branch 0 row where a hospital has none. watch_pct is the share below
-- target that still counts as Watch (0.05 where the config left 0).
select
    kpi_code,
    toUInt8(branch_id)  as branch_id,
    toUInt16(year)      as year,
    toFloat64(target_value) as target_value,
    toFloat64(watch_pct)    as watch_pct
from {{ ref('stg_ref__finance_target') }}
{{ hnh_settings() }}
