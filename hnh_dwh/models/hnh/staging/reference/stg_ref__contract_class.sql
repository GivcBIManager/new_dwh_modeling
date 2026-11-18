-- The old warehouse's hand class of each contract (default.map_contract_class, a copy of the old server's
-- patient_contract_mapping). int_contract_class uses it when the Oasis class description gives no class.
select
    toUInt8(BRANCH_ID)                  as branch_id,
    toInt64(CONTRACT_NO)                as contract_no,
    toInt64(CLASS_ID)                   as class_id,
    upper(trimBoth(CLASSIFICATION))     as classification
from {{ source('reference', 'map_contract_class') }}
