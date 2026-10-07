{#- Old-warehouse daily stock snapshots (spec S5, open item O-P5-5), loaded by the user into default.old_bal_product_base (source bal_product_base).
    Until that table exists this view returns no rows. The source column names are set once in `cols`: if the loaded
    table names a column differently, change only the right-hand name here. Every output column is wrapped to its
    declared type (assumeNotNull / ifNull), so a table loaded with Nullable columns still gives non-Nullable types. -#}
{%- set cols = {
    'branch_id': 'BRANCH_ID',
    'store_id': 'C_ID',
    'product_code': 'PRODUCT_CODE',
    'snapshot_at': 'Snapshot_timestamp',
    'qty_on_hand': 'QTY_ON_HAND',
    'average_cost': 'AVERAGE_COST'
} -%}
{%- set src = source('reference', 'bal_product_base') -%}
{%- set rel = adapter.get_relation(database=src.database, schema=src.schema, identifier=src.identifier) if execute else none -%}
{%- if rel is not none %}
select
    assumeNotNull(toUInt8({{ cols['branch_id'] }}))                        as branch_id,
    assumeNotNull(toInt64({{ cols['store_id'] }}))                         as store_id,
    ifNull(trimBoth(toString({{ cols['product_code'] }})), '')             as product_code,
    assumeNotNull(toDate({{ cols['snapshot_at'] }}))                       as snapshot_date,
    toFloat64(ifNull({{ cols['qty_on_hand'] }}, 0))                        as qty_on_hand,
    toFloat64(ifNull({{ cols['average_cost'] }}, 0))                       as average_cost
from {{ src }}
where {{ cols['snapshot_at'] }} is not null
  and {{ cols['branch_id'] }} is not null
  and {{ cols['store_id'] }} is not null
{%- else %}
-- {{ src }} does not exist yet: no rows, with the model's columns and types.
select toUInt8(0) as branch_id, toInt64(0) as store_id, '' as product_code, toDate('1970-01-01') as snapshot_date,
       toFloat64(0) as qty_on_hand, toFloat64(0) as average_cost
where 0
{%- endif %}
