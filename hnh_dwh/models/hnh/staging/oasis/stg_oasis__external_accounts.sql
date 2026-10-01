select
    toUInt8(branch_id)                 as branch_id,
    {{ hnh_code('account_code') }}     as account_code,
    {{ hnh_code('account_type') }}     as account_type,
    toInt64(c_id)                      as c_id,
    {{ hnh_str('account_name') }}      as account_name,
    {{ hnh_str('group_code') }}        as group_code
from {{ source('oasis', 'external_accounts_data') }} final
