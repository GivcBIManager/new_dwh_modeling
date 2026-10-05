-- One fact row per staged claim line whose claim visit falls in the window.
select 'fact_claim_line row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_claim_line') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__claim_services') }} as c
    inner join {{ ref('stg_oasis__claim_visits') }} as v on v.branch_id = c.branch_id and v.visit_id = c.visit_id
    where v.statement_end_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(v.statement_end_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
) as s
where f.n != s.n
