{{ config(order_by='(branch_key, date_key, absence_day_key)') }}

-- One row per calendar day of a counted, day-unit absence (spec 6.5); entries longer than 366 days are skipped.
with counted as (
    select a.absence_entry_id as absence_entry_id, assumeNotNull(a.start_date) as start_date, assumeNotNull(a.end_date) as end_date,
           if(ifNull(lb.branch_key, 0) = 0, e.branch_key, assumeNotNull(lb.branch_key)) as branch_key,
           e.employee_key as employee_key, e.staff_key as staff_key, ifNull(t.absence_type_key, toInt64(-1)) as absence_type_key
    from {{ ref('stg_fusion__absence_entries') }} as a
    inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = a.person_id
    left join (select absence_type_key, absence_type_id from {{ ref('hnh_dim_absence_type') }} where absence_type_id is not null) as t
        on t.absence_type_id = a.absence_type_id
    left join {{ ref('int_legal_employer_branch') }} as lb on lb.legal_employer_id = a.legal_employer_id
    where {{ hnh_is_counted_absence('a.absence_status_code', 'a.approval_status_code') }} = 1
      and ifNull(a.duration_uom, '') = 'C' and a.start_date is not null and a.end_date is not null
      and a.end_date >= a.start_date and dateDiff('day', a.start_date, a.end_date) <= 366
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['absence_entry_id', 'day']) }}    as absence_day_key,
    branch_key, employee_key, staff_key, absence_type_key,
    {{ hnh_date_key('day') }}                               as date_key,
    toUInt8(1)                                              as absence_days,
    now()                                                   as _loaded_at
from counted
array join arrayMap(i -> start_date + i, range(toUInt32(dateDiff('day', start_date, end_date) + 1))) as day
