{{ config(alias='dim_job', order_by='job_key') }}
select {{ hnh_surrogate_key(['job_id']) }} as job_key, toNullable(job_id) as job_id, job_code, job_name, full_part_time, regular_temporary, is_current
from {{ ref('stg_fusion__jobs') }}
union all
select toInt64(-1), null, null, 'Unknown', null, null, toUInt8(1)
