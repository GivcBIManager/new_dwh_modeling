select
    toUInt8(branch_id)                        as branch_id,
    toInt64(id)                               as response_id,
    {{ hnh_id('req_api_trans_id') }}          as api_trans_id,
    {{ hnh_ksa_wall_clock('creation_date') }} as responded_at,
    {{ hnh_code('auth_status') }}             as auth_status
from {{ hnh_oasis_source('api_pre_approval_res') }} final
