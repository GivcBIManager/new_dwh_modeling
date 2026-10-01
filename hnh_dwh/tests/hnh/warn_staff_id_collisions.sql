{{ config(severity='warn') }}

select
    branch_id,
    {{ hnh_code('staff_id') }}  as staff_id_normalised,
    groupArray(staff_id)        as raw_ids
from {{ source('oasis', 'staff_master_data') }} final
group by branch_id, staff_id_normalised
having uniqExact(staff_id) > 1
