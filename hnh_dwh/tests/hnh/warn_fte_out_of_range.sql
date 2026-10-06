{{ config(severity='warn') }}
-- FTE work measures outside (0, 1.5] (replaced by 1 in the snapshot).
select unit, count() as measures, min(value) as min_value, max(value) as max_value
from {{ ref('stg_fusion__work_measures') }}
where unit = 'FTE' and not (value > 0 and value <= 1.5)
group by unit
