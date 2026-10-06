select
    transaction_id,
    organization_id,
    {{ hnh_code('subinventory_code') }}     as subinventory_code,
    transfer_organization_id,
    {{ hnh_code('transfer_subinventory') }} as transfer_subinventory,
    inventory_item_id,
    transaction_type_id,
    {{ hnh_str('transaction_reference') }}  as transaction_reference,
    rcv_transaction_id,
    assumeNotNull(toDate(transaction_date)) as transaction_date,
    toFloat64(ifNull(primary_quantity, 0))  as primary_quantity,
    toFloat64(ifNull(transaction_quantity, 0)) as transaction_quantity,
    {{ hnh_code('transaction_uom') }}       as transaction_uom
from {{ hnh_fusion_source('fact_inventory_transaction') }} final
where transaction_date is not null
