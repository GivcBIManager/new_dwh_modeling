-- dim_patient must never carry a name, identifier or contact column.
select name
from system.columns
where database = '{{ ref("dim_patient").schema }}'
  and table = '{{ ref("dim_patient").identifier }}'
  and (name like '%name%' or name like '%national_id%' or name like '%passport%'
       or name like '%border%' or name like '%mobile%' or name like '%email%')
