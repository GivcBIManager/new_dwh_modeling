{{ config(severity='warn') }}
-- Active scorecard KPIs with a fixed target that has no target for a hospital in the current year (bsc ssas spec 6.2).
select k.kpi_code, b.branch_key
from {{ ref('dim_bsc_kpi') }} as k
cross join (select toUInt8(number + 1) as branch_key from numbers(8)) as b
left anti join (
    select distinct bsc_kpi_key, branch_key
    from {{ ref('fact_bsc_target_monthly') }}
    where intDiv(month_date_key, 10000) = toYear(today())
) as t on t.bsc_kpi_key = k.bsc_kpi_key and t.branch_key = b.branch_key
where k.is_active = 1 and k.target_source = 'fixed'
