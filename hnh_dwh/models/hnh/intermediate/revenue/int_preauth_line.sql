{{ config(order_by='(branch_id, line_natural_id)') }}

{% set not_final = "('Pended', 'Error', 'Unknown', 'Not sent')" %}
{% set null_s = "cast(null as Nullable(String))" %}

with oasis_lines as (
    select
        a.branch_id          as branch_id,
        a.authorisation_no   as authorisation_no,
        a.request_no         as request_no,
        a.patient_id         as patient_id,
        a.episode_no         as episode_no,
        a.ios                as ios,
        a.requested_qty      as requested_qty,
        a.authorised_qty     as authorised_qty,
        a.used_qty           as used_qty,
        a.authorised_flag    as authorised_flag,
        a.amount_authorised  as amount_authorised,
        a.is_transfer        as is_transfer,
        a.com_req_id         as com_req_id,
        r.requested_at       as requested_at,
        r.request_status     as request_status
    from {{ ref('stg_oasis__authorisations') }} as a
    left join {{ ref('stg_oasis__authorisation_requests') }} as r
        on r.branch_id = a.branch_id and r.request_no = a.request_no
),

sent_items as (
    -- Each time an item went to NPHIES. An item with a known Oasis line belongs to that line
    -- (resubmissions collect there); otherwise it is its own line.
    select
        i.branch_id            as branch_id,
        i.request_item_id      as request_item_id,
        i.api_trans_id         as api_trans_id,
        i.item_no              as item_no,
        i.ios                  as item_ios,
        i.quantity             as quantity,
        i.estimated_cost       as estimated_cost,
        q.oasis_request_no     as oasis_request_no,
        q.patient_id           as patient_id,
        q.episode_no           as episode_no,
        q.purchaser_code       as purchaser_code,
        q.service_dept         as service_dept,
        q.physician_staff_id   as physician_staff_id,
        q.treatment_type       as treatment_type,
        q.diagnosis_code       as diagnosis_code,
        q.is_transfer          as is_transfer,
        q.sent_at              as sent_at,
        -- never null (the A branch needs a matched authorisation_no, the N branch an inner-joined
        -- api_trans_id); assumeNotNull keeps it out of Nullable so it can sit in the sorting key
        assumeNotNull(if(ol.authorisation_no is not null,
           concat('A', toString(i.authorisation_no)),
           concat('N', toString(i.api_trans_id), '-', ifNull(i.item_no, '')))) as line_natural_id
    from {{ ref('stg_oasis__preauth_api_request_items') }} as i
    inner join {{ ref('stg_oasis__preauth_api_requests') }} as q
        on q.branch_id = i.branch_id and q.api_trans_id = i.api_trans_id
    left join (select branch_id, authorisation_no from {{ ref('stg_oasis__authorisations') }}) as ol
        on ol.branch_id = i.branch_id and ol.authorisation_no = i.authorisation_no
),

sends as (
    select
        branch_id, line_natural_id,
        request_send_count, first_sent_at,
        tupleElement(latest, 1)  as oasis_request_no,
        tupleElement(latest, 2)  as patient_id,
        tupleElement(latest, 3)  as episode_no,
        tupleElement(latest, 4)  as item_ios,
        tupleElement(latest, 5)  as purchaser_code,
        tupleElement(latest, 6)  as service_dept,
        tupleElement(latest, 7)  as physician_staff_id,
        tupleElement(latest, 8)  as treatment_type,
        tupleElement(latest, 9)  as diagnosis_code,
        tupleElement(latest, 10) as quantity,
        tupleElement(latest, 11) as estimated_cost,
        tupleElement(latest, 12) as api_trans_id,
        tupleElement(latest, 13) as item_no,
        is_transfer
    from (
        select
            branch_id, line_natural_id,
            uniqExact(api_trans_id)  as request_send_count,
            min(sent_at)             as first_sent_at,
            max(is_transfer)         as is_transfer,
            argMax(tuple(oasis_request_no, patient_id, episode_no, item_ios, purchaser_code, service_dept,
                         physician_staff_id, treatment_type, diagnosis_code, quantity, estimated_cost,
                         api_trans_id, item_no),
                   tuple(ifNull(sent_at, toDateTime(0, 'Asia/Riyadh')), request_item_id)) as latest
        from sent_items
        group by branch_id, line_natural_id
    )
),

