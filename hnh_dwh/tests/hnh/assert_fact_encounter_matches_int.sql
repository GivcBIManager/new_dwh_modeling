-- fact_encounter must hold every int_encounter row inside the history window (walk-ins included).
select 'fact_encounter row count differs from int_encounter within the window' as failure, f.n as fact_rows, i.n as int_rows
from (select count() as n from {{ ref('fact_encounter') }}) as f
cross join (
    select count() as n
    from {{ ref('int_encounter') }}
    where encounter_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
) as i
where f.n != i.n
