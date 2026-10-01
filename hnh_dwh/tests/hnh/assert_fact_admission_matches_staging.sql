-- Every admission in the reporting window is in the fact exactly once.
{% set start_ts = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
select 'fact_admission row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_admission') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__admissions') }}
    where admitted_at >= {{ start_ts }}
       or (admitted_at < {{ start_ts }} and (physical_discharge_at is null or physical_discharge_at >= {{ start_ts }}))
) as s
where f.n != s.n
