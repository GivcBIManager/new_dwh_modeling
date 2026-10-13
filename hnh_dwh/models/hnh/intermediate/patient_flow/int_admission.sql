{{ config(order_by='(branch_id, admission_no)') }}

with first_request as (
    -- The earliest request per admission, so a second request never duplicates the stay.
    select
        branch_id, assumeNotNull(admission_no) as admission_no,
        argMin(tuple(consultant_staff_id, planned_admit_at, admission_department_code, urgency_code, admission_type),
               admission_request_id) as chosen
    from {{ ref('stg_oasis__admission_requests') }}
    where admission_no is not null
    group by branch_id, admission_no
),

beds as (
    select
        branch_id, admission_no,
        if(countIf(is_excluded_ward = 0) > 0, argMinIf(work_entity, tuple(started_at, bed_detail_id), is_excluded_ward = 0), argMin(work_entity, tuple(started_at, bed_detail_id))) as first_work_entity,
        if(countIf(is_excluded_ward = 0) > 0, argMaxIf(work_entity, tuple(started_at, bed_detail_id), is_excluded_ward = 0), argMax(work_entity, tuple(started_at, bed_detail_id))) as last_work_entity,
        if(countIf(is_excluded_ward = 0) > 0, argMaxIf(toNullable(bed_location), tuple(started_at, bed_detail_id), is_excluded_ward = 0), argMax(toNullable(bed_location), tuple(started_at, bed_detail_id))) as last_bed_location,
        toUInt8(count() > 0)                                                            as has_bed,
        toUInt8(max(is_critical))                                                       as had_critical_bed,
        sumIf(dateDiff('minute', started_at, ifNull(ended_at, now('Asia/Riyadh'))), is_critical = 1) / 60 as critical_bed_hours,
        minIf(toNullable(started_at), is_critical = 1)                                  as first_critical_at,
        maxIf(ended_at, is_critical = 1)                                                as last_critical_left_at,
        toUInt8(argMax(is_excluded_ward, bed_detail_id) = 0)                            as legacy_last_bed_ok
    from {{ ref('int_bed_segment') }}
    group by branch_id, admission_no
),

base as (
    select
        a.branch_id                 as branch_id,
        a.admission_no              as admission_no,
        a.patient_id                as patient_id,
        a.episode_no                as episode_no,
        a.admitted_at               as admitted_at,
        a.seen_at                   as seen_at,
        a.estimated_discharge_at    as estimated_discharge_at,
        a.clinical_discharge_at     as clinical_discharge_at,
        a.physical_discharge_at     as physical_discharge_at,
        a.financial_discharge_at    as financial_discharge_at,
        a.treating_staff_id         as treating_staff_id,
        a.outcome_code              as outcome_code,
        a.bed_class                 as bed_class,
        tupleElement(rq.chosen, 1)  as request_consultant_staff_id,
        tupleElement(rq.chosen, 2)  as request_planned_admit_at,
        tupleElement(rq.chosen, 4)  as request_urgency_code,
        tupleElement(rq.chosen, 5)  as request_admission_type,
        dep.description_upper       as admission_department_upper,
        ref_t.description_upper     as referred_upper,
        if(a.outcome_code is null, 'Not recorded', {{ hnh_discharge_outcome_group('out.description_upper') }}) as discharge_outcome_group,
        ep.previous_care_type       as previous_care_type,
        b.first_work_entity         as first_work_entity,
        b.last_work_entity          as last_work_entity,
        b.last_bed_location         as last_bed_location,
        toUInt8(ifNull(b.has_bed, 0))            as has_bed,
        toUInt8(ifNull(b.had_critical_bed, 0))   as had_critical_bed,
        ifNull(b.critical_bed_hours, 0)          as critical_bed_hours,
        b.first_critical_at         as first_critical_at,
        b.last_critical_left_at     as last_critical_left_at,
        toUInt8(ifNull(b.legacy_last_bed_ok, 0)) as legacy_last_bed_ok,
        toUInt8(a.physical_discharge_at is null) as is_open,
        dateDiff('minute', a.admitted_at, a.physical_discharge_at) / 60       as los_hours,
        dateDiff('minute', a.admitted_at, ifNull(a.physical_discharge_at, now('Asia/Riyadh'))) / 1440 as los_days_to_date
    from {{ ref('stg_oasis__admissions') }} as a
    left join first_request as rq on rq.branch_id = a.branch_id and rq.admission_no = a.admission_no
    left join beds as b on b.branch_id = a.branch_id and b.admission_no = a.admission_no
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = a.branch_id and ep.patient_id = a.patient_id and ep.episode_no = a.episode_no
    left join {{ ref('int_code_decode') }} as out on out.branch_id = a.branch_id and out.code = a.outcome_code
    left join {{ ref('int_code_decode') }} as ref_t on ref_t.branch_id = a.branch_id and ref_t.code = a.referred_type_code
    left join {{ ref('int_code_decode') }} as dep
        on dep.branch_id = a.branch_id and dep.code = tupleElement(rq.chosen, 3)
),

