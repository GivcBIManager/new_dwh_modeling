{{ config(order_by='(branch_key, date_key, movement_key)') }}

-- One row per patient-sale or patient-return line of fact_stock_movement (spec 6.2). The line's charge lines come from
-- int_consumption_charge_link (invoice + product -> delivery lines -> live charge lines, spec F9 and plan refinement);
-- the row carries the keys of the linked live charge line with the lowest key, or of the lowest-key cancelled one when
-- no live charge links. Each charge line's revenue is counted once: on its revenue owner, the linked patient-sale line
-- with the lowest Oasis line id. Returns carry the charge's keys but no revenue. revenue_basis (controller ruling,
-- refines spec 7): 'charge' = links to a live charge that is not a package component; 'package_component' = its live
-- charges are all package components (revenue on the package header, which does not link here); 'cancelled' = only
-- non-live (cancelled or unknown-status) charges; 'none' = no charge. is_linked_to_charge = 1 when a live charge links.
-- oasis_cost_amount / is_cost_mismatch pass through for margin on the Oasis cost.
with sales as (
    select movement_key, branch_key, date_key, store_key, item_key, movement_type_key, movement_type, primary_quantity,
           cost_amount, consumption_quantity, consumption_cost, source_system, is_in_oasis, is_in_fusion, is_fusion_gap,
           oasis_cost_amount, is_cost_mismatch
    from {{ ref('fact_stock_movement') }}
    where movement_type in ('Patient sale', 'Patient return')
),

link_agg as (
    -- per line, from the narrow link alone: the key charge (lowest-key live, else lowest-key cancelled) and the counts
    -- that give the revenue basis
    select movement_key as agg_movement_key,
           if(countIf(charge_status = 'Live') > 0, minIf(charge_line_key, charge_status = 'Live'), min(charge_line_key)) as k_charge_line_key,
           countIf(charge_status = 'Live') as k_live_charges,
           countIf(charge_status = 'Live' and is_package_component = 0) as k_live_revenue_charges
    from {{ ref('int_consumption_charge_link') }}
    group by movement_key
),

key_charges as (
    select charge_line_key as kc_charge_line_key, encounter_key as kc_encounter_key, episode_key as kc_episode_key,
           patient_key as kc_patient_key, staff_key as kc_staff_key, billed_payer_key as kc_payer_key,
           care_type_key as kc_care_type_key, service_key as kc_service_key, department_key as kc_department_key
    from {{ ref('fact_charge_line') }}
    where charge_line_key in (select charge_line_key from {{ ref('int_consumption_charge_link') }})
),

owner_revenue as (
    -- the revenue of the charge lines the line owns
    select l.movement_key as rev_movement_key, sum(ch.revenue_amount) as k_revenue
    from {{ ref('int_consumption_charge_link') }} as l
    inner join (select charge_line_key, revenue_amount from {{ ref('fact_charge_line') }} where revenue_amount != 0) as ch
        on ch.charge_line_key = l.charge_line_key
    where l.is_revenue_owner = 1
    group by l.movement_key
)

select
    s.movement_key                                      as movement_key,
    s.branch_key                                        as branch_key,
    s.date_key                                          as date_key,
    s.store_key                                         as store_key,
    s.item_key                                          as item_key,
    s.movement_type_key                                 as movement_type_key,
    s.movement_type                                     as movement_type,
    ifNull(kc.kc_encounter_key, toInt64(-1))            as encounter_key,
    ifNull(kc.kc_episode_key, toInt64(-1))              as episode_key,
    ifNull(kc.kc_patient_key, toInt64(-1))              as patient_key,
    ifNull(kc.kc_staff_key, toInt64(-1))                as treating_staff_key,
    ifNull(kc.kc_payer_key, toInt64(-1))                as billed_payer_key,
    ifNull(kc.kc_care_type_key, toInt8(-1))             as care_type_key,
    ifNull(kc.kc_service_key, toInt64(-1))              as service_key,
    ifNull(kc.kc_department_key, toInt64(-1))           as department_key,
    ifNull(a.k_charge_line_key, toInt64(-1))            as charge_line_key,
    toUInt8(ifNull(a.k_live_charges, 0) > 0)            as is_linked_to_charge,
    toLowCardinality(multiIf(a.agg_movement_key is null, 'none', ifNull(a.k_live_revenue_charges, 0) > 0, 'charge',
                             ifNull(a.k_live_charges, 0) > 0, 'package_component', 'cancelled')) as revenue_basis,
    s.primary_quantity                                  as primary_quantity,
    s.cost_amount                                       as cost_amount,
    s.consumption_quantity                              as consumption_quantity,
    s.consumption_cost                                  as consumption_cost,
    ifNull(r.k_revenue, 0)                              as revenue_amount,
    s.oasis_cost_amount                                 as oasis_cost_amount,
    s.is_cost_mismatch                                  as is_cost_mismatch,
    s.source_system                                     as source_system,
    s.is_in_oasis                                       as is_in_oasis,
    s.is_in_fusion                                      as is_in_fusion,
    s.is_fusion_gap                                     as is_fusion_gap,
    now()                                               as _loaded_at
from sales as s
left join link_agg as a on a.agg_movement_key = s.movement_key
left join key_charges as kc on kc.kc_charge_line_key = a.k_charge_line_key
left join owner_revenue as r on r.rev_movement_key = s.movement_key
{{ hnh_settings() }}
