{{ config(order_by='(branch_id, encounter_type, source_id)') }}

with op as (
    select
        branch_id                                           as branch_id,
        'OP'                                                as encounter_type,
        appointment_id                                      as source_id,
        patient_id                                          as patient_id,
        episode_no                                          as episode_no,
        coalesce(starts_at, arrived_at, toDateTime(slot_date, 'Asia/Riyadh')) as encounter_at,
        arrived_at                                          as arrived_at,
        seen_at                                             as seen_at,
        completed_at                                        as completed_at,
        cast(null as Nullable(DateTime('Asia/Riyadh')))     as triaged_at,
        booked_at                                           as booked_at,
        work_entity                                         as work_entity,
        booked_staff_id                                     as booked_staff_id,
        treating_staff_id                                   as treating_staff_id,
        outcome_code                                        as outcome_code,
        cast(null as Nullable(Int64))                       as er_priority,
        toUInt8(arrived_at is not null)                     as is_arrived,
        toUInt8(seen_at is not null)                        as is_seen,
        is_walk_in                                          as is_walk_in,
        toUInt8(ifNull(new_followup_flag, '') = 'F')        as is_follow_up,
        is_virtual                                          as is_virtual,
        is_online_booking                                   as is_online_booking,
        booked_from                                         as booked_from
    from {{ ref('stg_oasis__appointments') }}
    where patient_id is not null
),

er as (
    select
        branch_id, 'ER', er_visit_id, patient_id, episode_no,
        arrived_at, arrived_at, treatment_started_at, completed_at, triaged_at,
        cast(null as Nullable(DateTime('Asia/Riyadh'))),
        work_entity, cast(null as Nullable(String)), treating_staff_id, outcome_code, priority,
        toUInt8(1), toUInt8(treatment_started_at is not null), toUInt8(0), toUInt8(0), toUInt8(0), toUInt8(0),
        cast(null as Nullable(String))
    from {{ ref('stg_oasis__er_visits') }}
),

ip as (
    select
        branch_id, 'IP', admission_no, patient_id, episode_no,
        admitted_at, admitted_at, seen_at, physical_discharge_at,
        cast(null as Nullable(DateTime('Asia/Riyadh'))), cast(null as Nullable(DateTime('Asia/Riyadh'))),
        first_work_entity, request_consultant_staff_id, treating_staff_id,
        cast(null as Nullable(Int64)), cast(null as Nullable(Int64)),
        toUInt8(1), toUInt8(1), toUInt8(0), toUInt8(0), toUInt8(0), toUInt8(0),
        cast(null as Nullable(String))
    from {{ ref('int_admission') }}
),

unioned as (
    select * from op
    union all
    select * from er
    union all
    select * from ip
),

decoded as (
    select
        u.branch_id as branch_id,
        u.encounter_type as encounter_type,
        u.source_id as source_id,
        u.patient_id as patient_id,
        u.episode_no as episode_no,
        u.encounter_at as encounter_at,
        u.arrived_at as arrived_at,
        u.seen_at as seen_at,
        u.completed_at as completed_at,
        u.triaged_at as triaged_at,
        u.booked_at as booked_at,
        u.work_entity as work_entity,
        u.booked_staff_id as booked_staff_id,
        u.treating_staff_id as treating_staff_id,
        u.outcome_code as outcome_code,
        u.er_priority as er_priority,
        u.is_arrived as is_arrived,
        u.is_seen as is_seen,
        u.is_walk_in as is_walk_in,
        u.is_follow_up as is_follow_up,
        u.is_virtual as is_virtual,
        u.is_online_booking as is_online_booking,
        u.booked_from as booked_from,
        if(u.outcome_code is null, 'Not recorded', {{ hnh_outcome_group('d.description_upper') }}) as outcome_group,
        if(ep.care_type is null or ep.care_type = 'Unknown', u.encounter_type, ep.care_type)       as care_type,
        coalesce(u.booked_staff_id, ep.consultant_staff_id)   as resolved_booked_staff_id,
        ifNull(ep.purchaser_code, toInt64(9999))              as purchaser_code,
        ep.eligibility_type                                   as eligibility_type,
        toUInt8(ifNull(ep.is_first_episode, 0))               as is_first_episode
    from unioned as u
    left join {{ ref('int_code_decode') }} as d
        on d.branch_id = u.branch_id and d.code = u.outcome_code
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = u.branch_id and ep.patient_id = u.patient_id and ep.episode_no = u.episode_no
),

flagged as (
    select *, toUInt8(outcome_group in ('Cancelled', 'Rescheduled')) as is_cancelled
    from decoded
),

arrival_days as (
    -- Days on which the patient arrived anywhere in the branch (clinic or ER).
    select distinct branch_id, assumeNotNull(patient_id) as patient_id, toDate(arrived_at) as arrival_date
    from flagged
    where encounter_type in ('OP', 'ER') and is_arrived = 1 and arrived_at is not null and patient_id is not null
),

