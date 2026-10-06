{{ config(severity='warn') }}

-- An employee should have at most one counted absence day row per calendar day (duplicated source entries overlap).
select employee_key, date_key, count() as day_rows
from {{ ref('fact_absence_daily') }}
group by employee_key, date_key
having count() > 1
