select
    per_accrual_entry_id                    as accrual_entry_id,
    person_id,
    absence_plan_id,
    toDate32(accrual_period_date)           as accrual_period_date,
    {{ hnh_code('status') }}                as status,
    toFloat64(ifNull(begin_balance, 0))     as begin_balance,
    toFloat64(ifNull(accrued, 0))           as accrued,
    toFloat64(ifNull(used, 0))              as used,
    toFloat64(ifNull(end_balance, 0))       as end_balance
from {{ hnh_fusion_source('fact_absence_balance') }} final
