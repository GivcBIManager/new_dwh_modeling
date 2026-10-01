-- Review focus 3: a patient whose nationality, marital or occupation code is
-- missing from codes_data must still be in the dimension.
select 'patient count differs from staging' as failure, s.n as staged, d.n as in_dimension
from (select count() as n from {{ ref('stg_oasis__patients') }}) as s
cross join (select count() as n from {{ ref('dim_patient') }} where patient_key != -1) as d
where s.n != d.n
