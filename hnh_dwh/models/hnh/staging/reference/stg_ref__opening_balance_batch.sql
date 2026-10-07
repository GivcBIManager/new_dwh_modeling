-- Fusion journal batches treated as opening balances although Fusion does not categorise them MRC Open Balances (O-P3-12).
select
    toUInt8(BRANCH_ID)                      as branch_id,
    toInt64(JE_BATCH_ID)                    as je_batch_id,
    {{ hnh_str('REASON') }}                 as reason
from {{ source('reference', 'map_opening_balance_batch') }}
