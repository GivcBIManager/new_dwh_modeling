select
    toUInt8(branch_id)                 as branch_id,
    toInt64(patient_id)                as patient_id,
    toInt64(episode_no)                as episode_no,
    toInt64(responsibility_seq)        as responsibility_seq,
    {{ hnh_id('purchaser_code') }}     as purchaser_code,
    {{ hnh_id('policy_code') }}        as policy_code,
    {{ hnh_id('contract_no') }}        as contract_no,
    {{ hnh_code('status') }}           as status
from {{ hnh_oasis_source('patient_bill_agreements') }} final
