{{ config(order_by='(branch_key, transaction_date, fusion_transaction_id)') }}

-- One row per Fusion inventory transaction (spec 6.1). Branch from the posting organisation, never from the reference
-- prefix (spec F1). reference_status of the four integration types: oasis_line (the reference resolves to a line of
-- int_oasis_stock_line in that branch), oasis_out_of_scope (to a staged Oasis line that int_oasis_stock_line leaves
-- out; oasis_scope_reason says why), not_in_oasis (a reference with no such staged line), no_reference (none
-- parseable); other types are not_integration. Unit cost: quantity-weighted cost of the valuation layers with the same
-- item, organisation, cost day and transaction type (spec F6); a zero cost is null, so the Oasis line cost applies.
-- Lot: the lot with the earliest expiry from 2000 on (earlier expiries go back to 1930 and are not real), with that
-- expiry; without such a lot, the lowest lot number and a null expiry.

with tx as (
    select t.transaction_id as transaction_id, t.organization_id as organization_id, t.subinventory_code as subinventory_code,
           t.transfer_organization_id as transfer_organization_id, t.transfer_subinventory as transfer_subinventory,
           t.inventory_item_id as inventory_item_id, t.transaction_type_id as transaction_type_id,
           t.transaction_reference as transaction_reference, t.rcv_transaction_id as rcv_transaction_id,
           t.transaction_date as transaction_date, t.primary_quantity as primary_quantity,
           ifNull(o.branch_key, toUInt8(0)) as branch_key, ifNull(o.org_type_code, '00') as org_type_code,
           toUInt8(ifNull(t.transaction_type_id, 0) in {{ hnh_fusion_integration_type_ids() }}) as is_integration_type,
           if(is_integration_type = 1, {{ hnh_oasis_line_ref('t.transaction_reference') }}, cast(null as Nullable(Int64))) as parsed_line_id
    from {{ ref('stg_fusion__inventory_transactions') }} as t
    left join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = t.organization_id
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

refs as (
    -- the (branch, Oasis line) pairs the integration references; every Oasis read below is restricted to them
    select distinct branch_key as ref_branch_id, assumeNotNull(parsed_line_id) as ref_line_id
    from tx
    where parsed_line_id is not null
),

oasis_lines as (
    -- every referenced Oasis line, in scope or not, with what decides its scope
    select branch_id, line_id, doc_id, doc_type, line_date, total_cost, line_status
    from {{ ref('stg_oasis__stock_document_lines') }}
    where line_date >= toDate32('{{ var("hnh_fusion_inventory_start") }}') - 92
      and (branch_id, line_id) in (select ref_branch_id, ref_line_id from refs)
),

oasis_docs as (
    select branch_id, doc_id, doc_status, gl_stk, order_type, doc_date
    from {{ ref('stg_oasis__stock_documents') }}
    where (branch_id, doc_id) in (select branch_id, doc_id from oasis_lines)
),

in_scope as (
    select branch_key as scope_branch_key, oasis_line_id as scope_line_id
    from {{ ref('int_oasis_stock_line') }}
    where (branch_key, oasis_line_id) in (select ref_branch_id, ref_line_id from refs)
),

valuation as (
    select inventory_item_id, inventory_org_id, cost_date, base_txn_type_id,
           nullIf(sum(abs(quantity) * unit_cost) / sum(abs(quantity)), 0) as layer_unit_cost
    from {{ ref('stg_fusion__inventory_valuation') }}
    where quantity != 0 and posted_flag in ('Y', 'E')
    group by inventory_item_id, inventory_org_id, cost_date, base_txn_type_id
),

lots as (
    select tl.transaction_id as transaction_id,
           countIf(lt.expiration_date >= toDate32('2000-01-01')) as dated_lots,
           if(dated_lots > 0,
              argMinIf(tl.lot_number, (assumeNotNull(lt.expiration_date), tl.lot_number), lt.expiration_date >= toDate32('2000-01-01')),
              min(tl.lot_number))                                       as first_lot,
           if(dated_lots > 0,
              toNullable(minIf(assumeNotNull(lt.expiration_date), lt.expiration_date >= toDate32('2000-01-01'))),
              cast(null as Nullable(Date32)))                           as first_expiry
    from {{ ref('stg_fusion__inventory_transaction_lots') }} as tl
    left join {{ ref('stg_fusion__lots') }} as lt
        on lt.inventory_item_id = tl.inventory_item_id and lt.organization_id = tl.organization_id and lt.lot_number = tl.lot_number
    group by tl.transaction_id
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
)

select
    t.transaction_id                                                    as fusion_transaction_id,
    t.branch_key                                                        as branch_key,
    t.organization_id                                                   as organization_id,
    t.org_type_code                                                     as org_type_code,
    t.subinventory_code                                                 as subinventory_code,
    t.transfer_organization_id                                          as transfer_organization_id,
    t.transfer_subinventory                                             as transfer_subinventory,
    t.inventory_item_id                                                 as inventory_item_id,
    t.transaction_type_id                                               as transaction_type_id,
    t.transaction_date                                                  as transaction_date,
    t.primary_quantity                                                  as primary_quantity,
    t.rcv_transaction_id                                                as rcv_transaction_id,
    t.is_integration_type                                               as is_integration_type,
    multiIf(t.is_integration_type = 0, 'not_integration', t.parsed_line_id is null, 'no_reference',
            ol.line_id is null, 'not_in_oasis', s.scope_line_id is null, 'oasis_out_of_scope',
            'oasis_line')                                               as reference_status,
    -- why a staged line is out of scope, with the predicates of int_oasis_stock_line (first match wins)
    toLowCardinality(multiIf(
        reference_status != 'oasis_out_of_scope', cast(null as Nullable(String)),
        ifNull(ol.doc_type, '') = 'CREDITAR', 'creditar',
        ifNull(ol.doc_type, '') = 'INVOICEAR' and ifNull(d.gl_stk, '') = 'R', 'reversed_invoice',
        ifNull(d.order_type, '') = 'PKHEADER', 'package_header',
        ifNull(ol.doc_type, '') not in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT')
            or (ifNull(ol.doc_type, '') = 'INVOICEAR' and ifNull(ol.total_cost, 0) = 0)
            or ifNull(ol.line_status, '') in ('C', 'S'), 'not_stock_or_zero_cost',
        'other'))                                                       as oasis_scope_reason,
    if(reference_status = 'oasis_line', t.parsed_line_id, cast(null as Nullable(Int64))) as oasis_line_id,
    {{ hnh_is_opening_balance('t.transaction_type_id', 't.transaction_reference') }} as is_opening_balance,
    {{ hnh_fusion_movement_type('t.transaction_type_id', 't.primary_quantity', 't.org_type_code', 'is_opening_balance') }} as fusion_movement_type,
    v.layer_unit_cost                                                   as valuation_unit_cost,
    lt.first_lot                                                        as lot_number,
    lt.first_expiry                                                     as expiry_date
from tx as t
left join oasis_lines as ol on ol.branch_id = t.branch_key and ol.line_id = t.parsed_line_id
left join oasis_docs as d on d.branch_id = ol.branch_id and d.doc_id = ol.doc_id
left join in_scope as s on s.scope_branch_key = t.branch_key and s.scope_line_id = t.parsed_line_id
left join valuation as v
    on v.inventory_item_id = t.inventory_item_id and v.inventory_org_id = t.organization_id
   and v.cost_date = t.transaction_date and v.base_txn_type_id = t.transaction_type_id
left join lots as lt on lt.transaction_id = t.transaction_id
{{ hnh_settings() }}
