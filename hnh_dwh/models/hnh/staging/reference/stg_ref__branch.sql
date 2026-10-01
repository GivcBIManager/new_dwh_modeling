select
    toUInt8(branch_id)          as branch_id,
    {{ hnh_str('branch_name') }} as branch_name,
    {{ hnh_str('city') }}        as city,
    toInt32(licensed_beds)      as licensed_beds,
    toInt64(oracle_ledger_id)   as fusion_ledger_id,
    toInt64(oracle_branch_id)   as fusion_branch_code,
    {{ hnh_str('pg_branch_code') }} as pg_branch_code
from {{ source('reference', 'branch_dict_source') }}
