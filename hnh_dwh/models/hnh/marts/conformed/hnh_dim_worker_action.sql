{{ config(alias='dim_worker_action', order_by='worker_action_key') }}
select {{ hnh_surrogate_key(['action_code', 'action_reason_code']) }} as worker_action_key,
       toNullable(action_code) as action_code, toNullable(action_reason_code) as action_reason_code,
       action_name, action_reason_name, {{ hnh_movement_group('action_code') }} as movement_group
from {{ ref('stg_fusion__worker_actions') }}
union all
select toInt64(-1), null, null, 'Unknown', null, 'Other'
