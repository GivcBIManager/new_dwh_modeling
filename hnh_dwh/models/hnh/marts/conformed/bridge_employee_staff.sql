{{ config(order_by='employee_key') }}

-- Fusion worker number = Oasis staff id within the employee's branch (spec W1, H4). Head Office has no Oasis staff.
select
    {{ hnh_surrogate_key(['e.person_id']) }}    as employee_key,
    s.staff_key                                 as staff_key,
    e.branch_key                                as branch_key,
    assumeNotNull(e.worker_number)              as worker_number,
    'worker_number'                             as match_method
from {{ ref('int_employee_period') }} as e
inner join (select staff_key, branch_key, staff_id from {{ ref('dim_staff') }} where staff_id is not null) as s
    on s.branch_key = e.branch_key and s.staff_id = e.worker_number
where e.worker_number is not null and e.branch_key between 1 and 8
