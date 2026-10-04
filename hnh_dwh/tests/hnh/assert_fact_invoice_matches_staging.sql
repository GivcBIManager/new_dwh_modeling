select 'fact_invoice row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_invoice') }}) as f
cross join (
    select count() as n from {{ ref('stg_oasis__episode_invoices') }}
    where created_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(created_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
) as s
where f.n != s.n
