{{ config(order_by='(branch_id, delivery_charge_id)') }}

-- One row per Oasis charge line in the history window with the links fact_charge_line turns into dimension keys:
-- service department, policy, the ordering doctor, the MRP (most responsible physician) of responsibilities 1-3 on the
-- delivery date, and the staff who charged it. Raw values; the mart titles and keys them.
-- Ordering doctor: delivery line -> order line -> order -> orderer_staff_id.
-- MRP k: the eligibility row of responsibility k of the same branch, patient and episode that covers the delivery time
-- (start <= delivered_at <= end, open end = still running). A row that is not cancelled beats a cancelled (C) one, then
-- the latest start wins, then the highest eligibility id; a cancelled row is used only when no other row covers the
-- time; none gives null. Eligibility is joined once and aggregated per responsibility in the final select.
-- Lookups (orders, sign-ons) are limited to what the charges in the window reach, to keep memory down.
-- Charged by: cashier sign-on -> staff_id.

with charges as (
    select branch_id, delivery_charge_id, delivery_line, delivered_at, patient_id, episode_no,
           service_dept, signon_id, policy_code
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= toDateTime('{{ var('hnh_history_start_date') }} 00:00:00', 'Asia/Riyadh')
),

delivery_lines as (
    select branch_id, delivery_line, order_line
    from {{ ref('stg_oasis__delivery_lines') }}
    where (branch_id, delivery_line) in (select branch_id, delivery_line from charges)
),

order_lines as (
    select branch_id, order_line, master_order_no
    from {{ ref('stg_oasis__order_lines') }}
    where (branch_id, order_line) in (select branch_id, order_line from delivery_lines)
),

orders as (
    select branch_id, master_order_no, orderer_staff_id
    from {{ ref('stg_oasis__orders') }}
    where (branch_id, master_order_no) in (select branch_id, master_order_no from order_lines)
),

ordering as (
    select dl.branch_id as branch_id, dl.delivery_line as delivery_line, o.orderer_staff_id as orderer_staff_id
    from delivery_lines as dl
    inner join order_lines as ol
        on ol.branch_id = dl.branch_id and ol.order_line = dl.order_line
    inner join orders as o
        on o.branch_id = ol.branch_id and o.master_order_no = ol.master_order_no
),

signons as (
    select branch_id, signon_id, staff_id
    from {{ ref('stg_oasis__cashier_signons') }}
    where (branch_id, signon_id) in (select branch_id, signon_id from charges)
),

linked as (
    select
        c.branch_id as branch_id, c.delivery_charge_id as delivery_charge_id, c.delivered_at as delivered_at,
        c.patient_id as patient_id, c.episode_no as episode_no, c.service_dept as service_dept,
        c.policy_code as policy_code, od.orderer_staff_id as ordering_staff_id, cs.staff_id as charged_by_staff_id
    from charges as c
    left join ordering as od
        on od.branch_id = c.branch_id and od.delivery_line = c.delivery_line
    left join signons as cs
        on cs.branch_id = c.branch_id and cs.signon_id = c.signon_id
),

eligibility as (
    select branch_id, patient_id, episode_no, responsibility, consultant_staff_id, eligibility_status,
           eligibility_start, eligibility_end, patient_eligibility_id
    from {{ ref('stg_oasis__eligibility') }}
    where responsibility in ('1', '2', '3')
)

select
    l.branch_id                       as branch_id,
    l.delivery_charge_id              as delivery_charge_id,
    any(l.service_dept)               as service_dept,
    any(l.policy_code)                as policy_code,
    any(l.ordering_staff_id)          as ordering_staff_id,
    argMaxIf(e.consultant_staff_id, tuple(ifNull(e.eligibility_status, '') != 'C', e.eligibility_start, e.patient_eligibility_id),
             e.responsibility = '1' and e.eligibility_start <= l.delivered_at and l.delivered_at <= ifNull(e.eligibility_end, now())) as mrp_1_staff_id,
    argMaxIf(e.consultant_staff_id, tuple(ifNull(e.eligibility_status, '') != 'C', e.eligibility_start, e.patient_eligibility_id),
             e.responsibility = '2' and e.eligibility_start <= l.delivered_at and l.delivered_at <= ifNull(e.eligibility_end, now())) as mrp_2_staff_id,
    argMaxIf(e.consultant_staff_id, tuple(ifNull(e.eligibility_status, '') != 'C', e.eligibility_start, e.patient_eligibility_id),
             e.responsibility = '3' and e.eligibility_start <= l.delivered_at and l.delivered_at <= ifNull(e.eligibility_end, now())) as mrp_3_staff_id,
    any(l.charged_by_staff_id)        as charged_by_staff_id
from linked as l
left join eligibility as e
    on e.branch_id = l.branch_id and e.patient_id = l.patient_id and e.episode_no = l.episode_no
group by l.branch_id, l.delivery_charge_id
{{ hnh_settings() }}
