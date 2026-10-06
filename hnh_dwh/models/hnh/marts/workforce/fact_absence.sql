{{ config(order_by='(branch_key, start_date_key, absence_key)') }}

-- One Fusion absence entry (spec 6.5). Branch from the entry's legal employer, else the person's current branch.
select
    {{ hnh_surrogate_key(['a.absence_entry_id']) }}                                    as absence_key,
    if(ifNull(lb.branch_key, 0) = 0, e.branch_key, assumeNotNull(lb.branch_key))      as branch_key,
    e.employee_key                                                                      as employee_key,
    e.staff_key                                                                         as staff_key,
    ifNull(t.absence_type_key, toInt64(-1))                                             as absence_type_key,
    ifNull({{ hnh_date_key_in_range('a.start_date') }}, 0)                              as start_date_key,
    {{ hnh_date_key_in_range('a.end_date') }}                                           as end_date_key,
    {{ hnh_absence_status('a.absence_status_code', 'a.approval_status_code') }}         as absence_status,
    {{ hnh_is_counted_absence('a.absence_status_code', 'a.approval_status_code') }}     as is_counted,
    a.duration_uom                                                                      as duration_uom,
    if(ifNull(a.duration_uom, '') = 'C', ifNull(a.duration, 0), 0)                       as absence_days,
    if(ifNull(a.duration_uom, '') = 'H', ifNull(a.duration, 0), 0)                       as absence_hours,
    now()                                                                               as _loaded_at
from {{ ref('stg_fusion__absence_entries') }} as a
inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
    on e.person_id = a.person_id
left join (select absence_type_key, absence_type_id from {{ ref('hnh_dim_absence_type') }} where absence_type_id is not null) as t
    on t.absence_type_id = a.absence_type_id
left join {{ ref('int_legal_employer_branch') }} as lb on lb.legal_employer_id = a.legal_employer_id
{{ hnh_settings() }}
