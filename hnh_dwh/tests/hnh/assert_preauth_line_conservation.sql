-- Every Oasis authorisation line is one row; no line is duplicated.
select 'Oasis authorisation lines differ from staging' as failure, i.n as in_int, s.n as in_staging
from (select count() as n from {{ ref('int_preauth_line') }} where line_source = 'Oasis') as i
cross join (select count() as n from {{ ref('stg_oasis__authorisations') }}) as s
where i.n != s.n

union all

-- Every line requested inside the window reaches the fact.
select 'fact_preauth_line differs from int_preauth_line in the window', f.n, i.n
from (select count() as n from {{ ref('fact_preauth_line') }}) as f
cross join (
    select count() as n from {{ ref('int_preauth_line') }}
    where requested_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(requested_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
) as i
where f.n != i.n
