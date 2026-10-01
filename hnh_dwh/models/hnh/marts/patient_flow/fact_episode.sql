{{ config(order_by='(branch_key, start_date_key, episode_key)') }}

with encounter_counts as (
    select
        branch_id, assumeNotNull(patient_id) as patient_id, assumeNotNull(episode_no) as episode_no,
        countIf(encounter_type = 'OP') as op_encounters,
        countIf(encounter_type = 'ER') as er_encounters,
        countIf(encounter_type = 'IP') as ip_encounters,
        toUInt8(countIf(encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0 and is_follow_up = 0) > 0) as has_arrived_non_follow_up_encounter
    from {{ ref('int_encounter') }}
    where patient_id is not null and episode_no is not null
    group by branch_id, patient_id, episode_no
),

e as (
    select
        ep.*,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.patient_id', 'ep.episode_no']) }}  as episode_key,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.patient_id']) }}                   as patient_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.consultant_staff_id']) }}          as consultant_staff_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.work_entity']) }}                  as department_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.purchaser_code']) }}               as payer_key_raw,
        {{ hnh_surrogate_key(['ep.branch_id', 'ep.eligibility_type']) }}             as eligibility_type_key_raw
    from {{ ref('int_episode') }} as ep
    where ep.started_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
)

select
    e.episode_key                                        as episode_key,
    e.branch_id                                          as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(e.started_at)))     as start_date_key,
    {{ hnh_date_key_in_range('e.ended_at') }}                     as end_date_key,
    ifNull(dp.patient_key, toInt64(-1))                  as patient_key,
    ifNull(ds.staff_key, toInt64(-1))                    as consultant_staff_key,
    ifNull(dd.department_key, toInt64(-1))               as department_key,
    ifNull(dpy.payer_key, toInt64(-1))                   as payer_key,
    {{ hnh_care_type_key('e.care_type') }}               as care_type_key,
    ifNull(det.eligibility_type_key, toInt64(-1))        as eligibility_type_key,
    e.episode_no                                         as episode_no,
    e.episode_seq                                        as episode_seq,
    e.is_first_episode                                   as is_first_episode,
    e.previous_care_type                                 as previous_care_type,
    e.policy_code                                        as policy_code,
    e.contract_no                                        as contract_no,
    toUInt8(rp.policy_code is not null)                  as is_referral_policy,
    toUInt32(ifNull(c.op_encounters, 0))                 as op_encounters,
    toUInt32(ifNull(c.er_encounters, 0))                 as er_encounters,
    toUInt32(ifNull(c.ip_encounters, 0))                 as ip_encounters,
    toUInt8(ifNull(c.has_arrived_non_follow_up_encounter, 0)) as has_arrived_non_follow_up_encounter,
    e.legacy_care_type                                   as legacy_care_type,
    e.legacy_purchaser_code                              as legacy_purchaser_code,
    now()                                                as _loaded_at
from e
left join encounter_counts as c
    on c.branch_id = e.branch_id and c.patient_id = e.patient_id and c.episode_no = e.episode_no
left join (select distinct branch_id, policy_code from {{ ref('stg_ref__referral_policy') }}) as rp
    on rp.branch_id = e.branch_id and rp.policy_code = e.policy_code
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = e.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = e.consultant_staff_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = e.department_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = e.payer_key_raw
left join (select eligibility_type_key from {{ ref('dim_eligibility_type') }}) as det on det.eligibility_type_key = e.eligibility_type_key_raw
{{ hnh_settings() }}
