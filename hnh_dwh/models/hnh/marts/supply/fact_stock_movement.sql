{{ config(order_by='(branch_key, date_key, movement_key)') }}

-- One row per stock line (spec 6.1, S1-S3). A line with an Oasis line id is that line: before the branch's inventory
-- go-live (or with no go-live) it is the Oasis line; from the go-live it is the Fusion transaction(s) that reference
-- it, else the Oasis line flagged is_fusion_gap. Fusion transactions without an Oasis line (receipts, counts, misc,
-- opening balances, references to lines Oasis does not hold, and references to Oasis lines out of scope for a reason
-- other than a reversed invoice, CREDITAR or a package header) are lines of their own from the go-live. Left out
-- (visible in rec_stock_interface_daily): Fusion rows before the go-live, integration rows with no reference or whose
-- line is a reversed invoice, CREDITAR or a package header (Oasis leaves out both sides of those reversals), and from
-- the go-live Oasis batch postings, which echo Fusion transactions (plan refinement).
-- The date of a line with an Oasis line id is the Oasis date, so a line keeps its day when it moves to Fusion.
-- Costs stay as recorded (S6); oasis_cost_amount carries the Oasis line's cost beside a Fusion-sourced cost and
-- is_cost_mismatch flags a ratio outside [0.5, 2] (Fusion pack-item costs loaded per base unit in five branches).
with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }}
    where inventory_go_live_date is not null
),