monthly as (
    select
        branch_id, assumeNotNull(patient_id) as patient_id,
        toRelativeMonthNum(assumeNotNull(encounter_at)) as month_num,
        countIf(encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0) as arrived_n
    from flagged
    where patient_id is not null and encounter_at is not null
    group by branch_id, patient_id, month_num
),

monthly_prior as (
    select
        branch_id, patient_id, month_num,
        sum(arrived_n) over (partition by branch_id, patient_id order by month_num
                             range between 4 preceding and 1 preceding) as prior_encounters_4m
    from monthly
)

select
    f.branch_id                         as branch_id,
    f.encounter_type                    as encounter_type,
    f.source_id                         as source_id,
    f.patient_id                        as patient_id,
    f.episode_no                        as episode_no,
    f.encounter_at                      as encounter_at,
    f.arrived_at                        as arrived_at,
    f.seen_at                           as seen_at,
    f.completed_at                      as completed_at,
    f.triaged_at                        as triaged_at,
    f.booked_at                         as booked_at,
    f.work_entity                       as work_entity,
    f.resolved_booked_staff_id          as booked_staff_id,
    f.treating_staff_id                 as treating_staff_id,
    f.outcome_code                      as outcome_code,
    f.er_priority                       as er_priority,
    f.care_type                         as care_type,
    f.purchaser_code                    as purchaser_code,
    f.eligibility_type                  as eligibility_type,
    f.outcome_group                     as outcome_group,
    f.is_arrived                        as is_arrived,
    f.is_seen                           as is_seen,
    f.is_cancelled                      as is_cancelled,
    toUInt8(f.encounter_type = 'OP' and f.is_walk_in = 0 and f.is_cancelled = 0 and f.is_arrived = 0
            and ifNull(toDate(f.encounter_at) < today(), 0) and ad.patient_id is null) as is_no_show,
    f.is_walk_in                        as is_walk_in,
    f.is_follow_up                      as is_follow_up,
    f.is_virtual                        as is_virtual,
    f.is_online_booking                 as is_online_booking,
    f.booked_from                       as booked_from,
    f.is_first_episode                  as is_first_episode,
    {{ hnh_visit_type('f.is_first_episode', 'f.is_follow_up') }} as visit_type,
    toUInt32(ifNull(mp.prior_encounters_4m, 0))                  as prior_encounters_4m,
    toUInt8(ifNull(mp.prior_encounters_4m, 0) > 0)               as is_returning,
    if(f.encounter_type = 'IP', null, {{ hnh_minutes_between('f.arrived_at', 'f.seen_at') }})      as wait_minutes,
    if(f.encounter_type = 'IP', null, dateDiff('minute', f.arrived_at, f.seen_at))                 as wait_minutes_raw,
    {{ hnh_minutes_between('f.arrived_at', 'f.triaged_at') }}                                      as door_to_triage_minutes,
    dateDiff('minute', f.arrived_at, f.triaged_at)                                                 as door_to_triage_minutes_raw,
    if(f.encounter_type = 'IP', null, {{ hnh_minutes_between('f.seen_at', 'f.completed_at') }})    as service_minutes,
    if(f.encounter_type = 'IP', null, dateDiff('minute', f.seen_at, f.completed_at))               as service_minutes_raw,
    if(f.encounter_type = 'ER' and dateDiff('minute', f.arrived_at, f.completed_at) between 0 and 10080,
       dateDiff('minute', f.arrived_at, f.completed_at), null)                                     as er_los_minutes,
    if(f.encounter_type = 'ER', dateDiff('minute', f.arrived_at, f.completed_at), null)            as er_los_minutes_raw,
    if(f.encounter_type = 'OP' and dateDiff('day', f.booked_at, f.encounter_at) >= 0,
       dateDiff('day', f.booked_at, f.encounter_at), null)                                         as booking_lead_days,
    toUInt8(f.encounter_type in ('OP', 'ER') and f.patient_id is not null and f.episode_no is not null
            and ifNull(f.outcome_code, 500) not in (93, 94, 106, 107))                             as legacy_in_op_census,
    toUInt8(ifNull(f.outcome_code, 0) in (93, 94, 107, 108))                                       as legacy_is_cancelled_outpatient_model
from flagged as f
left join arrival_days as ad
    on ad.branch_id = f.branch_id and ad.patient_id = f.patient_id and ad.arrival_date = toDate(f.encounter_at)
left join monthly_prior as mp
    on mp.branch_id = f.branch_id and mp.patient_id = f.patient_id
   and mp.month_num = toRelativeMonthNum(assumeNotNull(f.encounter_at))
{{ hnh_settings() }}
