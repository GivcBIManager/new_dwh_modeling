{{ config(order_by='(branch_id, patient_id, episode_no)') }}

with eligibility as (
    select * from {{ ref('stg_oasis__eligibility') }}
    where patient_id is not null and episode_no is not null
),

primary_eligibility as (
    -- One row per episode: lowest sequence, then lowest id. The whole row is taken
    -- as a tuple so every attribute comes from the same source row.
    select
        branch_id, patient_id, episode_no,
        argMin(
            tuple(attendance_type, consultant_staff_id, service_dept, coalesce(eligibility_work_entity, work_entity), admission_no),
            tuple(ifNull(sequence, 999999999), patient_eligibility_id)
        )                       as chosen,
        any(attendance_type)    as legacy_attendance_type
    from eligibility
    where responsibility = '1'
    group by branch_id, patient_id, episode_no
),

payer as (
    select
        branch_id, patient_id, episode_no,
        argMin(tuple(purchaser_code, policy_code, contract_no), tuple(responsibility_seq, ifNull(contract_no, 0))) as chosen,
        any(purchaser_code) as legacy_purchaser_code
    from {{ ref('stg_oasis__bill_agreements') }}
    where ifNull(status, 'I') = 'I'
    group by branch_id, patient_id, episode_no
),

episode_history as (
    -- Every episode ever recorded for a patient, including pre-2022 episodes that
    -- exist only in eligibility, so rank and look-back are correct.
    select h.branch_id as branch_id, h.patient_id as patient_id, h.episode_no as episode_no,
           tupleElement(pe.chosen, 1) as attendance_type
    from (
        select distinct branch_id, assumeNotNull(patient_id) as patient_id, assumeNotNull(episode_no) as episode_no from eligibility
        union distinct
        select branch_id, patient_id, episode_no from {{ ref('stg_oasis__episodes') }}
    ) as h
    left join primary_eligibility as pe
        on pe.branch_id = h.branch_id and pe.patient_id = h.patient_id and pe.episode_no = h.episode_no
),

ranked as (
    select
        branch_id, patient_id, episode_no,
        row_number() over (partition by branch_id, patient_id order by episode_no) as episode_seq,
        lagInFrame(toNullable(attendance_type), 1) over (
            partition by branch_id, patient_id order by episode_no
            rows between unbounded preceding and current row
        ) as previous_attendance_type
    from episode_history
)

select
    e.branch_id                                              as branch_id,
    e.patient_id                                             as patient_id,
    e.episode_no                                             as episode_no,
    e.started_at                                             as started_at,
    e.ended_at                                               as ended_at,
    e.eligibility_type                                       as eligibility_type,
    {{ hnh_care_type('tupleElement(pe.chosen, 1)') }}        as care_type,
    toUInt8(pe.branch_id is not null)                        as has_eligibility,
    tupleElement(pe.chosen, 2)                               as consultant_staff_id,
    tupleElement(pe.chosen, 3)                               as service_dept,
    tupleElement(pe.chosen, 4)                               as work_entity,
    tupleElement(pe.chosen, 5)                               as eligibility_admission_no,
    ifNull(tupleElement(py.chosen, 1), toInt64(9999))        as purchaser_code,
    tupleElement(py.chosen, 2)                               as policy_code,
    tupleElement(py.chosen, 3)                               as contract_no,
    toUInt32(r.episode_seq)                                  as episode_seq,
    toUInt8(r.episode_seq = 1)                               as is_first_episode,
    if(r.episode_seq = 1 or r.previous_attendance_type is null, null,
       {{ hnh_care_type('r.previous_attendance_type') }})    as previous_care_type,
    {{ hnh_care_type('pe.legacy_attendance_type') }}         as legacy_care_type,
    ifNull(py.legacy_purchaser_code, toInt64(9999))          as legacy_purchaser_code
from {{ ref('stg_oasis__episodes') }} as e
left join primary_eligibility as pe
    on pe.branch_id = e.branch_id and pe.patient_id = e.patient_id and pe.episode_no = e.episode_no
left join payer as py
    on py.branch_id = e.branch_id and py.patient_id = e.patient_id and py.episode_no = e.episode_no
left join ranked as r
    on r.branch_id = e.branch_id and r.patient_id = e.patient_id and r.episode_no = e.episode_no
{{ hnh_settings() }}