flagged as (
    select
        *,
        los_hours / 24                                                          as los_days,
        {{ hnh_is_short_stay('admitted_at', 'physical_discharge_at') }}         as is_short_stay,
        toUInt8(discharge_outcome_group = 'Wrong admission')                    as is_wrong_admission_outcome
    from base
),

countable as (
    -- Admissions follow the old warehouse's vw_inpatients rules (user decision 2026-10-13): in scope = a last bed in a
    -- ward that is not excluded and an outcome that is not wrong admission; countable = in scope and more than one hour
    -- (to now for open stays). The rule of the gold spec is kept as is_countable_corrected.
    select
        *,
        toUInt8(is_short_stay = 0 and is_wrong_admission_outcome = 0)                         as is_countable_corrected,
        toUInt8(has_bed = 1 and legacy_last_bed_ok = 1 and is_wrong_admission_outcome = 0)     as in_legacy_scope,
        toUInt8(has_bed = 1 and legacy_last_bed_ok = 1 and is_wrong_admission_outcome = 0
                and dateDiff('hour', admitted_at, ifNull(physical_discharge_at, now('Asia/Riyadh'))) > 1) as is_countable
    from flagged
),

previous_stay as (
    -- Look-back over countable stays only: the previous stay's discharge and the
    -- moment it last left a Critical bed.
    select
        branch_id, admission_no,
        lagInFrame(physical_discharge_at, 1) over w   as previous_discharge_at,
        lagInFrame(last_critical_left_at, 1) over w   as previous_critical_left_at
    from countable
    where is_countable_corrected = 1 and patient_id is not null and admitted_at is not null
    window w as (partition by branch_id, patient_id order by admitted_at asc, admission_no asc
                 rows between unbounded preceding and current row)
),

previous_any as (
    -- The old rule: previous admission date over the admissions of the old vw_inpatients (in scope, short or not).
    select
        branch_id, admission_no,
        lagInFrame(admitted_at, 1) over (partition by branch_id, patient_id order by admitted_at asc, admission_no asc
                                         rows between unbounded preceding and current row) as previous_admitted_at
    from countable
    where in_legacy_scope = 1 and patient_id is not null and admitted_at is not null
),

wards as (
    select branch_id, work_entity, upper(ifNull(description, '')) as ward_upper
    from {{ ref('stg_oasis__work_entities') }}
)

