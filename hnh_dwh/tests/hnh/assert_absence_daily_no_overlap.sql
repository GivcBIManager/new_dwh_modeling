{{ config(severity='warn') }}

-- An employee should have at most one counted absence day row per calendar day (duplicated source entries overlap).
-- Fusion rows only: Oasis days count once per staff and day, and an Oasis entry that overlaps Fusion is left out.
select employee_key, date_key, count() as day_rows
from {{ ref('fact_absence_daily') }}
where source = 'Fusion'
group by employee_key, date_key
having count() > 1
