{{ config(order_by='(branch_key, month_start)') }}

{#- Hospital pre-authorisation lines only: payer advance authorisations (line_source 'Payer advance', spec Phase 2B
    section 12) have no request, send or service and are reported in their own two columns. -#}
{% set h = "f.line_source != 'Payer advance'" %}

select
    branch_key,
    toStartOfMonth(YYYYMMDDToDate(toUInt32(request_date_key)))                  as month_start,
    countIf({{ h }})                                                            as services,
    countIf({{ h }} and is_approved = 1)                                        as approved,
    countIf({{ h }} and preauth_outcome = 'Rejected')                           as rejected,
    countIf({{ h }} and has_final_response = 1)                                 as final_responses,
    -- approval and rejection rates: these numerators over final_responses
    countIf({{ h }} and is_approved = 1 and has_final_response = 1)             as approved_final,
    countIf({{ h }} and preauth_outcome = 'Rejected' and has_final_response = 1) as rejected_final,
    countIf({{ h }} and is_approved_not_delivered = 1)                          as unutilised,
    sumIf(approved_estimated_amount, {{ h }} and is_approved_not_delivered = 1 and is_latest_request_for_service = 1) as lost_revenue,
    countIf({{ h }} and is_delivered_not_approved = 1)                          as delivered_not_approved,
    -- the RCM Authorization report: last response of any kind, all services as denominator
    countIf({{ h }} and nphies_last_status in ('APPROVED', 'NOT-REQUIRED', 'PARTIAL')) as legacy_approved,
    countIf({{ h }} and nphies_last_status = 'REJECTED')                        as legacy_rejected,
    sumIf(approved_estimated_amount, {{ h }} and nphies_last_status = 'APPROVED' and is_delivered = 0 and legacy_is_last_request = 1) as legacy_lost_revenue,
    -- rejections by the NPHIES reason category of the line's primary reason
    countIf({{ h }} and preauth_outcome = 'Rejected' and r.reason_category = 'Technical and contractual')   as rejected_technical_contractual,
    countIf({{ h }} and preauth_outcome = 'Rejected' and r.reason_category = 'Appropriateness of care')     as rejected_appropriateness,
    countIf({{ h }} and preauth_outcome = 'Rejected' and r.reason_category = 'Pharmacy Benefit Management') as rejected_pharmacy,
    countIf({{ h }} and preauth_outcome = 'Rejected' and r.reason_category = 'Duplicated Service')          as rejected_duplicated,
    countIf({{ h }} and preauth_outcome = 'Rejected' and r.reason_category = 'Fraud')                       as rejected_fraud,
    countIf({{ h }} and preauth_outcome = 'Rejected' and f.nphies_reason_key = 0)                           as rejected_reason_not_given,
    countIf({{ h }} and preauth_outcome = 'Rejected' and f.nphies_reason_key = -1)                          as rejected_reason_unknown,
    -- payer advance authorisations by creation month: count and approved amount as sent (placeholders included)
    countIf(f.line_source = 'Payer advance')                                    as advance_authorisations,
    sumIf(ifNull(f.payer_approved_amount, 0), f.line_source = 'Payer advance')  as advance_approved_amount
from {{ ref('fact_preauth_line') }} as f
left join (select nphies_reason_key, reason_category from {{ ref('dim_nphies_reason') }}) as r
    on r.nphies_reason_key = f.nphies_reason_key
group by f.branch_key, month_start
{{ hnh_settings() }}
