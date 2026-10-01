select
    toUInt8(BranchId)           as branch_id,
    TableDate                   as target_date,
    Scenario                    as scenario,
    CareType                    as care_type,
    StayType                    as stay_type,
    {{ hnh_str('Creditor') }}   as creditor,
    {{ hnh_str('Speciality') }} as specialty,
    Census                      as census,
    Episodes                    as episodes,
    CPE                         as cost_per_episode,
    ALOS                        as alos,
    Revenue                     as revenue,
    toUInt8(is_last_value)      as is_latest
from {{ source('reference', 'budget_data') }}