responses as (
    select
        s.branch_id                                    as branch_id,
        s.line_natural_id                              as line_natural_id,
        r.response_id                                  as response_id,
        r.responded_at                                 as responded_at,
        ifNull(r.responded_at, toDateTime(0, 'Asia/Riyadh')) as responded_sort,
        s.request_item_id                              as request_item_id,
        ifNull(ri.kept_response_item_id, 0)            as response_item_id,
        coalesce(tupleElement(ri.ri_t, 1), r.auth_status) as nphies_status,
        tupleElement(ri.ri_t, 3)                       as approved_amount,
        tupleElement(ri.ri_t, 2)                       as approved_quantity,
        tupleElement(ri.ri_t, 4)                       as payer_comment
    from sent_items as s
    inner join {{ ref('stg_oasis__preauth_api_responses') }} as r
        on r.branch_id = s.branch_id and r.api_trans_id = s.api_trans_id
    left join (
        -- response items are not unique on (response, item_no): keep the row with the highest id
        select
            branch_id, response_id, item_no,
            argMax(tuple(status, approved_quantity, approved_amount, payer_comment), response_item_id) as ri_t,
            max(response_item_id) as kept_response_item_id
        from {{ ref('stg_oasis__preauth_api_response_items') }}
        group by branch_id, response_id, item_no
    ) as ri
        on ri.branch_id = r.branch_id and ri.response_id = r.response_id and ri.item_no = s.item_no
),

response_summary as (
    select
        branch_id, line_natural_id, response_count, nphies_first_status, nphies_last_status, last_responded_at,
        tupleElement(final_answer, 1) as nphies_final_status,
        tupleElement(final_answer, 2) as final_responded_at,
        tupleElement(final_answer, 3) as nphies_approved_amount,
        tupleElement(final_answer, 4) as nphies_approved_quantity,
        tupleElement(final_answer, 5) as payer_comment
    from (
        select
            branch_id, line_natural_id,
            uniqExact(response_id)                                         as response_count,
            -- wrapped in a tuple so a NULL status is still picked rather than skipped
            tupleElement(argMin(tuple(nphies_status),
                                tuple(responded_sort, response_id, request_item_id, response_item_id)), 1) as nphies_first_status,
            tupleElement(argMax(tuple(nphies_status),
                                tuple(responded_sort, response_id, request_item_id, response_item_id)), 1) as nphies_last_status,
            max(responded_at)                                              as last_responded_at,
            -- final answer: the latest that is not pended, queued or an error; else the latest of any kind
            argMax(tuple(nphies_status, responded_at, approved_amount, approved_quantity, payer_comment),
                   tuple(toUInt8({{ hnh_preauth_outcome('nphies_status', null_s, null_s) }} not in {{ not_final }}),
                         responded_sort, response_id, request_item_id, response_item_id)) as final_answer
        from responses
        group by branch_id, line_natural_id
    )
),

payer_adjudication as (
    -- The payer's parsed pre-authorisation answer for the line: latest decision, else latest of any kind.
    select
        branch_id, line_natural_id,
        tupleElement(pa, 1) as primary_reason_code,
        tupleElement(pa, 2) as reason_codes,
        tupleElement(pa, 3) as payer_eligible_amount,
        tupleElement(pa, 4) as payer_approved_amount,
        tupleElement(pa, 5) as preauth_reference,
        tupleElement(pa, 6) as preauth_valid_from,
        tupleElement(pa, 7) as preauth_valid_to
    from (
        select
            s.branch_id as branch_id, s.line_natural_id as line_natural_id,
            argMax(tuple(a.primary_reason_code, a.reason_codes, a.eligible, a.benefit,
                         a.preauth_reference, a.preauth_valid_from, a.preauth_valid_to),
                   tuple(toUInt8(a.outcome in ('Approved', 'Partially approved', 'Not required', 'Rejected')),
                         ifNull(a.responded_at, toDateTime(0, 'Asia/Riyadh')), a.response_id)) as pa
        from sent_items as s
        inner join (select * from {{ ref('int_nphies_adjudication') }} where response_kind = 'Pre-authorisation') as a
            on a.branch_id = s.branch_id and a.about_api_trans_id = s.api_trans_id
           and toString(a.item_sequence) = s.item_no
        group by s.branch_id, s.line_natural_id
    )
),

