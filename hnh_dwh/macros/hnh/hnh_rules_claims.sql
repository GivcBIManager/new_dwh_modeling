{# NPHIES item adjudication outcome code (extension-adjudication-outcome) to a label. #}
{% macro hnh_nphies_outcome(outcome_code) -%}
multiIf(lower(ifNull({{ outcome_code }}, '')) = 'approved', 'Approved',
        lower(ifNull({{ outcome_code }}, '')) = 'partial', 'Partially approved',
        lower(ifNull({{ outcome_code }}, '')) = 'not-required', 'Not required',
        lower(ifNull({{ outcome_code }}, '')) = 'rejected', 'Rejected',
        lower(ifNull({{ outcome_code }}, '')) in ('pended', 'queued'), 'Pended',
        'Unknown')
{%- endmacro %}

{# A pull-response status that carries a payer decision. #}
{% macro hnh_is_decision_status(res_status) -%}
toUInt8(ifNull({{ res_status }}, '') in ('APPROVED', 'PARTIAL', 'REJECTED'))
{%- endmacro %}

{% macro hnh_claim_adjudication_status(is_sent, has_response, final_status) -%}
multiIf({{ is_sent }} = 0, 'Not sent',
        {{ has_response }} = 0, 'No response',
        ifNull({{ final_status }}, '') in ('APPROVED', 'PARTIAL', 'REJECTED'), 'Adjudicated',
        ifNull({{ final_status }}, '') in ('PENDED', 'QUEUED'), 'Pended',
        'Error')
{%- endmacro %}

{# First NPHIES reason code (e.g. BE-1-3) written in a claim line's free-text notes. #}
{% macro hnh_reason_from_notes(notes) -%}
nullIf(extract(ifNull({{ notes }}, ''), '[A-Z]{2}-[0-9]+-[0-9]+'), '')
{%- endmacro %}

{# Amount of the adjudication whose category code is `code`; null when the category is absent. #}
{% macro hnh_adjudication_amount(categories, adjudications, code) -%}
if(has({{ categories }}, {{ code }}),
   JSONExtractFloat(arrayElement({{ adjudications }}, indexOf({{ categories }}, {{ code }})), 'amount', 'value'),
   cast(null as Nullable(Float64)))
{%- endmacro %}
