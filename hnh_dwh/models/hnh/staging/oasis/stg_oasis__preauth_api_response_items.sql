select
    toUInt8(branch_id)                          as branch_id,
    toInt64(id)                                 as response_item_id,
    {{ hnh_id('res_id') }}                      as response_id,
    {{ hnh_str('item_no') }}                    as item_no,
    {{ hnh_code('status') }}                    as status,
    toFloat64OrNull(toString(approved_quantity)) as approved_quantity,
    toFloat64OrNull(toString(approved_amount))   as approved_amount,
    {{ hnh_str('error_text') }}                 as payer_comment
from {{ hnh_oasis_source('api_pre_approval_res_details') }} final
