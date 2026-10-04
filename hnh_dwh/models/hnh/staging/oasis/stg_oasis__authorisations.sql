select
    toUInt8(branch_id)                   as branch_id,
    toInt64(authorisation_no)            as authorisation_no,
    {{ hnh_id('request_no') }}           as request_no,
    {{ hnh_id('patient_id') }}           as patient_id,
    {{ hnh_id('episode_no') }}           as episode_no,
    {{ hnh_id('ios') }}                  as ios,
    toFloat64OrNull(toString(no_requested))  as requested_qty,
    toFloat64OrNull(toString(no_authorised)) as authorised_qty,
    toFloat64OrNull(toString(no_used))       as used_qty,
    {{ hnh_code('authorised_flag') }}    as authorised_flag,
    toFloat64OrNull(toString(amount_authorised)) as amount_authorised,
    {{ hnh_flag('transfer_request') }}   as is_transfer,
    {{ hnh_str('com_req_id') }}          as com_req_id
from {{ hnh_oasis_source('authorisations') }} final