all_lines as (
    select
        ol.branch_id                                     as branch_id,
        concat('A', toString(ol.authorisation_no))       as line_natural_id,
        'Oasis'                                          as line_source,
        toNullable(ol.authorisation_no)                  as authorisation_no,
        cast(null as Nullable(Int64))                    as api_trans_id,
        cast(null as Nullable(String))                   as item_no,
        ol.request_no                                    as request_no,
        coalesce(ol.patient_id, s.patient_id)            as patient_id,
        coalesce(ol.episode_no, s.episode_no)            as episode_no,
        coalesce(ol.ios, s.item_ios)                     as ios,
        s.service_dept                                   as service_dept,
        s.physician_staff_id                             as requesting_staff_id,
        s.purchaser_code                                 as purchaser_code,
        s.treatment_type                                 as treatment_type,
        s.diagnosis_code                                 as diagnosis_code,
        ol.requested_at                                  as requested_at,
        ol.request_status                                as request_status,
        ol.authorised_flag                               as authorised_flag,
        ol.requested_qty                                 as requested_qty,
        ol.authorised_qty                                as oasis_approved_qty,
        ol.used_qty                                      as used_qty,
        s.estimated_cost                                 as estimated_amount,
        ol.amount_authorised                             as legacy_amount_authorised,
        toUInt8(ol.is_transfer = 1 or ifNull(s.is_transfer, 0) = 1) as is_transfer,
        toUInt8(ol.com_req_id is not null)               as has_communication_request,
        toUInt64(ifNull(s.request_send_count, 0))        as request_send_count,
        s.first_sent_at                                  as first_sent_at
    from oasis_lines as ol
    left join sends as s
        on s.branch_id = ol.branch_id and s.line_natural_id = concat('A', toString(ol.authorisation_no))

    union all

    select
        s.branch_id, s.line_natural_id, 'NPHIES only', cast(null as Nullable(Int64)),
        toNullable(s.api_trans_id), s.item_no, s.oasis_request_no, s.patient_id, s.episode_no, s.item_ios,
        s.service_dept, s.physician_staff_id, s.purchaser_code, s.treatment_type, s.diagnosis_code,
        s.first_sent_at, cast(null as Nullable(String)), cast(null as Nullable(String)),
        s.quantity, cast(null as Nullable(Float64)), cast(null as Nullable(Float64)), s.estimated_cost,
        cast(null as Nullable(Float64)), toUInt8(s.is_transfer), toUInt8(0),
        toUInt64(s.request_send_count), s.first_sent_at
    from sends as s
    where startsWith(s.line_natural_id, 'N')
)

select
    l.branch_id                                          as branch_id,
    l.line_natural_id                                    as line_natural_id,
    l.line_source                                        as line_source,
    l.authorisation_no                                   as authorisation_no,
    l.api_trans_id                                       as api_trans_id,
    l.item_no                                            as item_no,
    l.request_no                                         as request_no,
    l.patient_id                                         as patient_id,
    l.episode_no                                         as episode_no,
    l.ios                                                as ios,
    l.service_dept                                       as service_dept,
    l.requesting_staff_id                                as requesting_staff_id,
    l.purchaser_code                                     as purchaser_code,
    l.treatment_type                                     as treatment_type,
    l.diagnosis_code                                     as diagnosis_code,
    l.requested_at                                       as requested_at,
    l.request_status                                     as request_status,
    l.authorised_flag                                    as authorised_flag,
    l.requested_qty                                      as requested_qty,
    coalesce(l.oasis_approved_qty, rs.nphies_approved_quantity) as approved_qty,
    l.used_qty                                           as used_qty,
    l.estimated_amount                                   as estimated_amount,
    l.legacy_amount_authorised                           as legacy_amount_authorised,
    l.is_transfer                                        as is_transfer,
    l.has_communication_request                          as has_communication_request,
    l.request_send_count                                 as request_send_count,
    l.first_sent_at                                      as first_sent_at,
    toUInt64(ifNull(rs.response_count, 0))               as response_count,
    rs.nphies_first_status                               as nphies_first_status,
    rs.nphies_last_status                                as nphies_last_status,
    rs.nphies_final_status                               as nphies_final_status,
    rs.final_responded_at                                as final_responded_at,
    rs.last_responded_at                                 as last_responded_at,
    rs.nphies_approved_amount                            as nphies_approved_amount,
    rs.payer_comment                                     as payer_comment,
    {{ hnh_preauth_outcome('rs.nphies_final_status', 'l.authorised_flag', 'l.request_status') }} as preauth_outcome,
    multiIf(l.request_status = 'S' and l.authorised_flag = 'Y', 'Approved',
            l.request_status = 'S' and l.authorised_flag = 'H', 'Hold',
            l.request_status = 'S' and l.authorised_flag = 'N', 'Sent',
            l.request_status = 'S' and l.authorised_flag = 'R', 'Rejected',
            l.request_status = 'P' and l.authorised_flag = 'N', 'Posted',
            l.request_status = 'O' and l.authorised_flag = 'N', 'Opened', null) as legacy_line_status,
    toUInt8(ifNull(l.request_no, 0) = max(ifNull(l.request_no, 0))
            over (partition by l.branch_id, l.patient_id, l.episode_no, l.ios))  as is_latest_request_for_service,
    toUInt8(ifNull(l.request_no, 0) = max(ifNull(l.request_no, 0))
            over (partition by l.branch_id, l.patient_id, l.episode_no))         as legacy_is_last_request,
    pa.primary_reason_code                               as primary_reason_code,
    ifNull(pa.reason_codes, cast([] as Array(String)))   as reason_codes,
    pa.payer_eligible_amount                             as payer_eligible_amount,
    pa.payer_approved_amount                             as payer_approved_amount,
    pa.preauth_reference                                 as preauth_reference,
    pa.preauth_valid_from                                as preauth_valid_from,
    pa.preauth_valid_to                                  as preauth_valid_to
from all_lines as l
left join response_summary as rs
    on rs.branch_id = l.branch_id and rs.line_natural_id = l.line_natural_id
left join payer_adjudication as pa
    on pa.branch_id = l.branch_id and pa.line_natural_id = l.line_natural_id
{{ hnh_settings() }}
