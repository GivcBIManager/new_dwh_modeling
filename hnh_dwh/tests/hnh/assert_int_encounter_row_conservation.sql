-- The union must neither drop nor multiply rows.
select 'int_encounter row count differs from its inputs' as failure, e.n as encounters, s.n as inputs
from (select count() as n from {{ ref('int_encounter') }}) as e
cross join (
    select
        (select count() from {{ ref('stg_oasis__appointments') }} where patient_id is not null)
      + (select count() from {{ ref('stg_oasis__er_visits') }})
      + (select count() from {{ ref('int_admission') }}) as n
) as s
where e.n != s.n
