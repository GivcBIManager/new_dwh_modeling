{{ config(order_by='(branch_key, invoice_date_key, invoice_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with invoices as (
    select * from {{ ref('stg_oasis__episode_invoices') }}
    where created_at >= {{ first_at }} and toDate(created_at) <= {{ last_day }}
),

approval_codes as (
    -- Code type 5116 is matched on user_code; identical in all eight branches.
    select branch_id, assumeNotNull(user_code) as user_code, any(description) as description
    from {{ ref('int_code_decode') }}
    where code_type = 5116 and user_code is not null
    group by branch_id, user_code
),

enriched as (
    select
        i.branch_id            as branch_id,
        i.invoice_no           as invoice_no,
        i.created_at           as created_at,
        i.service_start_at     as service_start_at,
        i.service_end_at       as service_end_at,
        i.account_code         as account_code,
        i.patient_id           as patient_id,
        i.episode_no           as episode_no,
        i.attendance_type      as attendance_type,
        i.gross_amount         as gross_amount,
        i.discount_amount      as discount_amount,
        i.net_amount           as net_amount,
        i.vat_amount           as vat_amount,
        i.total_amount         as total_amount,
        i.stat_invoice_no      as stat_invoice_no,
        i.approval_status_code as approval_status_code,
        i.claim_type           as claim_type,
        s.statement_end_at     as statement_end_at,
        s.statement_sent_at    as statement_sent_at,
        s.approved_at          as statement_approved_at,
        s.approved_by          as approved_by,
        s.cancelled_flag       as cancelled_flag,
        ac.description         as approval_status,
        cs.submission_status   as submission_status,
        cs.validation_status   as validation_status,
        py.purchaser_code      as purchaser_code,
        ep.care_type           as episode_care_type
    from invoices as i
    left join {{ ref('stg_oasis__invoice_statements') }} as s
        on s.branch_id = i.branch_id and s.stat_invoice_no = i.stat_invoice_no
    left join approval_codes as ac
        on ac.branch_id = i.branch_id and ac.user_code = i.approval_status_code
    left join {{ ref('stg_ref__claim_status') }} as cs
        on lower(cs.detailed_status) = lower(ac.description)
    left join {{ ref('int_invoice_payer') }} as py
        on py.branch_id = i.branch_id and py.account_code = i.account_code
    left join (select branch_id, patient_id, episode_no, care_type from {{ ref('int_episode') }}) as ep
        on ep.branch_id = i.branch_id and ep.patient_id = i.patient_id and ep.episode_no = i.episode_no
)

select
    {{ hnh_surrogate_key(['e.branch_id', 'e.invoice_no']) }}                 as invoice_key,
    e.branch_id                                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(e.created_at)))                        as invoice_date_key,
    {{ hnh_date_key_in_range('e.service_start_at') }}                       as service_start_date_key,
    {{ hnh_date_key_in_range('e.service_end_at') }}                         as service_end_date_key,
    {{ hnh_date_key_in_range('e.statement_end_at') }}                       as statement_end_date_key,
    {{ hnh_date_key_in_range('e.statement_sent_at') }}                      as statement_sent_date_key,
    {{ hnh_date_key_in_range('e.statement_approved_at') }}                  as statement_approved_date_key,
    {{ hnh_surrogate_key(['e.branch_id', 'e.patient_id', 'e.episode_no']) }} as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                                     as patient_key,
    ifNull(dpy.payer_key, toInt64(-1))                                      as payer_key,
    {{ hnh_care_type_key(hnh_charge_care_type('e.episode_care_type', 'e.attendance_type')) }} as care_type_key,
    e.invoice_no                                                            as invoice_no,
    e.stat_invoice_no                                                       as stat_invoice_no,
    e.account_code                                                          as account_code,
    e.purchaser_code                                                        as purchaser_code,
    e.gross_amount                                                          as gross_amount,
    e.discount_amount                                                       as discount_amount,
    e.net_amount                                                            as net_amount,
    e.vat_amount                                                            as vat_amount,
    e.total_amount                                                          as total_amount,
    e.approval_status_code                                                  as approval_status_code,
    ifNull(e.approval_status, if(e.approval_status_code is null, 'Not set', 'Unknown')) as approval_status,
    ifNull(e.submission_status, 'New')                                      as submission_status,
    ifNull(e.validation_status, 'New')                                      as validation_status,
    toUInt8(e.approval_status_code is null or e.submission_status is not null) as is_submission_status_mapped,
    toUInt8(e.approved_by is not null)                                      as is_verified,
    toUInt8(e.statement_sent_at is not null)                                as is_sent,
    toUInt8(e.cancelled_flag = 'Y')                                         as is_cancelled_statement,
    e.claim_type                                                            as claim_type,
    toUInt8(e.approved_by is not null)                                      as legacy_is_verified,
    now()                                                                   as _loaded_at
from enriched as e
left join (select patient_key from {{ ref('dim_patient') }}) as dp
    on dp.patient_key = {{ hnh_surrogate_key(['e.branch_id', 'e.patient_id']) }}
left join (select payer_key from {{ ref('dim_payer') }}) as dpy
    on dpy.payer_key = {{ hnh_surrogate_key(['e.branch_id', 'e.purchaser_code']) }}
{{ hnh_settings() }}
