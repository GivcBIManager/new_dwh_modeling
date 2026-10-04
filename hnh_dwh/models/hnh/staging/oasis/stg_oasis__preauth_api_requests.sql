select
    toUInt8(branch_id)                       as branch_id,
    toInt64(api_trans_id)                    as api_trans_id,
    {{ hnh_id('oasis_request_no') }}         as oasis_request_no,
    {{ hnh_id('patient_id') }}               as patient_id,
    {{ hnh_id('episode_no') }}               as episode_no,
    {{ hnh_id('purchaser_code') }}           as purchaser_code,
    {{ hnh_id('service_dept') }}             as service_dept,
    {{ hnh_code('physician_staff_id') }}     as physician_staff_id,
    {{ hnh_str('treatment_type') }}          as treatment_type,
    {{ hnh_str('diagnosis_code') }}          as diagnosis_code,
    {{ hnh_flag('transfer_request') }}       as is_transfer,
    {{ hnh_ksa_wall_clock('creation_date') }} as sent_at
from {{ hnh_oasis_source('api_pre_approval_req') }} final
