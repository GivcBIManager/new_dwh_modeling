-- Oasis contracts (a policy's terms for one class of members); class_id points to stg_oasis__policy_classes.
-- int_contract_class reads the class of each contract.
select
    toUInt8(branch_id)          as branch_id,
    toInt64(contract_no)        as contract_no,
    {{ hnh_id('class_id') }}    as class_id
from {{ hnh_oasis_source('contracts') }} final
