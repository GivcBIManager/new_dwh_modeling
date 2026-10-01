-- Every appointment slot with a date inside the dim_date range is counted exactly once.
-- This also proves an incremental run equals a full refresh.
select a.branch_key as branch_key, a.slots as in_aggregate, s.slots as in_staging
from (
    select branch_key, sum(slots_total) as slots
    from {{ ref('agg_clinic_capacity_daily') }}
    group by branch_key
) as a
inner join (
    select branch_id as branch_key, count() as slots
    from {{ ref('stg_oasis__appointments') }}
    where ifNull(slot_date, toDate(starts_at)) between toDate('{{ var("hnh_history_start_date") }}')
          and (select max(date_day) from {{ ref('dim_date') }})
    group by branch_id
) as s on s.branch_key = a.branch_key
where a.slots != s.slots
