{{ config(order_by='(branch_key, date_key, movement_key)') }}

-- One row per patient-sale or patient-return line of fact_stock_movement (spec 6.2). The line's charge lines come from
-- int_consumption_charge_link (invoice + product -> delivery lines -> live charge lines, spec F9 and plan refinement);
-- the row carries the keys of the linked charge line with the lowest key. Each charge line's revenue is counted once: on
-- its revenue owner, the linked patient-sale line with the lowest Oasis line id. Returns carry the charge's keys but no
-- revenue. oasis_cost_amount / is_cost_mismatch pass through for margin on the Oasis cost.
with sales as (
    select movement_key, branch_key, date_key, store_key, item_key, movement_type_key, movement_type, primary_quantity,
           cost_amount, consumption_quantity, consumption_cost, source_system, is_in_oasis, is_in_fusion, is_fusion_gap,
           oasis_cost_amount, is_cost_mismatch
    from {{ ref('fact_stock_movement') }}
    where movement_type in ('Patient sale', 'Patient return')
),

links as (
    select l.movement_key as movement_key, l.charge_line_key as charge_line_key, l.is_revenue_owner as is_revenue_owner,
           ch.revenue_amount as charge_revenue,
           ch.encounter_key as charge_encounter_key, ch.episode_key as charge_episode_key, ch.patient_key as charge_patient_key,
           ch.staff_key as charge_staff_key, ch.billed_payer_key as charge_payer_key, ch.care_type_key as charge_care_type_key,
           ch.service_key as charge_service_key, ch.department_key as charge_department_key
    from {{ ref('int_consumption_charge_link') }} as l
    inner join (select charge_line_key, revenue_amount, encounter_key, episode_key, patient_key, staff_key, billed_payer_key,
                       care_type_key, service_key, department_key
                from {{ ref('fact_charge_line') }}
                where charge_line_key in (select charge_line_key from {{ ref('int_consumption_charge_link') }})) as ch
        on ch.charge_line_key = l.charge_line_key
),

charge_keys as (
    -- the keys of the linked charge line with the lowest key, and the revenue of the charge lines the line owns
    select movement_key as key_movement_key,
           argMin(charge_encounter_key, charge_line_key) as k_encounter_key, argMin(charge_episode_key, charge_line_key) as k_episode_key,
           argMin(charge_patient_key, charge_line_key) as k_patient_key, argMin(charge_staff_key, charge_line_key) as k_staff_key,
           argMin(charge_payer_key, charge_line_key) as k_payer_key, argMin(charge_care_type_key, charge_line_key) as k_care_type_key,
           argMin(charge_service_key, charge_line_key) as k_service_key, argMin(charge_department_key, charge_line_key) as k_department_key,
           min(charge_line_key) as k_charge_line_key,
           sumIf(charge_revenue, is_revenue_owner = 1) as k_revenue
    from links
    group by movement_key
)

select
    s.movement_key                                      as movement_key,
    s.branch_key                                        as branch_key,
    s.date_key                                          as date_key,
    s.store_key                                         as store_key,
    s.item_key                                          as item_key,
    s.movement_type_key                                 as movement_type_key,
    s.movement_type                                     as movement_type,
    ifNull(k.k_encounter_key, toInt64(-1))              as encounter_key,
    ifNull(k.k_episode_key, toInt64(-1))                as episode_key,
    ifNull(k.k_patient_key, toInt64(-1))                as patient_key,
    ifNull(k.k_staff_key, toInt64(-1))                  as treating_staff_key,
    ifNull(k.k_payer_key, toInt64(-1))                  as billed_payer_key,
    ifNull(k.k_care_type_key, toInt8(-1))               as care_type_key,
    ifNull(k.k_service_key, toInt64(-1))                as service_key,
    ifNull(k.k_department_key, toInt64(-1))             as department_key,
    ifNull(k.k_charge_line_key, toInt64(-1))            as charge_line_key,
    toUInt8(k.key_movement_key is not null)             as is_linked_to_charge,
    s.primary_quantity                                  as primary_quantity,
    s.cost_amount                                       as cost_amount,
    s.consumption_quantity                              as consumption_quantity,
    s.consumption_cost                                  as consumption_cost,
    ifNull(k.k_revenue, 0)                              as revenue_amount,
    s.oasis_cost_amount                                 as oasis_cost_amount,
    s.is_cost_mismatch                                  as is_cost_mismatch,
    s.source_system                                     as source_system,
    s.is_in_oasis                                       as is_in_oasis,
    s.is_in_fusion                                      as is_in_fusion,
    s.is_fusion_gap                                     as is_fusion_gap,
    now()                                               as _loaded_at
from sales as s
left join charge_keys as k on k.key_movement_key = s.movement_key
{{ hnh_settings() }}
