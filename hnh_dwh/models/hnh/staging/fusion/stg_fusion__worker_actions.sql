select {{ hnh_code('action_code') }} as action_code, {{ hnh_code('action_reason_code') }} as action_reason_code,
       any({{ hnh_str('action_name') }}) as action_name, any({{ hnh_str('action_reason_name') }}) as action_reason_name
from {{ hnh_fusion_source('dim_worker_action') }} final
group by action_code, action_reason_code
