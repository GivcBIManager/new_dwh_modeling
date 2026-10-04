{{ config(order_by='(branch_key, request_date_key, preauth_line_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}
{% set null_s = "cast(null as Nullable(String))" %}
{% set approved_set = "('Approved', 'Partially approved', 'Not required')" %}

with lines as (
    select * from {{ ref('int_preauth_line') }}
    where requested_at >= {{ first_at }} and toDate(requested_at) <= {{ last_day }}
),

deliveries as (
    -- Latest live delivery per episode and service: delivered after a request
    -- exactly when this date is on or after the request date.
    select branch_key, episode_key, service_key, max(delivery_date_key) as last_delivery_date_key
    from {{ ref('fact_charge_line') }}
    where charge_status = 'Live'
    group by branch_key, episode_key, service_key
),

keyed as (
    select
        l.*,
        toInt32(toYYYYMMDD(assumeNotNull(l.requested_at)))                      as request_date_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.line_natural_id']) }}           as preauth_line_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.patient_id', 'l.episode_no']) }} as episode_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.patient_id']) }}                as patient_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.ios']) }}                       as service_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.requesting_staff_id']) }}       as staff_key_raw,
        coalesce(l.purchaser_code, ep.purchaser_code, toInt64(9999))            as payer_purchaser_code,
        ifNull(ep.care_type, 'Unknown')                                         as care_type,
        {{ hnh_preauth_outcome('l.nphies_final_status', null_s, null_s) }}      as nphies_outcome,
        {{ hnh_preauth_outcome('l.nphies_first_status', null_s, null_s) }}      as nphies_first_outcome
    from lines as l
    left join (select branch_id, patient_id, episode_no, care_type, purchaser_code from {{ ref('int_episode') }}) as ep
        on ep.branch_id = l.branch_id and ep.patient_id = l.patient_id and ep.episode_no = l.episode_no
)

select
    k.preauth_line_key                                         as preauth_line_key,
    k.branch_id                                                as branch_key,
    k.request_date_key                                         as request_date_key,
    {{ hnh_date_key_in_range('k.first_sent_at') }}             as first_sent_date_key,
    {{ hnh_date_key_in_range('k.final_responded_at') }}        as final_response_date_key,
    k.episode_key                                              as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                        as patient_key,
    ifNull(ds.staff_key, toInt64(-1))                          as requesting_staff_key,
    ifNull(dsv.service_key, toInt64(-1))                       as service_key,
    ifNull(dpy.payer_key, toInt64(-1))                         as payer_key,
    {{ hnh_care_type_key('k.care_type') }}                     as care_type_key,
    {{ hnh_preauth_outcome_key('k.preauth_outcome') }}         as preauth_outcome_key,
    toUInt8(k.preauth_outcome in {{ approved_set }})           as is_approved,
    toUInt8(k.nphies_final_status is not null
            and k.nphies_outcome in ('Approved', 'Partially approved', 'Not required', 'Rejected')) as has_final_response,
    toUInt8(k.nphies_first_outcome = 'Approved')               as is_first_response_approved,
    toUInt8(k.request_send_count > 1)                          as is_resubmitted,
    toUInt8((k.authorised_flag = 'Y' and k.nphies_outcome = 'Rejected')
            or (k.authorised_flag = 'R' and k.nphies_outcome in {{ approved_set }})) as is_status_override,
    toUInt8(ifNull(dv.last_delivery_date_key, 0) >= k.request_date_key)          as is_delivered,
    toUInt8(k.preauth_outcome = 'Approved' and is_delivered = 0)                as is_approved_not_delivered,
    toUInt8(k.preauth_outcome = 'Rejected' and is_delivered = 1)                as is_delivered_not_approved,
    if(ifNull(k.requested_qty, 0) > 0, k.estimated_amount / k.requested_qty * k.approved_qty, null) as approved_estimated_amount,
    {{ hnh_minutes_between('k.requested_at', 'k.first_sent_at') }}              as request_to_sent_minutes,
    dateDiff('minute', k.requested_at, k.first_sent_at)                         as request_to_sent_minutes_raw,
    {{ hnh_minutes_between('k.first_sent_at', 'k.final_responded_at') }}        as sent_to_response_minutes,
    dateDiff('minute', k.first_sent_at, k.final_responded_at)                   as sent_to_response_minutes_raw,
    {{ hnh_minutes_between('k.requested_at', 'k.final_responded_at') }}         as total_turnaround_minutes,
    dateDiff('minute', k.requested_at, k.final_responded_at)                    as total_turnaround_minutes_raw,
    -- old report: first sent to the last response of any kind
    dateDiff('minute', k.first_sent_at, k.last_responded_at)                    as legacy_sent_to_response_minutes,
    k.* except (branch_id, patient_id, episode_no, ios, requesting_staff_id, purchaser_code,
                request_date_key, preauth_line_key, episode_key, patient_key_raw, service_key_raw,
                staff_key_raw, care_type, nphies_first_outcome),
    now()                                                      as _loaded_at
from keyed as k
left join deliveries as dv
    on dv.branch_key = k.branch_id and dv.episode_key = k.episode_key and dv.service_key = k.service_key_raw
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.staff_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = k.service_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy
    on dpy.payer_key = {{ hnh_surrogate_key(['k.branch_id', 'k.payer_purchaser_code']) }}
{{ hnh_settings() }}
