select
    toUInt8(branch_id)                       as branch_id,
    toInt64(request_no)                      as request_no,
    {{ hnh_id('patient_id') }}               as patient_id,
    {{ hnh_id('episode_no') }}               as episode_no,
    {{ hnh_ksa_wall_clock('request_date') }} as requested_at,
    {{ hnh_code('status') }}                 as request_status,
    {{ hnh_id('contract_no') }}              as contract_no
from {{ hnh_oasis_source('authorisations_master') }} final
