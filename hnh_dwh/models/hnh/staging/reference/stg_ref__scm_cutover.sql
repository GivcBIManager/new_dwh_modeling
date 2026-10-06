-- Per-branch Fusion go-live for inventory (date) and purchasing (first month, yyyymm); null = not live (spec 4.2).
select
    toUInt8(BRANCH_ID)                      as branch_id,
    INVENTORY_GO_LIVE_DATE                  as inventory_go_live_date,
    if(FIRST_FUSION_PURCHASING_MONTH is null, cast(null as Nullable(Int32)), toInt32(FIRST_FUSION_PURCHASING_MONTH)) as first_fusion_purchasing_month
from {{ source('reference', 'map_scm_cutover') }}
