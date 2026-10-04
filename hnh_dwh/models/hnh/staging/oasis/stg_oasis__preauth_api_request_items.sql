select
    toUInt8(branch_id)                  as branch_id,
    toInt64(id)                         as request_item_id,
    {{ hnh_id('api_trans_id') }}        as api_trans_id,
    {{ hnh_str('item_no') }}            as item_no,
    {{ hnh_id('ios') }}                 as ios,
    {{ hnh_id('authorisation_no') }}    as authorisation_no,
    toFloat64OrNull(toString(quantity)) as quantity,
    toFloat64OrNull(replaceAll(trimBoth(ifNull(estimated_cost, '')), ',', '.')) as estimated_cost
from {{ hnh_oasis_source('api_pre_approval_req_details') }} final
