{{ config(order_by='(branch_key, start_date, staff_vacation_id)') }}

-- Oasis absences (staff_vacations) for the absence facts (user request 2026-11-05: absence from Oasis too; the
-- branches moved their absence recording from Oasis to Fusion one by one during 2026). From hnh_history_start_date:
--   dates   = from_date to to_date; without a to_date, from_date plus the days rounded up (days holds odd values on
--             a few one-day rows, such as 300 days on a settlement, so the dates win);
--   counted = every entry but status O; the type is the branch's vacation type (dim_absence_type, source Oasis);
--   staff   = dim_staff of the branch, employee = the Fusion employee of the staff (bridge), else -1.
-- An entry that overlaps a counted day-unit Fusion absence of the same employee is left out: Fusion has it.

with oasis as (
    select v.branch_id as branch_id, v.staff_vacation_id as staff_vacation_id, v.staff_id as staff_id,
           v.vacation_type_id as vacation_type_id, assumeNotNull(v.from_date) as start_date,
           greatest(assumeNotNull(v.from_date),
                    coalesce(v.to_date, assumeNotNull(v.from_date) + toInt32(greatest(1, ceil(v.days))) - 1)) as end_date
    from {{ ref('stg_oasis__staff_vacations') }} as v
    where v.from_date >= toDate32('{{ var("hnh_history_start_date") }}') and ifNull(v.status, '') != 'O'
),

keyed as (
    select o.branch_id as branch_id, o.staff_vacation_id as staff_vacation_id, o.start_date as start_date,
           o.end_date as end_date,
           ifNull(s.staff_key, toInt64(-1)) as staff_key,
           ifNull(b.employee_key, toInt64(-1)) as employee_key,
           {{ hnh_surrogate_key(["'oasis'", 'o.branch_id', 'o.vacation_type_id']) }} as absence_type_key
    from oasis as o
    left join (select staff_key, toUInt8(branch_key) as branch_key, staff_id from {{ ref('dim_staff') }}
               where staff_id is not null) as s
        on s.branch_key = o.branch_id and s.staff_id = o.staff_id
    left join (select staff_key, min(employee_key) as employee_key from {{ ref('bridge_employee_staff') }}
               group by staff_key) as b
        on b.staff_key = s.staff_key
    where dateDiff('day', o.start_date, o.end_date) <= 366
    {{ hnh_settings() }}
),

fusion as (
    select e.employee_key as employee_key, assumeNotNull(a.start_date) as start_date, assumeNotNull(a.end_date) as end_date
    from {{ ref('stg_fusion__absence_entries') }} as a
    inner join (select employee_key, person_id from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = a.person_id
    where {{ hnh_is_counted_absence('a.absence_status_code', 'a.approval_status_code') }} = 1
      and ifNull(a.duration_uom, '') = 'C' and a.start_date is not null and a.end_date is not null
),

covered as (
    select distinct k.branch_id as branch_id, k.staff_vacation_id as staff_vacation_id
    from keyed as k
    inner join fusion as f on f.employee_key = k.employee_key
    where k.employee_key != -1 and f.start_date <= k.end_date and f.end_date >= k.start_date
)

select
    k.branch_id                                               as branch_id,
    k.staff_vacation_id                                       as staff_vacation_id,
    toUInt8(k.branch_id)                                      as branch_key,
    k.employee_key                                            as employee_key,
    k.staff_key                                               as staff_key,
    k.absence_type_key                                        as absence_type_key,
    k.start_date                                              as start_date,
    k.end_date                                                as end_date,
    toFloat64(dateDiff('day', k.start_date, k.end_date) + 1)  as absence_days
from keyed as k
where (k.branch_id, k.staff_vacation_id) not in (select branch_id, staff_vacation_id from covered)
