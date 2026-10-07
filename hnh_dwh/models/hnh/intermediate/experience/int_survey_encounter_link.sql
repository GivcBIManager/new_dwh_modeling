{{ config(order_by='surveycode') }}

-- One row per survey invitation with the encounter it was sent for (spec 6.1). Branch from dim_branch.pg_branch_code;
-- encounter by branch + encounter type (prefix o/e/i) + Oasis id (appointment id, ER visit id, admission no). Episode,
-- patient, clinic, payer and care type come from the encounter. Doctor: for IP the admission's consultant, else the
-- encounter's treating doctor, else its booked doctor (spec P8). Unlinked surveys get -1 keys.
with surveys as (
    select
        r.surveycode                                        as surveycode,
        r.encounter_id                                      as encounter_id,
        ifNull(b.branch_key, toUInt8(0))                    as branch_key,
        {{ hnh_survey_encounter_type('r.encounter_id') }}   as encounter_type,
        {{ hnh_survey_source_id('r.encounter_id') }}        as source_id
    from {{ ref('stg_pg__survey_response') }} as r
    left join (select branch_key, pg_branch_code from {{ ref('hnh_dim_branch') }} where pg_branch_code is not null) as b
        on b.pg_branch_code = r.pg_branch_code
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

encounters as (
    select branch_key as e_branch_key, encounter_type as e_encounter_type, source_id as e_source_id,
           encounter_key as e_encounter_key, episode_key as e_episode_key, patient_key as e_patient_key,
           department_key as e_department_key, payer_key as e_payer_key, care_type_key as e_care_type_key,
           treating_staff_key as e_treating_staff_key, booked_staff_key as e_booked_staff_key
    from {{ ref('fact_encounter') }}
)

select
    s.surveycode                                            as surveycode,
    s.branch_key                                            as branch_key,
    s.encounter_id                                          as encounter_id,
    s.encounter_type                                        as encounter_type,
    ifNull(e.e_encounter_key, toInt64(-1))                  as encounter_key,
    ifNull(e.e_episode_key, toInt64(-1))                    as episode_key,
    ifNull(e.e_patient_key, toInt64(-1))                    as patient_key,
    ifNull(e.e_department_key, toInt64(-1))                 as department_key,
    ifNull(e.e_payer_key, toInt64(-1))                      as payer_key,
    ifNull(e.e_care_type_key, toInt8(-1))                   as care_type_key,
    toInt64(multiIf(e.e_encounter_key is null, -1,
                    s.encounter_type = 'IP' and ifNull(a.consultant_staff_key, -1) != -1, a.consultant_staff_key,
                    ifNull(e.e_treating_staff_key, -1) != -1, e.e_treating_staff_key,
                    ifNull(e.e_booked_staff_key, -1)))      as staff_key,
    multiIf(e.e_encounter_key is not null, 'Linked',
            s.source_id is null, 'Bad encounter id',
            'Encounter not found')                          as link_status
from surveys as s
left join encounters as e
    on e.e_branch_key = s.branch_key and e.e_encounter_type = s.encounter_type and e.e_source_id = s.source_id
left join (select encounter_key, consultant_staff_key from {{ ref('fact_admission') }}) as a
    on a.encounter_key = e.e_encounter_key
{{ hnh_settings() }}
