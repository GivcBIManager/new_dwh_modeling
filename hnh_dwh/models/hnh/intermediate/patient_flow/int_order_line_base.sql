{{ config(order_by='(branch_id, order_line)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with lines as (
    -- An order line with its header. The line's own order time wins; the header's fills the gap.
    select
        l.branch_id                                     as branch_id,
        l.order_line                                    as order_line,
        l.master_order_no                               as master_order_no,
        l.ios                                           as ios,
        l.generic_id                                    as generic_id,
        l.units_ordered                                 as units_ordered,
        l.std_price                                     as std_price,
        l.line_status_code                              as line_status_code,
        l.status_reason                                 as status_reason,
        l.original_order_line                           as original_order_line,
        l.urgent_flag                                   as urgency_code,
        l.order_work_entity                             as order_work_entity,
        coalesce(l.line_ordered_at, o.ordered_at)       as order_at,
        o.patient_id                                    as patient_id,
        o.episode_no                                    as episode_no,
        o.admission_no                                  as admission_no,
        o.orderer_staff_id                              as orderer_staff_id,
        o.attendance_type                               as attendance_type
    from {{ ref('stg_oasis__order_lines') }} as l
    left join (
        select branch_id, master_order_no, patient_id, episode_no, admission_no, orderer_staff_id,
               ordered_at, attendance_type
        from {{ ref('stg_oasis__orders') }}
    ) as o on o.branch_id = l.branch_id and o.master_order_no = l.master_order_no
    where order_at >= {{ first_at }} and toDate(order_at) <= {{ last_day }}
),

charge_lines as (
    -- One row per delivery line that has a live charge. A delivery line can carry several live
    -- rows: insurer tier rows (bill_to '1') that each hold part of the quantity, and a patient
    -- co-pay row (bill_to '2' or '3') that repeats a share of the same units. Units are the sum
    -- over the purchaser rows; with no purchaser row, the largest row. Amounts add up over all live rows.
    select
        c.branch_id                         as branch_id,
        d.order_line                        as order_line,
        c.delivery_line                     as delivery_line,
        count()                             as live_rows,
        if(countIf(c.bill_to = '1') > 0, sumIf(c.units_delivered, c.bill_to = '1'),
           max(c.units_delivered))          as line_units,
        sum(c.price_paid_purchaser)         as line_amount,
        min(c.delivered_at)                 as line_first_at
    from (
        select branch_id, assumeNotNull(delivery_line) as delivery_line, units_delivered,
               price_paid_purchaser, delivered_at, bill_to
        from {{ ref('stg_oasis__charges') }}
        where cancel_flag is null and delivery_line is not null and delivered_at >= {{ first_at }}
    ) as c
    inner join (
        select branch_id, delivery_line, assumeNotNull(order_line) as order_line
        from {{ ref('stg_oasis__delivery_lines') }}
        where order_line is not null
    ) as d on d.branch_id = c.branch_id and d.delivery_line = c.delivery_line
    group by c.branch_id, d.order_line, c.delivery_line
),

line_delivery as (
    select
        branch_id, order_line,
        sum(live_rows)          as live_charge_count,
        sum(line_units)         as units_delivered,
        sum(line_amount)        as charged_amount,
        min(line_first_at)      as first_delivered_at
    from charge_lines
    group by branch_id, order_line
),

ios_info as (
    select
        m.branch_id                                                     as branch_id,
        m.ios                                                           as ios,
        coalesce(m.product_category_code, si.product_category_code)     as product_category_code,
        nullIf(upper(trimBoth(ifNull(si.description, ''))), '')         as service_description_upper
    from {{ ref('stg_oasis__ios_master') }} as m
    left join {{ ref('stg_oasis__service_items') }} as si
        on si.branch_id = m.branch_id and si.ios_main = m.ios_main
)

select
    l.branch_id                                         as branch_id,
    l.order_line                                        as order_line,
    l.master_order_no                                   as master_order_no,
    l.patient_id                                        as patient_id,
    l.episode_no                                        as episode_no,
    l.admission_no                                      as admission_no,
    l.orderer_staff_id                                  as orderer_staff_id,
    l.order_work_entity                                 as order_work_entity,
    l.ios                                               as ios,
    l.generic_id                                        as generic_id,
    g.generic_name                                      as generic_name,
    l.order_at                                          as order_at,
    l.urgency_code                                      as urgency_code,
    l.status_reason                                     as status_reason,
    l.line_status_code                                  as line_status_code,
    l.original_order_line                               as original_order_line,
    l.units_ordered                                     as units_ordered,
    l.std_price                                         as std_price,
    ii.product_category_code                            as product_category_code,
    ii.service_description_upper                        as service_description_upper,
    -- The episode's care type; without a known episode, the order header's attendance type.
    if(ifNull(ep.care_type, 'Unknown') != 'Unknown', ifNull(ep.care_type, 'Unknown'),
       {{ hnh_care_type('l.attendance_type') }})        as care_type,
    ifNull(ep.purchaser_code, toInt64(9999))            as episode_purchaser_code,
    toUInt64(ifNull(ld.live_charge_count, 0))           as live_charge_count,
    toUInt8(ifNull(ld.live_charge_count, 0) > 0)        as has_live_charge,
    toFloat64(ifNull(ld.units_delivered, 0))            as units_delivered,
    toFloat64(ifNull(ld.charged_amount, 0))             as charged_amount,
    ld.first_delivered_at                               as first_delivered_at
from lines as l
left join line_delivery as ld on ld.branch_id = l.branch_id and ld.order_line = l.order_line
left join ios_info as ii on ii.branch_id = l.branch_id and ii.ios = l.ios
left join (select branch_id, generic_id, generic_name from {{ ref('stg_oasis__generics') }}) as g
    on g.branch_id = l.branch_id and g.generic_id = l.generic_id
left join (select branch_id, patient_id, episode_no, care_type, purchaser_code from {{ ref('int_episode') }}) as ep
    on ep.branch_id = l.branch_id and ep.patient_id = l.patient_id and ep.episode_no = l.episode_no
{{ hnh_settings() }}
