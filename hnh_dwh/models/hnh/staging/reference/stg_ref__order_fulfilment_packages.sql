-- Packages the old Order Fulfillment report kept although their category is PK
-- (vw_excluded_pakages_order_fulfillment). Every other PK product is excluded from leak scope.
select distinct upper(trimBoth(DESCRIPTION)) as package_description
from {{ source('reference', 'map_order_fulfilment_packages') }}
where trimBoth(DESCRIPTION) != ''
