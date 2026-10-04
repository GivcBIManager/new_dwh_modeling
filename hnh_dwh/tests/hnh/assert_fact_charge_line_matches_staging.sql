-- Every staged charge in the window is in the fact except superseded R rows.
select 'fact_charge_line row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_charge_line') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(delivered_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
      and (cancel_flag is null or cancel_flag != 'R')
) as s
where f.n != s.n
