{{ config(order_by='(branch_id, delivery_charge_id)') }}

-- One row per Oasis charge line in the history window with the links fact_charge_line turns into dimension keys:
-- service department, policy, the ordering doctor, the MRP (most responsible physician) of responsibilities 1-3 on the
-- delivery date, and the staff who charged it. Raw values; the mart titles and keys them.
-- Ordering doctor: delivery line -> order line -> order -> orderer_staff_id.
-- MRP k: the eligibility row of responsibility k (not cancelled) of the same branch, patient and episode that covers
-- the delivery time (start <= delivered_at <= end, open end = still running); the latest start wins, then the highest
-- eligibility id; no covering row gives null. Eligibility is joined once and aggregated per responsibility.
-- Charged by: cashier sign-on -> staff_id.

with charges as (
    select branch_id, delivery_charge_id, delivery_line, delivered_at, patient_id, episode_no,
           service_dept, signon_id, policy_code
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= toDateTime('{{ var('hnh_history_start_date') }} 00:00:00', 'Asia/Riyadh')
),

eligibility as (
    select branch_id, patient_id, episode_no, responsibility, consultant_staff_id, eligibility_start,
           eligibility_end, patient_eligibility_id
    from {{ ref('stg_oasis__eligibility') }}
    where responsibility in ('1', '2', '3') and ifNull(eligibility_status, '') != 'C'
),

mrp as (
    select
        c.branch_id, c.delivery_charge_id,
        argMaxIf(e.consultant_staff_id, tuple(e.eligibility_start, e.patient_eligibility_id),
                 e.responsibility = '1' and e.eligibility_start <= c.delivered_at and c.delivered_at <= ifNull(e.eligibility_end, now())) as mrp_1_staff_id,
        argMaxIf(e.consultant_staff_id, tuple(e.eligibility_start, e.patient_eligibility_id),
                 e.responsibility = '2' and e.eligibility_start <= c.delivered_at and c.delivered_at <= ifNull(e.eligibility_end, now())) as mrp_2_staff_id,
        argMaxIf(e.consultant_staff_id, tuple(e.eligibility_start, e.patient_eligibility_id),
                 e.responsibility = '3' and e.eligibility_start <= c.delivered_at and c.delivered_at <= ifNull(e.eligibility_end, now())) as mrp_3_staff_id
    from charges as c
    inner join eligibility as e
        on e.branch_id = c.branch_id and e.patient_id = c.patient_id and e.episode_no = c.episode_no
    group by c.branch_id, c.delivery_charge_id
),

ordering as (
    select dl.branch_id as branch_id, dl.delivery_line as delivery_line, o.orderer_staff_id as orderer_staff_id
    from {{ ref('stg_oasis__delivery_lines') }} as dl
    inner join {{ ref('stg_oasis__order_lines') }} as ol
        on ol.branch_id = dl.branch_id and ol.order_line = dl.order_line
    inner join {{ ref('stg_oasis__orders') }} as o
        on o.branch_id = ol.branch_id and o.master_order_no = ol.master_order_no
)

select
    c.branch_id                  as branch_id,
    c.delivery_charge_id         as delivery_charge_id,
    c.service_dept               as service_dept,
    c.policy_code                as policy_code,
    od.orderer_staff_id          as ordering_staff_id,
    m.mrp_1_staff_id             as mrp_1_staff_id,
    m.mrp_2_staff_id             as mrp_2_staff_id,
    m.mrp_3_staff_id             as mrp_3_staff_id,
    cs.staff_id                  as charged_by_staff_id
from charges as c
left join mrp as m
    on m.branch_id = c.branch_id and m.delivery_charge_id = c.delivery_charge_id
left join ordering as od
    on od.branch_id = c.branch_id and od.delivery_line = c.delivery_line
left join {{ ref('stg_oasis__cashier_signons') }} as cs
    on cs.branch_id = c.branch_id and cs.signon_id = c.signon_id
{{ hnh_settings() }}
