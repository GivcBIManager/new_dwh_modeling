{{ config(order_by='(branch_key, movement_key, charge_line_key)') }}

-- One row per patient-sale or patient-return line of fact_stock_movement and live charge line it links to: the one
-- link read by fact_patient_consumption and rec_consumption_charge_monthly. The line links through its Oasis invoice
-- line: docl.doc_no = delivery_charge.invoice_no and the line's product = the delivery line's product (spec F9). A
-- superseded charge row still names its delivery line, so the link goes invoice + product -> delivery line (any charge
-- row) -> the live charge lines of that delivery line in fact_charge_line (plan refinement). Each charge line's revenue
-- owner is the linked patient-sale line with the lowest Oasis line id; returns link but own no revenue.
with sales as (
    -- patient lines with their Oasis invoice line (both sides are cut to the needed rows and columns before joining)
    select movement_key, branch_key, movement_type as link_movement_type, assumeNotNull(oasis_line_id) as link_line_id,
           assumeNotNull(oasis_doc_no) as link_doc_no, assumeNotNull(oasis_product_code) as link_product_code
    from {{ ref('fact_stock_movement') }}
    where movement_type in ('Patient sale', 'Patient return')
      and oasis_line_id is not null and oasis_doc_no is not null and oasis_product_code is not null
),

invoice_lines as (
    select c.branch_id as branch_id, assumeNotNull(c.invoice_doc_no) as invoice_doc_no,
           assumeNotNull(d.product_code) as product_code, assumeNotNull(c.delivery_line) as delivery_line
    from {{ ref('stg_oasis__charges') }} as c
    inner join (select branch_id, delivery_line, product_code from {{ ref('stg_oasis__delivery_lines') }}
                where product_code is not null) as d
        on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
    where c.invoice_doc_no is not null and c.delivery_line is not null
      and (c.branch_id, c.invoice_doc_no) in (select branch_key, link_doc_no from sales)
    group by c.branch_id, c.invoice_doc_no, d.product_code, c.delivery_line
),

links as (
    select s.movement_key as movement_key, s.branch_key as branch_key, s.link_movement_type as link_movement_type,
           s.link_line_id as link_line_id, ch.charge_line_key as charge_line_key
    from sales as s
    inner join invoice_lines as il
        on il.branch_id = s.branch_key and il.invoice_doc_no = s.link_doc_no and il.product_code = s.link_product_code
    inner join (select charge_line_key, branch_key, assumeNotNull(delivery_line) as delivery_line
                from {{ ref('fact_charge_line') }} where delivery_line is not null) as ch
        on ch.branch_key = il.branch_id and ch.delivery_line = il.delivery_line
),

owned as (
    -- one pass over the links (a CTE read twice is computed twice): the revenue owner per charge line is the linked
    -- patient-sale line with the lowest Oasis line id
    select movement_key, branch_key, charge_line_key, link_movement_type,
           argMinIf(movement_key, link_line_id, link_movement_type = 'Patient sale')
               over (partition by charge_line_key) as owner_movement_key
    from links
)

select
    movement_key                                        as movement_key,
    branch_key                                          as branch_key,
    charge_line_key                                     as charge_line_key,
    toUInt8(link_movement_type = 'Patient sale' and owner_movement_key = movement_key) as is_revenue_owner
from owned
