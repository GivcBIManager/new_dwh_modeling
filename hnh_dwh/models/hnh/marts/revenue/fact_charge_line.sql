{{ config(order_by='(branch_key, delivery_date_key, charge_line_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with charges as (
    select
        branch_id, delivery_charge_id, delivery_line, delivered_at,
        assumeNotNull(toDate(delivered_at)) as delivery_day,
        patient_id, episode_no, encounter_id, encounter_type, staff_id, ios, purchaser_code,
        package_id, doc_id, invoice_doc_no, cancel_flag, cancel_reason_code, bill_to, package_deal_flag,
        attendance_type, product_category_code, units_delivered, price_paid_purchaser, discount_given,
        vat_value, updated_at
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= {{ first_at }} and toDate(delivered_at) <= {{ last_day }}
),

in_scope as (
    select c.*
    from charges as c
),

purchaser_lines as (
    -- Delivery lines with a live row billed to a purchaser. A patient-paid row on such a line is the
    -- co-pay (bill-to 3 for outpatients, 2 for inpatients).
    select branch_id, delivery_line, min(purchaser_code) as sibling_purchaser_code
    from in_scope
    where cancel_flag is null and bill_to = '1' and delivery_line is not null
    group by branch_id, delivery_line
),

lines as (
    select
        c.branch_id                 as branch_id,
        c.delivery_charge_id        as delivery_charge_id,
        c.delivery_line             as delivery_line,
        c.delivered_at              as delivered_at,
        c.delivery_day              as delivery_day,
        c.patient_id                as patient_id,
        c.episode_no                as episode_no,
        c.encounter_id              as encounter_id,
        c.encounter_type            as encounter_type,
        c.staff_id                  as staff_id,
        c.ios                       as ios,
        c.purchaser_code            as purchaser_code,
        c.package_id                as package_id,
        c.doc_id                    as doc_id,
        c.invoice_doc_no            as invoice_doc_no,
        c.cancel_flag               as cancel_flag,
        c.cancel_reason_code        as cancel_reason_code,
        c.bill_to                   as bill_to,
        c.package_deal_flag         as package_deal_flag,
        c.attendance_type           as attendance_type,
        c.product_category_code     as product_category_code,
        c.units_delivered           as units_delivered,
        c.price_paid_purchaser      as price_paid_purchaser,
        c.discount_given            as discount_given,
        c.vat_value                 as vat_value,
        toUInt8(pl.delivery_line is not null) as has_purchaser_sibling,
        pl.sibling_purchaser_code   as sibling_purchaser_code,
        md.work_entity              as work_entity
    from in_scope as c
    left join purchaser_lines as pl
        on pl.branch_id = c.branch_id and pl.delivery_line = c.delivery_line
    left join (
        select branch_id, delivery_line, master_delivery_no from {{ ref('stg_oasis__delivery_lines') }}
    ) as dl on dl.branch_id = c.branch_id and dl.delivery_line = c.delivery_line
    left join {{ ref('stg_oasis__master_deliveries') }} as md
        on md.branch_id = dl.branch_id and md.master_delivery_no = dl.master_delivery_no
    -- Only superseded (R) rows are left out; unexpected flags are kept with status Unknown.
    where c.cancel_flag is null or c.cancel_flag != 'R'
),

encounter_lookup as (
    -- The Oasis encounter id is an appointment id, admission number or ER visit id (Oasis view
    -- PATIENT_VALID_ENCOUNTERS). The same patient is required, so a number used by two of those
    -- tables cannot link another patient's encounter.
    select branch_id, source_id, patient_id, groupUniqArray(encounter_type) as encounter_types
    from {{ ref('int_encounter') }}
    group by branch_id, source_id, patient_id
),

resolved as (
    select
        l.*,
        multiIf(
            l.attendance_type = 'I', if(has(el.encounter_types, 'IP'), 'IP', null),
            l.encounter_type = 'E',  if(has(el.encounter_types, 'ER'), 'ER', null),
            l.encounter_type = 'O',  if(has(el.encounter_types, 'OP'), 'OP', null),
            has(el.encounter_types, 'OP'), 'OP',
            has(el.encounter_types, 'ER'), 'ER',
            null)                                                 as resolved_encounter_type,
        -- On outpatient charges admission_no holds the encounter id, so the admission is taken
        -- only from a resolved inpatient encounter.
        if(resolved_encounter_type = 'IP', l.encounter_id, cast(null as Nullable(Int64))) as resolved_admission_no
    from lines as l
    left join encounter_lookup as el
        on el.branch_id = l.branch_id and el.source_id = l.encounter_id and el.patient_id = l.patient_id
),

keyed as (
    select
        -- Named explicitly: with two joins ClickHouse names r.* columns that clash with a joined
        -- table's columns as r.<name>, which the next CTE cannot resolve.
        r.* except (branch_id, patient_id, episode_no, purchaser_code),
        r.branch_id as branch_id, r.patient_id as patient_id, r.episode_no as episode_no,
        r.purchaser_code as purchaser_code,
        ep.care_type                                              as episode_care_type,
        ifNull(ep.purchaser_code, toInt64(9999))                  as episode_purchaser_code,
        toUInt8(ifNull(ad.is_ltc, 0) = 1 or ifNull(ad.is_ltc_to_date, 0) = 1) as is_ltc,
        {{ hnh_charge_care_type('ep.care_type', 'r.attendance_type') }}       as care_type,
        {{ hnh_billed_purchaser('r.bill_to', 'r.purchaser_code', 'r.has_purchaser_sibling') }} as billed_purchaser_code,
        {{ hnh_surrogate_key(['r.branch_id', 'r.delivery_charge_id']) }}      as charge_line_key,
        {{ hnh_surrogate_key(['r.branch_id', 'r.patient_id', 'r.episode_no']) }} as episode_key,
        {{ hnh_surrogate_key(['r.branch_id', 'r.resolved_encounter_type', 'r.encounter_id']) }} as encounter_key,
        {{ hnh_surrogate_key(['r.branch_id', 'r.resolved_admission_no']) }}   as admission_key,
        {{ hnh_surrogate_key(['r.branch_id', 'r.patient_id']) }}              as patient_key_raw,
        {{ hnh_surrogate_key(['r.branch_id', 'r.staff_id']) }}                as staff_key_raw,
        {{ hnh_surrogate_key(['r.branch_id', 'r.work_entity']) }}             as department_key_raw,
        {{ hnh_surrogate_key(['r.branch_id', 'r.ios']) }}                     as service_key_raw,
        {{ hnh_surrogate_key(['r.branch_id', 'r.product_category_code']) }}   as product_category_key_raw
    from resolved as r
    left join (select branch_id, patient_id, episode_no, care_type, purchaser_code from {{ ref('int_episode') }}) as ep
        on ep.branch_id = r.branch_id and ep.patient_id = r.patient_id and ep.episode_no = r.episode_no
    left join (select branch_id, admission_no, is_ltc, is_ltc_to_date from {{ ref('int_admission') }}) as ad
        on ad.branch_id = r.branch_id and ad.admission_no = r.resolved_admission_no
),

with_payers as (
    select
        k.*,
        {{ hnh_surrogate_key(['k.branch_id', 'k.billed_purchaser_code']) }}  as billed_payer_key_raw,
        {{ hnh_surrogate_key(['k.branch_id', 'k.episode_purchaser_code']) }} as episode_payer_key_raw
    from keyed as k
)

select
    w.charge_line_key                                   as charge_line_key,
    w.branch_id                                         as branch_key,
    toInt32(toYYYYMMDD(w.delivery_day))                 as delivery_date_key,
    {{ hnh_time_key('w.delivered_at') }}                as delivery_time_key,
    w.episode_key                                       as episode_key,
    w.encounter_key                                     as encounter_key,
    w.admission_key                                     as admission_key,
    ifNull(dp.patient_key, toInt64(-1))                 as patient_key,
    ifNull(ds.staff_key, toInt64(-1))                   as staff_key,
    ifNull(dd.department_key, toInt64(-1))              as department_key,
    ifNull(dsv.service_key, toInt64(-1))                as service_key,
    ifNull(dpc.product_category_key, toInt64(-1))       as product_category_key,
    ifNull(dbp.payer_key, toInt64(-1))                  as billed_payer_key,
    ifNull(dep.payer_key, toInt64(-1))                  as episode_payer_key,
    {{ hnh_care_type_key('w.care_type') }}              as care_type_key,
    w.delivery_charge_id                                as delivery_charge_id,
    w.delivery_line                                     as delivery_line,
    w.encounter_id                                      as encounter_id,
    w.encounter_type                                    as encounter_type,
    w.resolved_encounter_type                           as resolved_encounter_type,
    w.resolved_admission_no                             as admission_no,
    w.invoice_doc_no                                    as invoice_doc_no,
    w.package_id                                        as package_id,
    w.bill_to                                           as bill_to,
    w.billed_purchaser_code                             as billed_purchaser_code,
    w.episode_purchaser_code                            as episode_purchaser_code,
    {{ hnh_charge_status('w.cancel_flag') }}            as charge_status,
    w.cancel_reason_code                                as cancel_reason_code,
    toUInt8(ifNull(w.package_deal_flag, 'N') = 'Y')     as is_package_component,
    toUInt8(ifNull(w.bill_to, '') != '1' and w.has_purchaser_sibling = 1) as is_patient_share,
    toUInt8(ifNull(w.bill_to, '') = '3' and w.has_purchaser_sibling = 0) as is_cash_billed,
    {{ hnh_is_medication('w.product_category_code', 'dd.entity_type') }}  as is_medication,
    w.is_ltc                                            as is_ltc,
    w.units_delivered                                   as units,
    w.price_paid_purchaser                              as net_amount,
    w.discount_given                                    as line_discount_amount,
    w.price_paid_purchaser + w.discount_given           as gross_amount,
    w.vat_value                                         as vat_amount,
    {{ hnh_is_recognised_revenue('w.cancel_flag', 'w.package_deal_flag') }} as is_recognised_revenue,
    if(is_recognised_revenue = 1, w.price_paid_purchaser, 0)               as revenue_amount,
    if(w.cancel_flag is null and ifNull(w.package_deal_flag, 'N') = 'Y', w.price_paid_purchaser, 0) as package_content_amount,
    toUInt8(is_recognised_revenue = 1 and ifNull(w.bill_to, '') = '1')    as is_claimable,
    if(is_claimable = 1, w.price_paid_purchaser, 0)                        as claimable_amount,
    -- old mv_revenue_dataset: package N, cancel flag X (live), invoiced
    toUInt8(ifNull(w.package_deal_flag, 'N') = 'N' and w.cancel_flag is null and ifNull(w.doc_id, 0) != 0) as legacy_in_revenue,
    if(legacy_in_revenue = 1, w.price_paid_purchaser, 0)                   as legacy_revenue_amount,
    -- old TRANS_PURCHASER / PATIENT_PURCHASER: the co-pay is 8888 on one, the insurer on the other
    toInt64(if(ifNull(w.bill_to, '') != '1' and w.has_purchaser_sibling = 1, 8888, ifNull(w.purchaser_code, 9999))) as legacy_trans_purchaser,
    toInt64(multiIf(legacy_trans_purchaser = 9999 and dep.creditor = 'Cash Offers', w.episode_purchaser_code,
                    ifNull(w.bill_to, '') != '1' and w.has_purchaser_sibling = 1, ifNull(w.sibling_purchaser_code, 0),
                    legacy_trans_purchaser))           as legacy_patient_purchaser,
    multiIf(w.episode_care_type = 'OP', 'OP', w.episode_care_type = 'ER', 'ER', 'IP') as legacy_care_type,
    now()                                               as _loaded_at
from with_payers as w
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = w.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = w.staff_key_raw
left join (select department_key, entity_type from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = w.department_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = w.service_key_raw
left join (select product_category_key from {{ ref('dim_product_category') }}) as dpc on dpc.product_category_key = w.product_category_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dbp on dbp.payer_key = w.billed_payer_key_raw
left join (select payer_key, creditor from {{ ref('dim_payer') }}) as dep on dep.payer_key = w.episode_payer_key_raw
{{ hnh_settings() }}
