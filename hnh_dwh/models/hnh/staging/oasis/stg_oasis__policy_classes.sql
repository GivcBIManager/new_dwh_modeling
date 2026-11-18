-- Oasis policy classes; the description carries the insurance class (VIP, A, B, C) that int_contract_class extracts.
select
    toUInt8(branch_id)              as branch_id,
    toInt64(class_id)               as class_id,
    {{ hnh_str('description') }}    as description
from {{ hnh_oasis_source('policy_classes') }} final
