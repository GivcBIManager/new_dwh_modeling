{# delivery_charge.cancel_flag: null is the live row; C is a cancellation; R is a superseded
   version that was credited and re-billed (its credit note equals the row). #}
{% macro hnh_charge_status(cancel_flag) -%}
multiIf({{ cancel_flag }} is null, 'Live', {{ cancel_flag }} = 'C', 'Cancelled',
        {{ cancel_flag }} = 'R', 'Superseded', 'Unknown')
{%- endmacro %}

{# Only live rows that are not package components are revenue: the package header carries the price. #}
{% macro hnh_is_recognised_revenue(cancel_flag, package_deal_flag) -%}
toUInt8({{ cancel_flag }} is null and ifNull({{ package_deal_flag }}, 'N') != 'Y')
{%- endmacro %}

{% macro hnh_is_medication(product_category_code, delivery_entity_type) -%}
toUInt8(ifNull({{ product_category_code }}, '') in ('MD', 'MED', 'PH', 'CSM', 'RTL', 'MLK')
        or ifNull({{ delivery_entity_type }}, '') = 'P')
{%- endmacro %}

{# Who a charge row is billed to. A patient-paid row (bill-to 2 or 3) on a delivery line that also
   has a live purchaser row is the co-pay: 8888 Deductible. Otherwise the row's purchaser; none is 9999 Cash. #}
{% macro hnh_billed_purchaser(bill_to, purchaser_code, has_purchaser_sibling) -%}
toInt64(if(ifNull({{ bill_to }}, '') != '1' and ifNull({{ has_purchaser_sibling }}, 0) = 1,
           8888, ifNull({{ purchaser_code }}, 9999)))
{%- endmacro %}

{# Care type of a charge: the episode's, else the charge's own attendance type. #}
{% macro hnh_charge_care_type(episode_care_type, attendance_type) -%}
if(ifNull({{ episode_care_type }}, 'Unknown') != 'Unknown', ifNull({{ episode_care_type }}, 'Unknown'),
   multiIf({{ attendance_type }} = 'I', 'IP', {{ attendance_type }} = 'O', 'OP', 'Unknown'))
{%- endmacro %}

{# Pre-authorisation outcome. The NPHIES status (upper-cased) wins when present; otherwise the
   Oasis line: request status S/P with authorised flag Y/R/Z/C/H, S+N is sent and awaiting. #}
{% macro hnh_preauth_outcome(nphies_status, authorised_flag, request_status) -%}
multiIf(
    {{ nphies_status }} in ('ACCEPT.', 'ALL LISTED SERVICES ARE APPROVED')
        or startsWith(ifNull({{ nphies_status }}, ''), 'APPROVED'),          'Approved',
    {{ nphies_status }} = 'PARTIAL',                                         'Partially approved',
    {{ nphies_status }} = 'NOT-REQUIRED',                                    'Not required',
    {{ nphies_status }} = 'REJECTED',                                        'Rejected',
    {{ nphies_status }} in ('PENDED', 'QUEUED', 'QUEUED BY NPHIES'),         'Pended',
    startsWith(ifNull({{ nphies_status }}, ''), 'ERROR'),                    'Error',
    -- SENT and COMPLETE are transport states, not payer decisions: fall through to the Oasis line
    {{ nphies_status }} is not null and {{ nphies_status }} not in ('SENT', 'COMPLETE'), 'Unknown',
    ifNull({{ request_status }}, '') in ('S', 'P') and {{ authorised_flag }} = 'Y', 'Approved',
    ifNull({{ request_status }}, '') in ('S', 'P') and {{ authorised_flag }} = 'R', 'Rejected',
    {{ authorised_flag }} = 'Z',                                             'Not required',
    {{ authorised_flag }} = 'C',                                             'Cancelled',
    {{ authorised_flag }} = 'H',                                             'Pended',
    ifNull({{ request_status }}, '') = 'S' and ifNull({{ authorised_flag }}, 'N') = 'N', 'Pended',
    ifNull({{ request_status }}, '') in ('O', 'P') or ifNull({{ authorised_flag }}, 'N') = 'N', 'Not sent',
    'Unknown')
{%- endmacro %}

{% macro hnh_preauth_outcome_key(expr) -%}
toInt8(multiIf({{ expr }} = 'Approved', 1, {{ expr }} = 'Partially approved', 2, {{ expr }} = 'Not required', 3,
               {{ expr }} = 'Rejected', 4, {{ expr }} = 'Pended', 5, {{ expr }} = 'Error', 6,
               {{ expr }} = 'Cancelled', 7, {{ expr }} = 'Not sent', 8, -1))
{%- endmacro %}
