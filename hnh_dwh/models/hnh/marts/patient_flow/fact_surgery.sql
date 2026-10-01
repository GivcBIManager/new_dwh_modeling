{{ config(order_by='(branch_key, surgery_key)') }}

with ops as (
    select
        o.branch_id                 as branch_id,
        o.operating_slot_code       as operating_slot_code,
        o.operation_seq             as operation_seq,
        o.ios_main                  as ios_main,
        o.surgeon_staff_id          as surgeon_staff_id,
        o.anaesthetist_staff_id     as anaesthetist_staff_id,
        o.operation_status_code     as operation_status_code,
        o.operation_type_code       as operation_type_code,
        o.anaesthesia_type_code     as anaesthesia_type_code,
        sl.work_entity              as work_entity,
        sl.patient_id               as patient_id,
        sl.episode_no               as episode_no,
        sl.entity_type              as entity_type,
        sl.is_cancelled             as is_cancelled,
        sl.cancel_code              as cancel_code,
        sl.hall_arrived_at          as hall_arrived_at,
        sl.theatre_arrived_at       as theatre_arrived_at,
        sl.anaesthesia_started_at   as anaesthesia_started_at,
        sl.anaesthesia_ended_at     as anaesthesia_ended_at,
        sl.recovery_at              as recovery_at,
        sl.ward_at                  as ward_at,
        coalesce(o.operation_started_at, sl.operation_started_at) as operation_started_at,
        coalesce(o.operation_ended_at, sl.operation_ended_at)     as operation_ended_at,
        coalesce(o.operation_started_at, sl.operation_started_at, sl.scheduled_start_at) as operation_at
    from {{ ref('stg_oasis__operations') }} as o
    inner join {{ ref('stg_oasis__operating_slots') }} as sl
        on sl.branch_id = o.branch_id and sl.operating_slot_code = o.operating_slot_code
    where sl.patient_id is not null
),

enriched as (
    select
        ops.branch_id                 as branch_id,
        ops.operating_slot_code       as operating_slot_code,
        ops.operation_seq             as operation_seq,
        ops.surgeon_staff_id          as surgeon_staff_id,
        ops.anaesthetist_staff_id     as anaesthetist_staff_id,
        ops.work_entity               as work_entity,
        ops.patient_id                as patient_id,
        ops.episode_no                as episode_no,
        ops.entity_type               as entity_type,
        ops.is_cancelled              as is_cancelled,
        ops.hall_arrived_at           as hall_arrived_at,
        ops.theatre_arrived_at        as theatre_arrived_at,
        ops.anaesthesia_started_at    as anaesthesia_started_at,
        ops.anaesthesia_ended_at      as anaesthesia_ended_at,
        ops.recovery_at               as recovery_at,
        ops.ward_at                   as ward_at,
        ops.operation_started_at      as operation_started_at,
        ops.operation_ended_at        as operation_ended_at,
        ops.operation_at              as operation_at,
        upper(it.description)                                   as procedure_upper,
        it.description                                          as procedure_name,
        st.description                                          as operation_status,
        ot.description                                          as operation_type,
        an.description                                          as anaesthesia_type,
        cr.description                                          as cancel_reason,
        ifNull(ep.purchaser_code, toInt64(9999))                as purchaser_code,
        if(ep.care_type is null, 'Unknown', ep.care_type)       as care_type
    from ops
    left join {{ ref('stg_oasis__service_items') }} as it on it.branch_id = ops.branch_id and it.ios_main = ops.ios_main
    left join {{ ref('int_code_decode') }} as st on st.branch_id = ops.branch_id and st.code = ops.operation_status_code
    left join {{ ref('int_code_decode') }} as ot on ot.branch_id = ops.branch_id and ot.code = ops.operation_type_code
    left join {{ ref('int_code_decode') }} as an on an.branch_id = ops.branch_id and an.code = ops.anaesthesia_type_code
    left join {{ ref('int_code_decode') }} as cr on cr.branch_id = ops.branch_id and cr.code = ops.cancel_code
    left join {{ ref('int_episode') }} as ep
        on ep.branch_id = ops.branch_id and ep.patient_id = ops.patient_id and ep.episode_no = ops.episode_no
    where ops.operation_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
),

k as (
    select
        enriched.branch_id as branch_id,
        enriched.operating_slot_code as operating_slot_code,
        enriched.operation_seq as operation_seq,
        enriched.is_cancelled as is_cancelled,
        enriched.hall_arrived_at as hall_arrived_at,
        enriched.theatre_arrived_at as theatre_arrived_at,
        enriched.anaesthesia_started_at as anaesthesia_started_at,
        enriched.anaesthesia_ended_at as anaesthesia_ended_at,
        enriched.recovery_at as recovery_at,
        enriched.ward_at as ward_at,
        enriched.operation_started_at as operation_started_at,
        enriched.operation_ended_at as operation_ended_at,
        enriched.operation_at as operation_at,
        enriched.procedure_name as procedure_name,
        enriched.operation_status as operation_status,
        enriched.operation_type as operation_type,
        enriched.anaesthesia_type as anaesthesia_type,
        enriched.cancel_reason as cancel_reason,
        enriched.care_type as care_type,
        {{ hnh_surrogate_key(['branch_id', 'operating_slot_code', 'operation_seq']) }} as surgery_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}             as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                           as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'surgeon_staff_id']) }}                     as surgeon_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'anaesthetist_staff_id']) }}                as anaesthetist_staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}                          as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }}                       as payer_key_raw,
        {{ hnh_procedure_type('procedure_upper', 'entity_type') }}                     as procedure_type
    from enriched
)

select
    k.surgery_key                                        as surgery_key,
    k.branch_id                                          as branch_key,
    {{ hnh_date_key('k.operation_at') }}                 as operation_date_key,
    {{ hnh_time_key('k.operation_at') }}                 as operation_time_key,
    k.episode_key                                        as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                  as patient_key,
    ifNull(dsu.staff_key, toInt64(-1))                   as surgeon_staff_key,
    ifNull(dan.staff_key, toInt64(-1))                   as anaesthetist_staff_key,
    ifNull(dd.department_key, toInt64(-1))               as department_key,
    ifNull(dpy.payer_key, toInt64(-1))                   as payer_key,
    {{ hnh_care_type_key('k.care_type') }}               as care_type_key,
    {{ hnh_procedure_type_key('k.procedure_type') }}     as procedure_type_key,
    k.operating_slot_code                                as operating_slot_code,
    k.operation_seq                                      as operation_seq,
    k.procedure_name                                     as procedure_name,
    k.operation_type                                     as operation_type,
    k.anaesthesia_type                                   as anaesthesia_type,
    k.operation_status                                   as operation_status,
    k.is_cancelled                                       as is_cancelled,
    k.cancel_reason                                      as cancel_reason,
    {{ hnh_minutes_between('k.hall_arrived_at', 'k.theatre_arrived_at') }}        as hall_to_theatre_minutes,
    {{ hnh_minutes_between('k.anaesthesia_started_at', 'k.anaesthesia_ended_at') }} as anaesthesia_minutes,
    {{ hnh_minutes_between('k.operation_started_at', 'k.operation_ended_at') }}   as operating_minutes,
    {{ hnh_minutes_between('k.recovery_at', 'k.ward_at') }}                       as recovery_handover_minutes,
    now()                                                as _loaded_at
from k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dsu on dsu.staff_key = k.surgeon_staff_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as dan on dan.staff_key = k.anaesthetist_staff_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = k.department_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
{{ hnh_settings() }}
