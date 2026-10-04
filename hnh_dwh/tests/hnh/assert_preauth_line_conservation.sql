-- Every Oasis authorisation line is one row; no line is duplicated.
select 'Oasis authorisation lines differ from staging' as failure, i.n as in_int, s.n as in_staging
from (select count() as n from {{ ref('int_preauth_line') }} where line_source = 'Oasis') as i
cross join (select count() as n from {{ ref('stg_oasis__authorisations') }}) as s
where i.n != s.n
