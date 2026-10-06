{{ config(severity='warn') }}
-- Counted day-unit absences with zero or missing days.
select branch_key, count() as entries
from {{ ref('fact_absence') }}
where is_counted = 1 and duration_uom = 'C' and absence_days <= 0
group by branch_key
