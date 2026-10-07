-- fact_purchase_line holds every Fusion PO schedule in scope (ship-to branch with a first Fusion purchasing month, PO
-- created in or after it) exactly once (spec 8).
with expected as (
    select count() as n
    from {{ ref('stg_fusion__po_schedules') }} as s
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = s.ship_to_organization_id
    inner join {{ ref('stg_ref__scm_cutover') }} as k on k.branch_id = o.branch_key
    where s.po_creation_date is not null and k.first_fusion_purchasing_month is not null
      and toInt32(toYYYYMM(s.po_creation_date)) >= k.first_fusion_purchasing_month
),
actual as (
    select count() as n, uniqExact(fusion_line_location_id) as distinct_schedules
    from {{ ref('fact_purchase_line') }} where source_system = 'fusion'
)
select e.n as expected_schedules, a.n as fact_rows, a.distinct_schedules
from expected as e cross join actual as a
where e.n != a.n or a.n != a.distinct_schedules
