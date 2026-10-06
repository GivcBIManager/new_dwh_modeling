{{ config(severity='warn') }}
-- Oasis staff records linked to more than one Fusion employee (rehires or reused worker numbers).
select staff_key, branch_key, count() as employees
from {{ ref('bridge_employee_staff') }}
group by staff_key, branch_key
having count() > 1
