-- SSAS spec 4.2 and planning decisions P2/P3: every gold.ssas_* view exposes Int64 integers, Decimal amounts, no arrays,
-- no legacy or load columns, no nullable non-date keys, and the large line facts carry no line ids. Returns violations.
{% set db = ref('ssas_dim_branch').schema %}
with cols as (
    select table, name, type
    from system.columns
    where database = '{{ db }}' and startsWith(table, 'ssas_')
)
select table, name, type, 'type not allowed' as rule
from cols
where match(type, 'Array|UInt|Int8|Int16|Int32|Float32|Date32|LowCardinality')
union all
select table, name, type, 'legacy or load column'
from cols
where startsWith(name, 'legacy_') or name = '_loaded_at'
union all
select table, name, type, 'amount stored as Float64'
from cols
where type like '%Float64%' and match(name, '(amount|_value$|cost|debit|credit|_pay$|fee|price|salary|_rate$|revenue)')
union all
select table, name, type, 'nullable non-date key'
from cols
where type like 'Nullable%' and endsWith(name, '_key') and not match(name, '(date|time)_key$')
union all
select table, name, type, 'line id kept on a large line fact'
from cols
where table in ('ssas_fact_charge_line', 'ssas_fact_order_line', 'ssas_fact_stock_movement',
                'ssas_fact_patient_consumption', 'ssas_fact_claim_line')
  and name in ('charge_line_key', 'order_line_key', 'movement_key', 'claim_line_key', 'delivery_charge_id',
               'delivery_line', 'invoice_doc_no', 'master_order_no', 'order_line', 'oasis_line_id', 'oasis_doc_no',
               'fusion_transaction_id', 'claim_invoice_no', 'stat_invoice_no', 'visit_id', 'sequence_no', 'lot_number')
union all
select 'gold' as table, toString(n) as name, 'views' as type, 'expected 79 ssas_ views' as rule
from (select count() as n from system.tables where database = '{{ db }}' and startsWith(name, 'ssas_'))
where n != 79
