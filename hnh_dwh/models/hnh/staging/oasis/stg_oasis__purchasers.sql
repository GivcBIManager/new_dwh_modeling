select
    toUInt8(branch_id)                 as branch_id,
    toInt64(purchaser_code)            as purchaser_code,
    {{ hnh_str('description') }}       as description,
    {{ hnh_code('account_code') }}     as account_code,
    {{ hnh_code('account_type') }}     as account_type,
    toInt64(account_c_id)              as account_c_id,
    {{ hnh_str('cchi_no') }}           as cchi_no,
    {{ hnh_str('nphies_license') }}    as nphies_license,
    {{ hnh_flag('is_tpa') }}           as is_tpa,
    toUInt8(ifNull(toString(activity_indicator), 'Y') != 'N') as is_active
from {{ hnh_oasis_source('purchasers') }} final
