{{ config(severity='warn') }}

-- A target of a '%' finance KPI is stored as a fraction (0.21 = 21%). A value above 5 in absolute terms is most likely
-- a percentage typed as a number (21), which would make the KPI look 100 times off target.
select
    t.kpi_code,
    t.branch_id,
    t.year,
    t.target_value
from {{ ref('dim_finance_target') }} as t
inner join {{ ref('dim_finance_kpi') }} as k on k.kpi_code = t.kpi_code
where k.unit = '%'
  and abs(t.target_value) > 5
