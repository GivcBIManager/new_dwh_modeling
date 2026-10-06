{# Fusion transaction types of the Oasis-to-Fusion integration: Oasis Transfer Order Issue, Oasis Transfer Order
   Receipt, Oasis Sales Return, Oasis Sales Issue (spec F1). #}
{% macro hnh_fusion_integration_type_ids() -%}
(300000012981824, 300000012981825, 300000012981826, 300000012981827)
{%- endmacro %}

{# Movement type of an Oasis stock line (spec 4.4 with the plan refinements). doc_type is the line's document type;
   source_code and has_pod (UInt8) come from the document header. #}
{% macro hnh_oasis_movement_type(doc_type, source_code, has_pod) -%}
multiIf(ifNull({{ doc_type }}, '') = 'INVOICEAR', 'Patient sale',
        ifNull({{ doc_type }}, '') = 'STOCKRCPT' and ifNull({{ source_code }}, '') in ('CRD', 'SALES'), 'Patient return',
        ifNull({{ doc_type }}, '') = 'STOCKISS' and ifNull({{ source_code }}, '') = 'ENTT' and {{ has_pod }} = 0, 'Department issue',
        ifNull({{ doc_type }}, '') = 'STOCKISS' and ifNull({{ source_code }}, '') = 'ENTT', 'Transfer out',
        ifNull({{ doc_type }}, '') = 'STOCKRCPT' and ifNull({{ source_code }}, '') = 'ENTT', 'Transfer in',
        ifNull({{ doc_type }}, '') = 'STOCKRCPT' and ifNull({{ source_code }}, '') = 'GRN', 'Goods receipt',
        ifNull({{ doc_type }}, '') = 'STOCKISS' and ifNull({{ source_code }}, '') = 'RFN', 'Return to supplier',
        ifNull({{ source_code }}, '') = 'CNT', 'Count adjustment',
        'Write-off / misc')
{%- endmacro %}

{# Store-side sign of an Oasis line: receipts add stock, issues and patient invoices remove it. Oasis quantities are
   never negative. #}
{% macro hnh_oasis_direction(doc_type) -%}
toInt8(if(ifNull({{ doc_type }}, '') = 'STOCKRCPT', 1, -1))
{%- endmacro %}

{# Opening-balance loads (Miscellaneous Receipt, type 42) and their reversals (Miscellaneous issue, type 32), by the
   reference prefixes measured on 2026-10-06: OB-, ABHA-, M-JA-, RF- loads and CP-, PPC-, CCP-, PC- reversals. #}
{% macro hnh_is_opening_balance(transaction_type_id, reference) -%}
toUInt8((ifNull({{ transaction_type_id }}, 0) = 42 and match(upper(ifNull({{ reference }}, '')), '^(OB|ABHA|M-[A-Z][A-Z]|RF)(-|$)'))
     or (ifNull({{ transaction_type_id }}, 0) = 32 and match(upper(ifNull({{ reference }}, '')), '^(CP|PPC|CCP|PC)(-|$)')))
{%- endmacro %}

{# Movement type of a Fusion transaction that has no Oasis line (spec 4.4). org_type_code is the two-digit
   inventory-organisation type ('04'-'12' are department organisations). #}
{% macro hnh_fusion_movement_type(transaction_type_id, primary_quantity, org_type_code, is_opening_balance) -%}
multiIf({{ is_opening_balance }} = 1, 'Opening balance',
        ifNull({{ transaction_type_id }}, 0) = 300000012981827, 'Patient sale',
        ifNull({{ transaction_type_id }}, 0) = 300000012981826, 'Patient return',
        ifNull({{ transaction_type_id }}, 0) = 300000012981824, 'Transfer out',
        ifNull({{ transaction_type_id }}, 0) = 300000012981825, 'Transfer in',
        ifNull({{ transaction_type_id }}, 0) in (18, 71), 'Goods receipt',
        ifNull({{ transaction_type_id }}, 0) = 36, 'Return to supplier',
        ifNull({{ transaction_type_id }}, 0) in (4, 8), 'Count adjustment',
        ifNull({{ transaction_type_id }}, 0) in (2, 3, 12, 21, 34, 53, 54, 61, 62),
            if(ifNull({{ primary_quantity }}, 0) >= 0, 'Transfer in', 'Transfer out'),
        ifNull({{ transaction_type_id }}, 0) = 1, 'Department issue',
        ifNull({{ transaction_type_id }}, 0) = 32 and ifNull({{ org_type_code }}, '') between '04' and '12', 'Department issue',
        'Write-off / misc')
{%- endmacro %}

{# Consumption = patient sales, patient returns and department issues (spec 6.3); transfers never count. #}
{% macro hnh_is_consumption(movement_type) -%}
toUInt8(ifNull({{ movement_type }}, '') in ('Patient sale', 'Patient return', 'Department issue'))
{%- endmacro %}

{# Normal direction of a movement type: 1 into the store, -1 out of it, 0 either way. #}
{% macro hnh_movement_direction(movement_type) -%}
toInt8(multiIf(ifNull({{ movement_type }}, '') in ('Patient return', 'Transfer in', 'Goods receipt'), 1,
               ifNull({{ movement_type }}, '') in ('Patient sale', 'Department issue', 'Transfer out', 'Return to supplier'), -1,
               0))
{%- endmacro %}

{# The Oasis line id in a Fusion integration reference "<prefix>-<line_id>" (one or two dashes); null otherwise.
   The prefix is not trusted: the branch comes from the posting organisation (spec F1). #}
{% macro hnh_oasis_line_ref(reference) -%}
toInt64OrNull(extract(ifNull({{ reference }}, ''), '^[A-Za-z]+-+([0-9]+)$'))
{%- endmacro %}

{# Oasis base-unit quantity in the item's primary unit: divided by the crosswalk's Oasis units per Fusion primary unit
   when that factor is greater than 0, unchanged otherwise (plan refinement of spec 4.5). #}
{% macro hnh_primary_qty(qty, units_per_primary) -%}
toFloat64(if(ifNull({{ units_per_primary }}, 0) > 0, ifNull({{ qty }}, 0) / ifNull({{ units_per_primary }}, 0), ifNull({{ qty }}, 0)))
{%- endmacro %}

{# ABC class from an item's cumulative share of consumption cost (spec 7). #}
{% macro hnh_abc_class(cum_share) -%}
multiIf(ifNull({{ cum_share }}, 1) <= 0.80, 'A', ifNull({{ cum_share }}, 1) <= 0.95, 'B', 'C')
{%- endmacro %}

{# Two-digit organisation type of a Fusion inventory organisation code (spec F3): the code's last two digits for
   <letters><nn> codes; Alrabwah's N01-N04 are Pharmacy, Ward, Clinics and Radiology; the master and Head Office
   administration organisations are 00 and 10. #}
{% macro hnh_org_type_code(organization_code) -%}
multiIf(ifNull({{ organization_code }}, '') = 'N01', '04', ifNull({{ organization_code }}, '') = 'N02', '06',
        ifNull({{ organization_code }}, '') = 'N03', '07', ifNull({{ organization_code }}, '') = 'N04', '09',
        ifNull({{ organization_code }}, '') in ('HQ01', 'IT_HQ'), '10',
        match(ifNull({{ organization_code }}, ''), '^[A-Z]+[0-9][0-9]$'), right(ifNull({{ organization_code }}, ''), 2),
        '00')
{%- endmacro %}

{# Oasis purchase-order status label from the document status. #}
{% macro hnh_oasis_po_status(doc_status, line_status) -%}
multiIf(ifNull({{ line_status }}, '') = 'C', 'CANCELED', ifNull({{ doc_status }}, '') = 'R', 'RELEASED',
        ifNull({{ doc_status }}, '') = 'C', 'CLOSED', ifNull({{ doc_status }}, '') = 'O', 'OPEN', 'UNKNOWN')
{%- endmacro %}

{# Last month-end of the monthly stock snapshot: var hnh_stock_month_end_last, empty = the current month's end. #}
{% macro hnh_stock_last_month_end() -%}
{%- set last_var = var('hnh_stock_month_end_last', '') -%}
{%- if last_var -%}toDate('{{ last_var }}'){%- else -%}toLastDayOfMonth(today()){%- endif -%}
{%- endmacro %}

{# Item key of a stock line: the Fusion inventory item id when known, else the Oasis branch + product code. Arguments
   are SQL expressions. #}
{% macro hnh_stock_item_key(inventory_item_id, branch, product_code) -%}
if({{ inventory_item_id }} is not null, {{ hnh_surrogate_key([inventory_item_id]) }}, {{ hnh_surrogate_key([branch, product_code]) }})
{%- endmacro %}

{# Store key of a Fusion organisation + subinventory; a null subinventory is the organisation level ('*'). #}
{% macro hnh_fusion_store_key(organization_id, subinventory_code) -%}
{{ hnh_surrogate_key(["'fusion'", organization_id, "ifNull(nullIf(" ~ subinventory_code ~ ", ''), '*')"]) }}
{%- endmacro %}
