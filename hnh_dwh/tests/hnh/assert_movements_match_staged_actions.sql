-- fact_worker_movement holds exactly one row per staged assignment action the model admits (action date from the
-- history start, person known): no fan-out from the legal-employer, department or action joins and no rows lost.
select 'fact_worker_movement row count differs from admitted staged actions' as failure, f.n as fact_rows, m.n as staged_rows
from (select count() as n from {{ ref('hnh_fact_worker_movement') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_fusion__worker_movements') }}
    where action_date >= toDate32('{{ var("hnh_history_start_date") }}') and person_id is not null
) as m
where f.n != m.n
