{{ config(order_by='(branch_key, order_date_key, order_line_key)') }}

with keyed as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'order_line']) }}                as order_line_key,
        {{ hnh_surrogate_key(['branch_id', 'master_order_no']) }}           as order_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id', 'episode_no']) }}  as episode_key,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}                as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'orderer_staff_id']) }}          as staff_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'order_work_entity']) }}         as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'ios']) }}                       as service_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'product_category_code']) }}     as product_category_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'episode_purchaser_code']) }}    as payer_key_raw
    from {{ ref('int_order_line') }}
)

select
    k.order_line_key                                        as order_line_key,
    k.order_key                                             as order_key,
    k.branch_id                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(toDate(k.order_at))))  as order_date_key,
    {{ hnh_time_key('k.order_at') }}                        as order_time_key,
    {{ hnh_date_key_in_range('k.first_delivered_at') }}     as first_delivery_date_key,
    ifNull(dp.patient_key, toInt64(-1))                     as patient_key,
    k.episode_key                                           as episode_key,
    ifNull(dpy.payer_key, toInt64(-1))                      as payer_key,
    ifNull(ds.staff_key, toInt64(-1))                       as ordering_staff_key,
    ifNull(dd.department_key, toInt64(-1))                  as ordering_department_key,
    ifNull(dsv.service_key, toInt64(-1))                    as service_key,
    ifNull(dpc.product_category_key, toInt64(-1))           as product_category_key,
    {{ hnh_care_type_key('k.care_type') }}                  as care_type_key,
    k.master_order_no                                       as master_order_no,
    k.order_line                                            as order_line,
    k.order_category                                        as order_category,
    k.line_status                                           as line_status,
    k.fulfilment_status                                     as fulfilment_status,
    k.status_reason                                         as status_reason,
    k.generic_name                                          as generic_name,
    k.urgency_code                                          as urgency_code,
    k.is_alternative                                        as is_alternative,
    k.is_excluded_package                                   as is_excluded_package,
    k.is_inpatient                                          as is_inpatient,
    k.is_in_leak_scope                                      as is_in_leak_scope,
    k.is_lost                                               as is_lost,
    k.is_partially_delivered                                as is_partially_delivered,
    k.units_ordered                                         as units_ordered,
    k.units_delivered                                       as units_delivered,
    k.ordered_value                                         as ordered_value,
    k.charged_amount                                        as charged_amount,
    k.live_charge_count                                     as live_charge_count,
    k.order_to_delivery_minutes                             as order_to_delivery_minutes,
    k.legacy_status                                         as legacy_status,
    k.legacy_in_scope                                       as legacy_in_scope,
    k.legacy_is_lost                                        as legacy_is_lost,
    now()                                                   as _loaded_at
from keyed as k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.staff_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = k.department_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = k.service_key_raw
left join (select product_category_key from {{ ref('dim_product_category') }}) as dpc
    on dpc.product_category_key = k.product_category_key_raw
{{ hnh_settings() }}
