-- Review focus 4: tied posts, several licence documents or several contracts
-- must not multiply staff rows.
select 'staff count differs from staging' as failure, s.n as staged, d.n as in_dimension
from (select count() as n from {{ ref('stg_oasis__staff') }} where staff_id is not null) as s
cross join (select count() as n from {{ ref('dim_staff') }} where staff_key != -1) as d
where s.n != d.n
