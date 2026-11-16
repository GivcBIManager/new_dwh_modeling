{{ config(order_by='(branch_id, order_line)') }}

-- The visit an order line belongs to, keyed like fact_encounter.encounter_key.
-- 1. hl7_encounter on the order: prefix O / E / I and the encounter id, when that encounter exists for the order's patient.
-- 2. Otherwise the encounter of the line's earliest live charge whose encounter resolved (hl7 prefix X never matches).
-- 3. Otherwise -1.
with lines as (
    select branch_id, order_line, master_order_no, patient_id
    from {{ ref('int_order_line') }}
),

orders as (
    select branch_id, master_order_no, any(hl7_encounter) as hl7_encounter
    from {{ ref('stg_oasis__orders') }}
    group by branch_id, master_order_no
),

encounters as (
    select
        branch_id, encounter_type, source_id, patient_id,
        {{ hnh_surrogate_key(['branch_id', 'encounter_type', 'source_id']) }} as encounter_key
    from {{ ref('int_encounter') }}
    where patient_id is not null
),

charge_orders as (
    -- earliest live charge with a resolved encounter, per order line
    select
        c.branch_id                                                          as branch_id,
        d.order_line                                                         as order_line,
        argMin(c.encounter_key, tuple(c.delivery_date_key, c.delivery_time_key, c.charge_line_key)) as encounter_key
    from (
        select toUInt8(branch_key) as branch_id, delivery_line, encounter_key,
               delivery_date_key, delivery_time_key, charge_line_key
        from {{ ref('fact_charge_line') }}
        where charge_status = 'Live' and resolved_encounter_type is not null and delivery_line is not null
    ) as c
    inner join (
        select branch_id, delivery_line, assumeNotNull(order_line) as order_line
        from {{ ref('stg_oasis__delivery_lines') }}
        where order_line is not null
    ) as d on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
    group by c.branch_id, d.order_line
),

parsed as (
    select
        l.branch_id                                         as branch_id,
        l.order_line                                        as order_line,
        l.patient_id                                        as patient_id,
        multiIf(startsWith(ifNull(o.hl7_encounter, ''), 'O'), 'OP',
                startsWith(ifNull(o.hl7_encounter, ''), 'E'), 'ER',
                startsWith(ifNull(o.hl7_encounter, ''), 'I'), 'IP',
                cast(null as Nullable(String)))             as hl7_type,
        toInt64OrNull(substring(ifNull(o.hl7_encounter, ''), 2)) as hl7_id
    from lines as l
    left join orders as o on o.branch_id = l.branch_id and o.master_order_no = l.master_order_no
)

select
    p.branch_id                                             as branch_id,
    p.order_line                                            as order_line,
    multiIf(e.encounter_key is not null, e.encounter_key,
            co.encounter_key is not null, co.encounter_key,
            toInt64(-1))                                    as encounter_key,
    multiIf(e.encounter_key is not null, 'order',
            co.encounter_key is not null, 'charge',
            'none')                                         as encounter_source
from parsed as p
left join encounters as e
    on e.branch_id = p.branch_id and e.encounter_type = p.hl7_type
   and e.source_id = p.hl7_id and e.patient_id = p.patient_id
left join charge_orders as co on co.branch_id = p.branch_id and co.order_line = p.order_line
{{ hnh_settings() }}