select
    c.branch_id as branch_id, c.admission_no as admission_no, c.patient_id as patient_id, c.episode_no as episode_no,
    c.admitted_at as admitted_at, c.seen_at as seen_at, c.estimated_discharge_at as estimated_discharge_at, c.clinical_discharge_at as clinical_discharge_at, c.physical_discharge_at as physical_discharge_at, c.financial_discharge_at as financial_discharge_at,
    c.treating_staff_id as treating_staff_id, c.request_consultant_staff_id as request_consultant_staff_id, c.request_planned_admit_at as request_planned_admit_at, c.request_urgency_code as request_urgency_code, c.request_admission_type as request_admission_type,
    c.outcome_code as outcome_code, c.discharge_outcome_group as discharge_outcome_group,
    {{ hnh_admission_source('c.admission_department_upper', 'c.previous_care_type') }} as admission_source,
    c.referred_upper as referred_type,
    c.bed_class as bed_class,
    c.los_hours as los_hours, c.los_days as los_days, c.los_days_to_date as los_days_to_date,
    c.is_open as is_open, c.is_short_stay as is_short_stay, c.is_wrong_admission_outcome as is_wrong_admission_outcome, c.is_countable as is_countable,
    c.is_countable_corrected as is_countable_corrected,
    -- old rule: more than 30 days to discharge or to now, or referred as LTC
    toUInt8(dateDiff('hour', c.admitted_at, ifNull(c.physical_discharge_at, now('Asia/Riyadh'))) / 24 > 30
            or ifNull(c.referred_upper, '') = 'LTC')             as is_ltc,
    toUInt8(dateDiff('hour', c.admitted_at, ifNull(c.physical_discharge_at, now('Asia/Riyadh'))) / 24 > 30
            or ifNull(c.referred_upper, '') = 'LTC')             as is_ltc_to_date,
    {{ hnh_is_ltc('c.los_days', 'c.referred_upper') }}          as is_ltc_corrected,
    c.first_work_entity as first_work_entity, c.last_work_entity as last_work_entity, c.last_bed_location as last_bed_location, c.has_bed as has_bed,
    c.had_critical_bed as had_critical_bed, c.critical_bed_hours as critical_bed_hours, c.first_critical_at as first_critical_at, c.last_critical_left_at as last_critical_left_at,
    if(ps.previous_discharge_at is null, null, dateDiff('day', ps.previous_discharge_at, c.admitted_at)) as days_since_previous_discharge,
    -- old rules: days from the previous admission of the old scope; ICU = within 2 days, last ward named ICU or CCU
    toUInt8(ifNull(dateDiff('day', pa.previous_admitted_at, c.admitted_at) <= 30, 0))                    as is_readmission_30d,
    toUInt8(ifNull(dateDiff('day', pa.previous_admitted_at, c.admitted_at) <= 2, 0)
            and (ifNull(wd.ward_upper, '') like '%ICU%' or ifNull(wd.ward_upper, '') like '%CCU%'))      as is_icu_readmission_48h,
    toUInt8(ifNull(dateDiff('day', ps.previous_discharge_at, c.admitted_at) between 0 and 30, 0))        as is_readmission_30d_corrected,
    toUInt8(ifNull(dateDiff('minute', ps.previous_critical_left_at, c.first_critical_at) between 0 and 2880, 0)) as is_icu_readmission_48h_corrected,
    toUInt8(c.discharge_outcome_group = 'Died')                  as is_died,
    toUInt8(c.discharge_outcome_group = 'Left against advice')   as is_dama,
    toUInt8(dateDiff('hour', c.admitted_at, ifNull(c.physical_discharge_at, now('Asia/Riyadh'))) <= 1) as legacy_is_wrong_admission,
    toUInt8(dateDiff('hour', c.admitted_at, ifNull(c.physical_discharge_at, now('Asia/Riyadh'))) / 24 > 30
            or ifNull(c.referred_upper, '') = 'LTC')             as legacy_is_ltc,
    if(pa.previous_admitted_at is null, null, dateDiff('day', pa.previous_admitted_at, c.admitted_at)) as legacy_days_since_previous_admission,
    toUInt8(c.has_bed = 1 and c.legacy_last_bed_ok = 1)          as legacy_in_vw_inpatients
from countable as c
left join previous_stay as ps on ps.branch_id = c.branch_id and ps.admission_no = c.admission_no
left join previous_any as pa on pa.branch_id = c.branch_id and pa.admission_no = c.admission_no
left join wards as wd on wd.branch_id = c.branch_id and wd.work_entity = c.last_work_entity
{{ hnh_settings() }}
