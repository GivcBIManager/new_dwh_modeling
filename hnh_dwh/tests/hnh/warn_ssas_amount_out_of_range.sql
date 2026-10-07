{{ config(severity='warn') }}
-- SSAS spec 4.2 rule 4 (ruling R4): amounts that are not finite or have abs >= 1e14 cannot be stored as SSAS fixed
-- decimal; the gold.ssas_* views load them as blank. These are source errors (e.g. typo quantities); fix them in Oasis.
select 'fact_order_line' as model, 'ordered_value' as column_name, branch_key, ordered_value as value
from {{ ref('fact_order_line') }} where not isFinite(ordered_value) or abs(ordered_value) >= 1e14
union all
select 'fact_preauth_line', 'approved_estimated_amount', branch_key, approved_estimated_amount
from {{ ref('fact_preauth_line') }}
where approved_estimated_amount is not null and (not isFinite(approved_estimated_amount) or abs(approved_estimated_amount) >= 1e14)
