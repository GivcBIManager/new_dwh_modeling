{{ config(order_by='(branch_id, order_line)') }}

with base as (
    select * from {{ ref('int_order_line_base') }}
),

alternatives as (
    -- Lines ordered as an alternative to another line, per original line.
    select
        branch_id,
        assumeNotNull(original_order_line)  as original_line,
        count()                             as alternative_lines,
        max(has_live_charge)                as charged_alternatives
    from base
    where original_order_line is not null
    group by branch_id, original_line
),

generics as (
    -- Lines of the same generic within one episode, and how many of them were charged.
    select
        branch_id, patient_id, episode_no, generic_id,
        count()                 as generic_lines,
        sum(has_live_charge)    as charged_generic_lines
    from base
    where generic_id is not null and patient_id is not null and episode_no is not null
    group by branch_id, patient_id, episode_no, generic_id
),

legacy_names as (
    -- Old report: pharmacy lines of one episode with the same generic NAME (blank matches blank).
    -- The old DAX ran over an import that had already dropped statuses P/Q/X/Cancelled and inpatient care.
    select
        branch_id, patient_id, episode_no,
        ifNull(generic_name, '')    as name_key,
        count()                     as name_lines
    from base
    where {{ hnh_order_category('product_category_code') }} = 'Pharmacy'
      and ifNull(line_status_code, '') not in ('P', 'Q', 'X', 'C')
      and care_type != 'IP'
      and patient_id is not null and episode_no is not null
    group by branch_id, patient_id, episode_no, name_key
)

select
    b.branch_id                                         as branch_id,
    b.order_line                                        as order_line,
    b.master_order_no                                   as master_order_no,
    b.patient_id                                        as patient_id,
    b.episode_no                                        as episode_no,
    b.admission_no                                      as admission_no,
    b.orderer_staff_id                                  as orderer_staff_id,
    b.order_work_entity                                 as order_work_entity,
    b.ios                                               as ios,
    b.generic_id                                        as generic_id,
    b.generic_name                                      as generic_name,
    b.order_at                                          as order_at,
    b.urgency_code                                      as urgency_code,
    b.status_reason                                     as status_reason,
    b.original_order_line                               as original_order_line,
    b.product_category_code                             as product_category_code,
    b.care_type                                         as care_type,
    b.episode_purchaser_code                            as episode_purchaser_code,
    b.units_ordered                                     as units_ordered,
    b.units_delivered                                   as units_delivered,
    b.std_price                                         as std_price,
    b.units_ordered * b.std_price                       as ordered_value,
    b.charged_amount                                    as charged_amount,
    b.live_charge_count                                 as live_charge_count,
    b.first_delivered_at                                as first_delivered_at,
    {{ hnh_order_category('b.product_category_code') }} as order_category,
    -- PK products are out of leak scope unless listed as an included package.
    toUInt8(order_category = 'Package' and ifNull(pk.package_description, '') = '') as is_excluded_package,
    toUInt8(b.care_type = 'IP')                         as is_inpatient,
    toUInt8(b.original_order_line is not null)          as is_alternative,
    {{ hnh_order_line_status('b.line_status_code') }}   as line_status,
    toUInt8(ifNull(a.charged_alternatives, 0) = 1)      as has_charged_alternative,
    -- Pharmacy only: another line of the same generic in the same episode was charged.
    toUInt8(order_category = 'Pharmacy' and b.has_live_charge = 0
            and ifNull(gl.charged_generic_lines, 0) > 0) as has_charged_substitute,
    {{ hnh_order_fulfilment_status('line_status', 'b.has_live_charge', 'has_charged_alternative', 'has_charged_substitute') }} as fulfilment_status,
    -- Delivered-status lines with negative units are reversal/credit lines, not orders that leaked.
    toUInt8(line_status in ('Delivered', 'Ordered') and is_excluded_package = 0 and b.units_ordered > 0) as is_in_leak_scope,
    toUInt8(is_in_leak_scope = 1 and fulfilment_status = 'Undelivered')          as is_lost,
    -- tolerance: insurer tier rows summing to fractions leave float noise
    toUInt8(b.has_live_charge = 1 and b.units_delivered < b.units_ordered - 0.0001) as is_partially_delivered,
    -- Per-line fill rate capped at 1; the sum of units is distorted by ml/mg-unit lines (units_ordered in the thousands).
    if(b.units_ordered > 0, least(b.units_delivered / b.units_ordered, 1), cast(null as Nullable(Float64))) as unit_fulfilment_ratio,
    toUInt8(b.units_ordered > 1000)                     as is_unit_outlier,
    if(b.first_delivered_at is null or b.order_at is null, cast(null as Nullable(Int64)),
       dateDiff('minute', b.order_at, b.first_delivered_at))                     as order_to_delivery_minutes,
    -- old mv_orders_fulfillment + report: any alternative relation or a duplicated generic counted as delivered
    if(b.has_live_charge = 1 or b.original_order_line is not null or ifNull(a.alternative_lines, 0) > 0
       or (order_category = 'Pharmacy' and ifNull(ln.name_lines, 0) > 1),
       'Delivered', 'Undelivered')                                               as legacy_status,
    toUInt8(ifNull(b.line_status_code, '') not in ('P', 'Q', 'X', 'C')
            and is_excluded_package = 0 and b.care_type != 'IP')                 as legacy_in_scope,
    toUInt8(legacy_in_scope = 1 and legacy_status = 'Undelivered')               as legacy_is_lost
from base as b
left join alternatives as a on a.branch_id = b.branch_id and a.original_line = b.order_line
left join generics as gl
    on gl.branch_id = b.branch_id and gl.patient_id = b.patient_id
   and gl.episode_no = b.episode_no and gl.generic_id = b.generic_id
left join legacy_names as ln
    on ln.branch_id = b.branch_id and ln.patient_id = b.patient_id
   and ln.episode_no = b.episode_no and ln.name_key = ifNull(b.generic_name, '')
left join (select distinct package_description from {{ ref('stg_ref__order_fulfilment_packages') }}) as pk
    on pk.package_description = b.service_description_upper
{{ hnh_settings() }}
