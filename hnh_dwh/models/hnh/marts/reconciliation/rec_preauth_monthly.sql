{{ config(order_by='(branch_key, month_start)') }}

select
    branch_key,
    toStartOfMonth(YYYYMMDDToDate(toUInt32(request_date_key)))                  as month_start,
    count()                                                                     as services,
    countIf(is_approved = 1)                                                    as approved,
    countIf(preauth_outcome = 'Rejected')                                       as rejected,
    countIf(has_final_response = 1)                                             as final_responses,
    countIf(is_approved_not_delivered = 1)                                      as unutilised,
    sumIf(approved_estimated_amount, is_approved_not_delivered = 1 and is_latest_request_for_service = 1) as lost_revenue,
    countIf(is_delivered_not_approved = 1)                                      as delivered_not_approved,
    -- the RCM Authorization report: last response of any kind, all services as denominator
    countIf(nphies_last_status in ('APPROVED', 'NOT-REQUIRED', 'PARTIAL'))      as legacy_approved,
    countIf(nphies_last_status = 'REJECTED')                                    as legacy_rejected,
    sumIf(approved_estimated_amount, nphies_last_status = 'APPROVED' and is_delivered = 0 and legacy_is_last_request = 1) as legacy_lost_revenue
from {{ ref('fact_preauth_line') }}
group by branch_key, month_start
