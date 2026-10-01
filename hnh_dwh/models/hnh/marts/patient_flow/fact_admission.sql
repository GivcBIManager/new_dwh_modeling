{{ config(order_by='(branch_key, admit_date_key, admission_key)') }}

{% set start_ts = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}

with a as (
    select
        adm.*,
        ep.purchaser_code                                                           as purchaser_code,
        coalesce(adm.request_consultant_staff_id, ep.consultant_staff_id)           as consultant_staff_id,
        if(ep.care_type is null or ep.care_type = 'Unknown', 'IP', ep.care_type)    as care_type
    from {{ ref('int_admission') }} as adm
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = adm.branch_id and ep.patient_id = adm.patient_id and ep.episode_no = adm.episode_no
    where adm.admitted_at >= {{ start_ts }}
       or (adm.admitted_at < {{ start_ts }} and (adm.physical_discharge_at is null or adm.physical_discharge_at >= {{ start_ts }}))
),

k as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'admission_no']) }}                  as admission_key,
        {{ hnh_surrogate_key(['branch_id', "'IP'", 'admission_no']) }}          as encounter_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}      as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                    as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'consultant_staff_id']) }}           as consultant_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'treating_staff_id']) }}             as treating_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'first_work_entity']) }}             as first_department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'last_work_entity']) }}              as last_department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'last_bed_location']) }}             as last_bed_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'ifNull(purchaser_code, toInt64(9999))']) }} as payer_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'outcome_code']) }}                  as discharge_outcome_key_raw
    from a
)

select
    k.admission_key                                          as admission_key,
    k.encounter_key                                          as encounter_key,
    k.branch_id                                              as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(k.admitted_at)))        as admit_date_key,
    {{ hnh_time_key('k.admitted_at') }}                      as admit_time_key,
    {{ hnh_date_key_in_range('k.clinical_discharge_at') }}            as clinical_discharge_date_key,
    {{ hnh_date_key_in_range('k.physical_discharge_at') }}            as physical_discharge_date_key,
    {{ hnh_date_key_in_range('k.financial_discharge_at') }}           as financial_discharge_date_key,
    k.episode_key                                            as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                      as patient_key,
    ifNull(dcs.staff_key, toInt64(-1))                       as consultant_staff_key,
    ifNull(dts.staff_key, toInt64(-1))                       as treating_staff_key,
    ifNull(dfd.department_key, toInt64(-1))                  as first_department_key,
    ifNull(dld.department_key, toInt64(-1))                  as last_department_key,
    ifNull(db.bed_key, toInt64(-1))                          as last_bed_key,
    ifNull(dpy.payer_key, toInt64(-1))                       as payer_key,
    {{ hnh_care_type_key('k.care_type') }}                   as care_type_key,
    {{ hnh_admission_source_key('k.admission_source') }}     as admission_source_key,
    ifNull(ddo.discharge_outcome_key, toInt64(-1))           as discharge_outcome_key,
    k.admission_no                                           as admission_no,
    k.admitted_at                                            as admitted_at,
    k.physical_discharge_at                                  as physical_discharge_at,
    k.request_planned_admit_at                               as planned_admit_at,
    k.request_admission_type                                 as admission_type,
    k.referred_type                                          as referred_type,
    k.discharge_outcome_group                                as discharge_outcome_group,
    k.los_hours, k.los_days, k.los_days_to_date,
    k.is_open, k.is_short_stay, k.is_wrong_admission_outcome, k.is_countable,
    k.is_ltc, k.is_ltc_to_date,
    k.has_bed, k.had_critical_bed, k.critical_bed_hours,
    k.days_since_previous_discharge, k.is_readmission_30d, k.is_icu_readmission_48h,
    k.is_died, k.is_dama,
    k.legacy_is_wrong_admission, k.legacy_is_ltc, k.legacy_days_since_previous_admission, k.legacy_in_vw_inpatients,
    now()                                                    as _loaded_at
from k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dcs on dcs.staff_key = k.consultant_staff_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dts on dts.staff_key = k.treating_staff_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dfd on dfd.department_key = k.first_department_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dld on dld.department_key = k.last_department_key_raw
left join (select bed_key from {{ ref('dim_bed') }}) as db on db.bed_key = k.last_bed_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
left join (select discharge_outcome_key from {{ ref('dim_discharge_outcome') }}) as ddo on ddo.discharge_outcome_key = k.discharge_outcome_key_raw
{{ hnh_settings() }}
