select job_id, {{ hnh_str('job_code') }} as job_code, {{ hnh_str('job_name') }} as job_name,
       {{ hnh_code('full_part_time') }} as full_part_time, {{ hnh_code('regular_temporary') }} as regular_temporary,
       toUInt8(ifNull(is_current, '') = 'Y') as is_current
from {{ hnh_fusion_source('dim_job') }} final
order by valid_from desc, valid_to desc
limit 1 by job_id
