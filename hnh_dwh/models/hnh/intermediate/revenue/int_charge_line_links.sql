{{ config(order_by='(branch_id, delivery_charge_id)') }}

-- One row per Oasis charge line in the history window with the links fact_charge_line turns into dimension keys:
-- service department, policy, the ordering doctor, the MRP (most responsible physician) of responsibilities 1-3 on the
-- delivery date, and the staff who charged it. Raw values; the mart titles and keys them.
-- Ordering doctor: delivery line -> order line -> order -> orderer_staff_id.
-- MRP k: the eligibility row of responsibility k of the same branch, patient and episode that covers the delivery time
-- (start <= delivered_at <= end, open end = still running). A row that is not cancelled beats a cancelled (C) one, then
-- the latest start wins, then the highest eligibility id; a cancelled row is used only when no other row covers the
-- time; none gives null, and so does a winning row without a consultant. Eligibility is grouped once per branch,
-- patient and episode into an array of periods, joined 1:1 to the charges, and each MRP is picked from that array, so
-- no aggregation over the charges is needed (memory).
-- Lookups (orders, sign-ons) are limited to what the charges in the window reach, to keep memory down.
-- Charged by: cashier sign-on -> staff_id.
-- Policy class: REF when the line's policy is a referral (int_policy_client), else the class of the line's contract
-- (int_contract_class: Oasis class description, else the old server's mapping), else null (policy class design 2026-11-18).
-- A co-pay or deductible line (bill-to other than 1) without its own contract has no policy or contract in Oasis; it
-- takes the policy and contract of the live purchaser (bill-to 1) row on the same delivery line for its class, so an
-- insured visit's patient share is classed with the visit. Its policy_code output is unchanged (dim_policy's Deductible).

with charges as (
    select branch_id, delivery_charge_id, delivery_line, delivered_at, patient_id, episode_no,
           service_dept, signon_id, policy_code, contract_no, bill_to, cancel_flag
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= toDateTime('{{ var('hnh_history_start_date') }} 00:00:00', 'Asia/Riyadh')
),

purchaser_rows as (
    -- the live purchaser (bill-to 1) row of each delivery line (the lowest charge id if there are several), only for the
    -- delivery lines that have a patient-share row without a contract
    select branch_id, delivery_line,
           argMin(tuple(policy_code, contract_no), delivery_charge_id) as purchaser_policy_contract
    from charges
    where bill_to = '1' and cancel_flag is null
      and (branch_id, delivery_line) in (
          select branch_id, delivery_line from charges
          where ifNull(bill_to, '') != '1' and contract_no is null and delivery_line is not null)
    group by branch_id, delivery_line
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
        c.policy_code as policy_code, od.orderer_staff_id as ordering_staff_id, cs.staff_id as charged_by_staff_id,
        -- the policy and contract the class is taken from: the line's own, or its purchaser row's for a patient share
        -- without a contract
        if(ifNull(c.bill_to, '') != '1' and c.contract_no is null, pr.purchaser_policy_contract.1, c.policy_code) as class_policy_code,
        if(ifNull(c.bill_to, '') != '1' and c.contract_no is null, pr.purchaser_policy_contract.2, c.contract_no) as class_contract_no
    from charges as c
    left join ordering as od
        on od.branch_id = c.branch_id and od.delivery_line = c.delivery_line
    left join signons as cs
        on cs.branch_id = c.branch_id and cs.signon_id = c.signon_id
    left join purchaser_rows as pr
        on pr.branch_id = c.branch_id and pr.delivery_line = c.delivery_line
),

eligibility as (
    -- periods: (responsibility, not cancelled, start, end, eligibility id, consultant). A row without a start, or one that
    -- ended before the history window, never covers a charge in the window.
    select
        branch_id, patient_id, episode_no,
        groupArray(tuple(assumeNotNull(responsibility), toUInt8(ifNull(eligibility_status, '') != 'C'),
                         assumeNotNull(eligibility_start), eligibility_end, patient_eligibility_id,
                         consultant_staff_id)) as periods
    from {{ ref('stg_oasis__eligibility') }}
    where responsibility in ('1', '2', '3') and eligibility_start is not null
      and (eligibility_end is null or eligibility_end >= toDateTime('{{ var('hnh_history_start_date') }} 00:00:00', 'Asia/Riyadh'))
      and patient_id is not null and episode_no is not null
    group by branch_id, patient_id, episode_no
)

select
    l.branch_id                       as branch_id,
    l.delivery_charge_id              as delivery_charge_id,
    l.service_dept                    as service_dept,
    l.policy_code                     as policy_code,
    l.ordering_staff_id               as ordering_staff_id,
    -- MRP 1: the best covering period of responsibility 1 (sorted by not cancelled, start, id; none gives null)
    arrayReverseSort(p -> tuple(p.2, p.3, p.5),
        arrayFilter(p -> p.1 = '1' and p.3 <= l.delivered_at and l.delivered_at <= ifNull(p.4, now()), e.periods)
    )[1].6                            as mrp_1_staff_id,
    -- MRP 2: the best covering period of responsibility 2 (sorted by not cancelled, start, id; none gives null)
    arrayReverseSort(p -> tuple(p.2, p.3, p.5),
        arrayFilter(p -> p.1 = '2' and p.3 <= l.delivered_at and l.delivered_at <= ifNull(p.4, now()), e.periods)
    )[1].6                            as mrp_2_staff_id,
    -- MRP 3: the best covering period of responsibility 3 (sorted by not cancelled, start, id; none gives null)
    arrayReverseSort(p -> tuple(p.2, p.3, p.5),
        arrayFilter(p -> p.1 = '3' and p.3 <= l.delivered_at and l.delivered_at <= ifNull(p.4, now()), e.periods)
    )[1].6                            as mrp_3_staff_id,
    l.charged_by_staff_id             as charged_by_staff_id,
    if(rp.policy_code is not null, 'REF', cc.policy_class) as policy_class
from linked as l
left join eligibility as e
    on e.branch_id = l.branch_id and e.patient_id = l.patient_id and e.episode_no = l.episode_no
left join (select branch_id, policy_code from {{ ref('int_policy_client') }} where is_referral = 1) as rp
    on rp.branch_id = l.branch_id and rp.policy_code = l.class_policy_code
left join (select branch_id, contract_no, policy_class from {{ ref('int_contract_class') }}) as cc
    on cc.branch_id = l.branch_id and cc.contract_no = l.class_contract_no
{{ hnh_settings() }}
