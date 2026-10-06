{{ config(order_by='(branch_key, line_date, oasis_line_id)') }}

-- One row per in-scope Oasis stock line from the history start (spec 4.4, 6.1). In scope: posted documents
-- (doc_status P) that are not reversed (gl_stk R) and not package headers; patient invoice lines only with a cost;
-- GRN lines not cancelled or superseded (line status C/S). Credit notes (CREDITAR) are invoice reversals, not stock
-- (plan refinement). Lines are filtered before any join (about 32M of 156M lines).
-- Quantities: Oasis base units converted to the item's primary unit through the crosswalk; signed + in / - out.
-- Cost: total_cost, or quantity x unit cost on lines that carry none (counts, patient returns), with the same sign.
-- Expiry dates before 2000 are Oasis "no expiry" values (1900-era adj_date) and become null.
{% set first_day = "toDate32('" ~ var('hnh_history_start_date') ~ "')" %}
{% set last_day = "toDate32(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with lines as (
    select branch_id, line_id, doc_id, doc_type, line_date, store_id, product_code, quantity, unit_cost, total_cost,
           line_status, cross_ref_line_id, lot_number, batch_number, expiry_date, bonus_quantity
    from {{ ref('stg_oasis__stock_document_lines') }}
    where doc_type in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT')
      and line_date >= {{ first_day }} and line_date <= {{ last_day }}
      and (doc_type != 'INVOICEAR' or total_cost != 0)
      and ifNull(line_status, '') not in ('C', 'S')
),

docs as (
    select branch_id, doc_id, doc_no, source_code, pod, account_code
    from {{ ref('stg_oasis__stock_documents') }}
    where doc_type in ('INVOICEAR', 'STOCKISS', 'STOCKRCPT')
      and doc_status = 'P' and ifNull(gl_stk, '') != 'R' and ifNull(order_type, '') != 'PKHEADER'
      and doc_date >= {{ first_day }} - 62
),

classified as (
    select
        l.branch_id                                                     as branch_key,
        l.line_id                                                       as oasis_line_id,
        l.doc_id                                                        as oasis_doc_id,
        d.doc_no                                                        as oasis_doc_no,
        l.doc_type                                                      as doc_type,
        d.source_code                                                   as source_code,
        assumeNotNull(l.line_date)                                      as line_date,
        {{ hnh_oasis_movement_type('l.doc_type', 'd.source_code', 'toUInt8(d.pod is not null)') }} as movement_type,
        toUInt8(ifNull(d.source_code, '') = 'BATCH')                    as is_batch_posting,
        l.store_id                                                      as store_id,
        if(movement_type in ('Transfer out', 'Transfer in'), d.pod, cast(null as Nullable(Int64))) as transfer_store_id,
        l.product_code                                                  as product_code,
        l.quantity                                                      as base_quantity,
        if(l.total_cost != 0, l.total_cost, l.quantity * l.unit_cost)   as base_cost,
        {{ hnh_oasis_direction('l.doc_type') }}                         as direction,
        coalesce(l.lot_number, l.batch_number)                          as lot_number,
        if(l.expiry_date >= toDate32('2000-01-01'), l.expiry_date, cast(null as Nullable(Date32))) as expiry_date,
        d.account_code                                                  as account_code,
        l.cross_ref_line_id                                             as cross_ref_line_id,
        l.bonus_quantity                                                as bonus_quantity
    from lines as l
    inner join docs as d on d.branch_id = l.branch_id and d.doc_id = l.doc_id
)

select
    c.branch_key                                                        as branch_key,
    c.oasis_line_id                                                     as oasis_line_id,
    c.oasis_doc_id                                                      as oasis_doc_id,
    c.oasis_doc_no                                                      as oasis_doc_no,
    c.doc_type                                                          as doc_type,
    c.source_code                                                       as source_code,
    c.line_date                                                         as line_date,
    c.movement_type                                                     as movement_type,
    c.is_batch_posting                                                  as is_batch_posting,
    c.store_id                                                          as store_id,
    c.transfer_store_id                                                 as transfer_store_id,
    c.product_code                                                      as product_code,
    x.inventory_item_id                                                 as inventory_item_id,
    {{ hnh_stock_item_key('x.inventory_item_id', 'c.branch_key', 'c.product_code') }} as item_key,
    c.direction * {{ hnh_primary_qty('c.base_quantity', 'x.units_per_primary') }} as primary_quantity,
    c.direction * c.base_cost                                           as cost_amount,
    if(primary_quantity != 0, cost_amount / primary_quantity, 0)        as unit_cost,
    c.lot_number                                                        as lot_number,
    c.expiry_date                                                       as expiry_date,
    c.account_code                                                      as account_code,
    c.cross_ref_line_id                                                 as cross_ref_line_id,
    {{ hnh_primary_qty('c.bonus_quantity', 'x.units_per_primary') }}    as bonus_quantity
from classified as c
left join {{ ref('int_item_crosswalk') }} as x on x.branch_key = c.branch_key and x.product_code = c.product_code
{{ hnh_settings() }}
