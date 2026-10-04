select
    toUInt8(branch_id)                 as branch_id,
    toInt64(policy_code)               as policy_code,
    {{ hnh_id('purchaser_code') }}     as purchaser_code,
    {{ hnh_code('account_no') }}       as account_no,
    {{ hnh_str('description') }}       as description,
    toUInt8(ifNull(toString(active_flag), 'Y') != 'N') as is_active
from {{ hnh_oasis_source('policies') }} final
