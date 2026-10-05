{{ config(severity='warn') }}
-- Included-package names that match no PK product in any branch (renamed or retired products).
select p.package_description as package_description
from {{ ref('stg_ref__order_fulfilment_packages') }} as p
left join (
    select distinct upper(trimBoth(si.description)) as description_upper
    from {{ ref('stg_oasis__ios_master') }} as m
    inner join {{ ref('stg_oasis__service_items') }} as si
        on si.branch_id = m.branch_id and si.ios_main = m.ios_main
    where coalesce(m.product_category_code, si.product_category_code) = 'PK'
) as x on x.description_upper = p.package_description
where x.description_upper is null
settings join_use_nulls = 1
