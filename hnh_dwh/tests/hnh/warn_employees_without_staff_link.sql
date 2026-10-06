{{ config(severity='warn') }}
-- Current hospital employees whose worker number matches no Oasis staff in their branch.
select branch_key, count() as employees
from {{ ref('hnh_dim_employee') }}
where employee_key != -1 and staff_key = -1 and branch_key between 1 and 8 and worker_type_code = 'EMP' and is_terminated = 0
group by branch_key
