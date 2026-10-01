{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['branch_key', 'date_key'],
    order_by='(branch_key, date_key, department_key, staff_key)'
) }}

{% set first_date = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set last_date = "(select max(date_day) from " ~ ref('dim_date') ~ ")" %}

with slots as (
    select
        branch_id, appointment_id, patient_id, work_entity, booked_staff_id, break_code, slot_minutes,
        assumeNotNull(ifNull(slot_date, toDate(starts_at))) as slot_day,
        updated_at
    from {{ ref('stg_oasis__appointments') }}
    where ifNull(slot_date, toDate(starts_at)) between {{ first_date }} and {{ last_date }}
),

{% if is_incremental() %}
changed_days as (
    -- Rebuild whole days: every day that has a slot changed since the last load.
    select distinct branch_id, slot_day
    from slots
    where updated_at > (select max(_loaded_at) - toIntervalDay(1) from {{ this }})
),
{% endif %}

in_scope as (
    select s.*
    from slots as s
    {% if is_incremental() %}
    inner join changed_days as c on c.branch_id = s.branch_id and c.slot_day = s.slot_day
    {% endif %}
),

booked as (
    select branch_id, source_id as appointment_id, is_arrived, is_cancelled, is_no_show, is_walk_in, outcome_group
    from {{ ref('int_encounter') }}
    where encounter_type = 'OP'
),

per_day as (
    select
        s.branch_id         as branch_id,
        s.slot_day          as slot_day,
        s.work_entity       as work_entity,
        s.booked_staff_id   as booked_staff_id,
        count()                                                              as slots_total,
        countIf(s.patient_id is not null)                                    as slots_booked,
        countIf(b.is_arrived = 1 and b.is_cancelled = 0)                     as slots_attended,
        countIf(b.is_no_show = 1)                                            as slots_no_show,
        countIf(b.outcome_group = 'Cancelled')                               as slots_cancelled,
        countIf(b.outcome_group = 'Rescheduled')                             as slots_rescheduled,
        countIf(b.is_walk_in = 1)                                            as slots_walk_in,
        countIf(s.break_code is not null)                                    as break_slots,
        sum(ifNull(s.slot_minutes, 0))                                       as scheduled_minutes
    from in_scope as s
    left join booked as b on b.branch_id = s.branch_id and b.appointment_id = s.appointment_id
    group by s.branch_id, s.slot_day, s.work_entity, s.booked_staff_id
),

keyed as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}      as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'booked_staff_id']) }}  as staff_key_raw
    from per_day
)

select
    k.branch_id                                  as branch_key,
    toInt32(toYYYYMMDD(k.slot_day))              as date_key,
    ifNull(dd.department_key, toInt64(-1))       as department_key,
    ifNull(ds.staff_key, toInt64(-1))            as staff_key,
    sum(k.slots_total)                           as slots_total,
    sum(k.slots_booked)                          as slots_booked,
    sum(k.slots_attended)                        as slots_attended,
    sum(k.slots_no_show)                         as slots_no_show,
    sum(k.slots_cancelled)                       as slots_cancelled,
    sum(k.slots_rescheduled)                     as slots_rescheduled,
    sum(k.slots_walk_in)                         as slots_walk_in,
    sum(k.break_slots)                           as break_slots,
    sum(k.scheduled_minutes)                     as scheduled_minutes,
    -- Old capacity rule: clinic hours x slots per hour, for a doctor-day with at least one attended visit.
    toFloat64(if(sum(k.slots_attended) > 0,
       ifNull(any(ds.clinic_duration_hours) * any(ds.slots_per_hour), 0), 0)) as legacy_capacity_slots,
    now()                                        as _loaded_at
from keyed as k
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = k.department_key_raw
left join (select staff_key, clinic_duration_hours, slots_per_hour from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.staff_key_raw
group by k.branch_id, k.slot_day, department_key, staff_key
{{ hnh_settings() }}
