{{ config(order_by='(branch_key, encounter_date_key, encounter_key)') }}

with e as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'encounter_type', 'source_id']) }}   as encounter_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}      as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                    as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'booked_staff_id']) }}               as booked_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'treating_staff_id']) }}             as treating_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}                   as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }}                as payer_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'eligibility_type']) }}              as eligibility_type_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'outcome_code']) }}                  as outcome_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'er_priority']) }}                   as er_priority_key_raw
    from {{ ref('int_encounter') }}
    where encounter_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
)

select
    e.encounter_key                                          as encounter_key,
    e.branch_id                                              as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(e.encounter_at)))       as encounter_date_key,
    {{ hnh_time_key('e.encounter_at') }}                     as encounter_time_key,
    {{ hnh_date_key_in_range('e.arrived_at') }}                       as arrival_date_key,
    {{ hnh_time_key('e.arrived_at') }}                       as arrival_time_key,
    {{ hnh_date_key_in_range('e.booked_at') }}                        as booking_date_key,
    e.episode_key                                            as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                      as patient_key,
    ifNull(dbs.staff_key, toInt64(-1))                       as booked_staff_key,
    ifNull(dts.staff_key, toInt64(-1))                       as treating_staff_key,
    ifNull(dd.department_key, toInt64(-1))                   as department_key,
    ifNull(dpy.payer_key, toInt64(-1))                       as payer_key,
    {{ hnh_care_type_key('e.care_type') }}                   as care_type_key,
    ifNull(det.eligibility_type_key, toInt64(-1))            as eligibility_type_key,
    ifNull(dout.outcome_key, toInt64(-1))                    as outcome_key,
    ifNull(dpr.er_priority_key, toInt64(-1))                 as er_priority_key,
    e.encounter_type                                         as encounter_type,
    e.source_id                                              as source_id,
    e.visit_type                                             as visit_type,
    e.booked_from                                            as booked_from,
    e.is_arrived, e.is_seen, e.is_cancelled, e.is_no_show, e.is_walk_in, e.is_follow_up,
    e.is_virtual, e.is_online_booking, e.is_first_episode, e.is_returning,
    e.prior_encounters_4m,
    e.wait_minutes, e.wait_minutes_raw, e.door_to_triage_minutes, e.door_to_triage_minutes_raw,
    e.service_minutes, e.service_minutes_raw, e.er_los_minutes, e.er_los_minutes_raw, e.booking_lead_days,
    e.legacy_in_op_census, e.legacy_is_cancelled_outpatient_model,
    now()                                                    as _loaded_at
from e
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = e.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dbs on dbs.staff_key = e.booked_staff_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dts on dts.staff_key = e.treating_staff_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = e.department_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = e.payer_key_raw
left join (select eligibility_type_key from {{ ref('dim_eligibility_type') }}) as det on det.eligibility_type_key = e.eligibility_type_key_raw
left join (select outcome_key from {{ ref('dim_appointment_outcome') }}) as dout on dout.outcome_key = e.outcome_key_raw
left join (select er_priority_key from {{ ref('dim_er_priority') }}) as dpr on dpr.er_priority_key = e.er_priority_key_raw
{{ hnh_settings() }}
