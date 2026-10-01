-- One fact row per operation whose slot has a patient.
select 'fact_surgery row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_surgery') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__operations') }} as o
    inner join {{ ref('stg_oasis__operating_slots') }} as sl
        on sl.branch_id = o.branch_id and sl.operating_slot_code = o.operating_slot_code
    where sl.patient_id is not null
      and coalesce(o.operation_started_at, sl.operation_started_at, sl.scheduled_start_at)
          >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
) as s
where f.n != s.n
