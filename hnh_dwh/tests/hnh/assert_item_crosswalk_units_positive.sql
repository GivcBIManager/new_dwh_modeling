-- units_per_primary divides Oasis base-unit quantities into Fusion primary units; zero or negative values would break
-- every later primary-quantity conversion. Returns the offending rows.
select branch_key, product_code, inventory_item_id, units_per_primary
from {{ ref('int_item_crosswalk') }}
where units_per_primary <= 0