oasis as (
    select o.branch_key as branch_key, o.oasis_line_id as oasis_line_id, o.oasis_doc_no as oasis_doc_no,
           o.line_date as line_date, o.movement_type as movement_type, o.is_batch_posting as is_batch_posting,
           o.store_id as store_id, o.transfer_store_id as transfer_store_id, o.product_code as product_code,
           o.item_key as item_key, o.primary_quantity as primary_quantity, o.cost_amount as cost_amount,
           o.unit_cost as unit_cost, o.lot_number as lot_number, o.expiry_date as expiry_date,
           k.go_live_date as go_live_date,
           toUInt8(k.go_live_date is not null and o.line_date >= k.go_live_date) as is_live
    from {{ ref('int_oasis_stock_line') }} as o
    left join cutover as k on k.branch_id = o.branch_key
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

fusion as (
    select f.*, k.go_live_date as go_live_date
    from {{ ref('int_fusion_stock_line') }} as f
    left join cutover as k on k.branch_id = f.branch_key
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

fusion_by_line as (
    -- the Fusion transactions that reference one Oasis line (a line posted twice and corrected nets to one)
    select branch_key as fl_branch_key, assumeNotNull(oasis_line_id) as fl_oasis_line_id,
           min(fusion_transaction_id) as fl_transaction_id, toUInt32(count()) as fl_transaction_count,
           min(transaction_date) as fl_transaction_date, sum(primary_quantity) as fl_quantity,
           sum(primary_quantity * ifNull(valuation_unit_cost, 0)) as fl_valuation_cost,
           countIf(valuation_unit_cost is null) as fl_missing_cost,
           argMin(organization_id, fusion_transaction_id) as fl_organization_id,
           argMin(subinventory_code, fusion_transaction_id) as fl_subinventory_code,
           argMin(transfer_organization_id, fusion_transaction_id) as fl_transfer_organization_id,
           argMin(transfer_subinventory, fusion_transaction_id) as fl_transfer_subinventory,
           argMin(inventory_item_id, fusion_transaction_id) as fl_inventory_item_id,
           -- lot and expiry as one pair: those of the first transaction (lowest id) that carries a lot
           toUInt8(countIf(lot_number is not null) > 0) as fl_has_lot,
           argMinIf(tuple(lot_number, expiry_date), fusion_transaction_id, lot_number is not null) as fl_lot_pair,
           tupleElement(fl_lot_pair, 1) as fl_lot_number, tupleElement(fl_lot_pair, 2) as fl_expiry_date
    from fusion
    where reference_status = 'oasis_line'
    group by branch_key, oasis_line_id
),

oasis_identity as (
    select o.*, fl.*, toUInt8(fl.fl_oasis_line_id is not null) as has_fusion
    from oasis as o
    left join fusion_by_line as fl on fl.fl_branch_key = o.branch_key and fl.fl_oasis_line_id = o.oasis_line_id
    where not (o.is_live = 1 and o.is_batch_posting = 1)
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
),

identity_rows as (
    select
        {{ hnh_surrogate_key(["'oasis-line'", 'branch_key', 'oasis_line_id']) }}  as movement_key,
        branch_key,
        line_date,
        if(is_live = 1 and has_fusion = 1, 'fusion', 'oasis')                     as source_system,
        toUInt8(1)                                                                as is_in_oasis,
        has_fusion                                                                as is_in_fusion,
        toUInt8(is_live = 1 and has_fusion = 0)                                   as is_fusion_gap,
        toUInt8(0)                                                                as is_opening_balance,
        movement_type,
        if(source_system = 'fusion',
           {{ hnh_fusion_store_key('fl_organization_id', 'fl_subinventory_code') }},
           {{ hnh_surrogate_key(["'oasis'", 'branch_key', 'store_id']) }})         as store_key_raw,
        if(source_system = 'fusion',
           if(fl_transfer_organization_id is null and fl_transfer_subinventory is null, toInt64(-1),
              {{ hnh_fusion_store_key('ifNull(fl_transfer_organization_id, fl_organization_id)', 'fl_transfer_subinventory') }}),
           {{ hnh_surrogate_key(["'oasis'", 'branch_key', 'transfer_store_id']) }}) as transfer_store_key_raw,
        -- hnh_stock_item_key with a known Fusion item reduces to this form; a null item stays -1 as in the plan
        if(source_system = 'fusion', {{ hnh_surrogate_key(['fl_inventory_item_id']) }}, item_key) as item_key_raw,
        toNullable(oasis_line_id)                                                 as oasis_line_id,
        oasis_doc_no,
        product_code                                                              as oasis_product_code,
        if(has_fusion = 1, fl_transaction_id, cast(null as Nullable(Int64))) as fusion_transaction_id,
        if(has_fusion = 1, assumeNotNull(fl_transaction_count), toUInt32(0))                     as fusion_transaction_count,
        if(has_fusion = 1, fl_transaction_date, cast(null as Nullable(Date))) as fusion_transaction_date,
        if(source_system = 'fusion', ifNull(fl_quantity, 0), primary_quantity)    as movement_quantity,
        multiIf(source_system = 'oasis', if(cost_amount != 0, 'oasis_line', 'none'),
                fl_missing_cost = 0, 'fusion_valuation', ifNull(unit_cost, 0) != 0, 'oasis_line', 'none') as cost_source,
        multiIf(source_system = 'oasis', cost_amount, fl_missing_cost = 0, ifNull(fl_valuation_cost, 0),
                -- the Oasis unit cost only when there is one (0 = none: no usable Oasis quantity)
                ifNull(unit_cost, 0) != 0, ifNull(unit_cost, 0) * ifNull(fl_quantity, 0), 0) as movement_cost,
        toNullable(cost_amount)                                                   as oasis_cost_amount,
        -- the Fusion lot pair when Fusion has a lot, else the Oasis pair (never one from each)
        if(source_system = 'fusion' and ifNull(fl_has_lot, 0) = 1, fl_lot_number, lot_number) as lot_number,
        if(source_system = 'fusion' and ifNull(fl_has_lot, 0) = 1, fl_expiry_date, expiry_date) as expiry_date
    from oasis_identity
),

fusion_only_rows as (
    select
        {{ hnh_surrogate_key(["'fusion-transaction'", 'fusion_transaction_id']) }} as movement_key,
        branch_key,
        toDate32(transaction_date)                                                as line_date,
        'fusion'                                                                  as source_system,
        toUInt8(0)                                                                as is_in_oasis,
        toUInt8(1)                                                                as is_in_fusion,
        toUInt8(0)                                                                as is_fusion_gap,
        is_opening_balance,
        fusion_movement_type                                                      as movement_type,
        {{ hnh_fusion_store_key('organization_id', 'subinventory_code') }}         as store_key_raw,
        if(transfer_organization_id is null and transfer_subinventory is null, toInt64(-1),
           {{ hnh_fusion_store_key('ifNull(transfer_organization_id, organization_id)', 'transfer_subinventory') }}) as transfer_store_key_raw,
        {{ hnh_surrogate_key(['inventory_item_id']) }}                            as item_key_raw,
        cast(null as Nullable(Int64))                                             as oasis_line_id,
        cast(null as Nullable(String))                                            as oasis_doc_no,
        cast(null as Nullable(String))                                            as oasis_product_code,
        toNullable(fusion_transaction_id)                                         as fusion_transaction_id,
        toUInt32(1)                                                               as fusion_transaction_count,
        toNullable(transaction_date)                                              as fusion_transaction_date,
        primary_quantity                                                          as movement_quantity,
        if(valuation_unit_cost is not null, 'fusion_valuation', 'none')           as cost_source,
        -- an uncosted line is a plain 0 (quantity x 0 would give -0 on issues)
        if(valuation_unit_cost is not null, primary_quantity * assumeNotNull(valuation_unit_cost), 0) as movement_cost,
        cast(null as Nullable(Float64))                                           as oasis_cost_amount,
        lot_number,
        expiry_date
    from fusion
    where go_live_date is not null and transaction_date >= go_live_date
      and (reference_status in ('not_integration', 'not_in_oasis')
           or (reference_status = 'oasis_out_of_scope'
               and ifNull(oasis_scope_reason, '') not in ('reversed_invoice', 'creditar', 'package_header')))
),

lines as (
    select * from identity_rows
    union all
    select * from fusion_only_rows
)

select
    l.movement_key                                                  as movement_key,
    l.branch_key                                                    as branch_key,
    {{ hnh_date_key('l.line_date') }}                               as date_key,
    ifNull(s.store_key, toInt64(-1))                                as store_key,
    ifNull(ts.store_key, toInt64(-1))                               as transfer_store_key,
    ifNull(i.item_key, toInt64(-1))                                 as item_key,
    {{ hnh_surrogate_key(['l.movement_type']) }}                    as movement_type_key,
    l.movement_type                                                 as movement_type,
    l.source_system                                                 as source_system,
    l.is_in_oasis                                                   as is_in_oasis,
    l.is_in_fusion                                                  as is_in_fusion,
    l.is_fusion_gap                                                 as is_fusion_gap,
    l.is_opening_balance                                            as is_opening_balance,
    {{ hnh_is_consumption('l.movement_type') }}                     as is_consumption,
    l.oasis_line_id                                                 as oasis_line_id,
    l.oasis_doc_no                                                  as oasis_doc_no,
    l.oasis_product_code                                            as oasis_product_code,
    l.fusion_transaction_id                                         as fusion_transaction_id,
    l.fusion_transaction_count                                      as fusion_transaction_count,
    {{ hnh_date_key_in_range('l.fusion_transaction_date') }}        as fusion_transaction_date_key,
    l.movement_quantity                                             as primary_quantity,
    if(l.movement_quantity != 0, abs(l.movement_cost / l.movement_quantity), 0) as unit_cost,
    l.movement_cost                                                 as cost_amount,
    l.cost_source                                                   as cost_source,
    l.oasis_cost_amount                                             as oasis_cost_amount,
    toUInt8(l.movement_cost != 0 and ifNull(l.oasis_cost_amount, 0) != 0
            and (abs(l.movement_cost) / abs(ifNull(l.oasis_cost_amount, 0)) < 0.5
                 or abs(l.movement_cost) / abs(ifNull(l.oasis_cost_amount, 0)) > 2)) as is_cost_mismatch,
    -- 0 - x rather than -x, so a zero stays +0
    if(is_consumption = 1, 0 - l.movement_quantity, 0)              as consumption_quantity,
    if(is_consumption = 1, 0 - l.movement_cost, 0)                  as consumption_cost,
    l.lot_number                                                    as lot_number,
    l.expiry_date                                                   as expiry_date,
    now()                                                           as _loaded_at
from lines as l
left join (select store_key from {{ ref('dim_store') }}) as s on s.store_key = l.store_key_raw
left join (select store_key from {{ ref('dim_store') }}) as ts on ts.store_key = l.transfer_store_key_raw
left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = l.item_key_raw
{{ hnh_settings() }}
