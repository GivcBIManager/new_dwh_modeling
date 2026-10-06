-- Lot expiry dates run from 1930 to 2299 (spec F14), so they are Date32.
select
    inventory_item_id,
    organization_id,
    assumeNotNull({{ hnh_str('lot_number') }}) as lot_number,
    toDate32(expiration_date)               as expiration_date
from {{ hnh_fusion_source('dim_lot') }} final
where {{ hnh_str('lot_number') }} is not null
