{{ config(order_by='(branch_key, month_start)') }}

-- Patient consumption cost against the revenue of the same charge lines, per branch and month (spec 8), with the sale
-- lines that have no charge and the medication charges that no stock line links to. A charge is linked when
-- int_consumption_charge_link holds it (the same link as fact_patient_consumption, so a charge linked only beside a
-- line's lowest charge key still counts as linked). linked_consumption_cost_oasis values the linked lines at the Oasis
-- line's cost (Fusion pack-item costs are per base unit in five branches).
with consumption as (
    select branch_key, toStartOfMonth(toDate(toString(date_key))) as month_start,
           sum(consumption_cost) as patient_consumption_cost,
           sumIf(consumption_cost, is_linked_to_charge = 1) as linked_consumption_cost,
           -- patient sales and returns are consumption rows: consumption cost = 0 - cost
           sumIf(0 - ifNull(oasis_cost_amount, 0), is_linked_to_charge = 1) as linked_consumption_cost_oasis,
           sum(revenue_amount) as linked_revenue,
           countIf(movement_type = 'Patient sale' and is_linked_to_charge = 0) as sale_lines_without_charge,
           sumIf(consumption_cost, movement_type = 'Patient sale' and is_linked_to_charge = 0) as cost_without_charge
    from {{ ref('fact_patient_consumption') }}
    group by branch_key, month_start
),

unlinked_charges as (
    select c.branch_key as branch_key, toStartOfMonth(toDate(toString(c.delivery_date_key))) as month_start,
           count() as medication_charges_without_cost, sum(c.revenue_amount) as revenue_without_cost
    from {{ ref('fact_charge_line') }} as c
    where c.is_medication = 1 and c.revenue_amount != 0
      and c.charge_line_key not in (select charge_line_key from {{ ref('int_consumption_charge_link') }})
    group by branch_key, month_start
),

spine as (
    select branch_key, month_start from consumption
    union distinct
    select branch_key, month_start from unlinked_charges
)

select
    s.branch_key                                        as branch_key,
    s.month_start                                       as month_start,
    ifNull(c.patient_consumption_cost, 0)               as patient_consumption_cost,
    ifNull(c.linked_consumption_cost, 0)                as linked_consumption_cost,
    ifNull(c.linked_consumption_cost_oasis, 0)          as linked_consumption_cost_oasis,
    ifNull(c.linked_revenue, 0)                         as linked_revenue,
    ifNull(c.linked_revenue, 0) - ifNull(c.linked_consumption_cost, 0) as linked_margin,
    ifNull(c.sale_lines_without_charge, 0)              as sale_lines_without_charge,
    ifNull(c.cost_without_charge, 0)                    as cost_without_charge,
    ifNull(u.medication_charges_without_cost, 0)        as medication_charges_without_cost,
    ifNull(u.revenue_without_cost, 0)                   as revenue_without_cost
from spine as s
left join consumption as c on c.branch_key = s.branch_key and c.month_start = s.month_start
left join unlinked_charges as u on u.branch_key = s.branch_key and u.month_start = s.month_start
{{ hnh_settings() }}
