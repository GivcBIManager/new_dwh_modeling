{{ config(order_by='(hr_kpi_key, branch_key, month_date_key)') }}

-- HR KPI targets per hospital and month, from the first target year to the current year. Same fallback as
-- fact_bsc_target_monthly. For a KPI, branch and month the first match wins:
--   1. rows of that year: the branch's row for the month, the branch's annual row (month 0), the all-hospitals row
--      (branch_id 0) for the month, the all-hospitals annual row;
--   2. otherwise the latest earlier annual row, the branch's before the all-hospitals one.
-- Only active KPIs whose target_source is 'fixed' (BSC-sourced KPIs take their target from the scorecard).
-- Branches 1-8 only.
with
    toYear(ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today())) as this_year_,
targets as (
    select t.kpi_code as kpi_code, t.branch_id as branch_id, t.year as year, t.month as month,
           t.target_value as target_value, t.watch_value as watch_value, t.scale_with_months as scale_with_months,
           t.source_basis as source_basis, t.is_placeholder as is_placeholder
    from {{ ref('stg_ref__hr_target') }} as t
    inner join {{ ref('stg_ref__hr_kpi') }} as k on k.kpi_code = t.kpi_code
    where k.target_source = 'fixed' and k.status = 'active'
),

kpi_years as (
    select kpi_code, toUInt16(arrayJoin(range(toUInt32(min(year)), toUInt32(greatest(max(year), this_year_)) + 1))) as year
    from targets
    group by kpi_code
),

grid as (
    select ky.kpi_code as kpi_code, b.branch_key as branch_key, ky.year as year, toUInt8(m.number + 1) as month
    from kpi_years as ky
    cross join (select toUInt8(number + 1) as branch_key from numbers(8)) as b
    cross join (select number from numbers(12)) as m
),

candidates as (
    select
        g.kpi_code                                                                as kpi_code,
        g.branch_key                                                              as branch_key,
        g.year                                                                    as year,
        g.month                                                                   as month,
        tuple(toUInt8(t.year < g.year), toUInt16(g.year - t.year),
              toUInt8(t.branch_id = 0) * 2 + toUInt8(t.month = 0))                as rank_,
        t.target_value                                                            as value_,
        t.watch_value                                                             as watch_,
        t.scale_with_months                                                       as scale_,
        t.source_basis                                                            as basis_,
        t.is_placeholder                                                          as placeholder_
    from grid as g
    inner join targets as t on t.kpi_code = g.kpi_code
    where (t.branch_id = g.branch_key or t.branch_id = 0)
      and ((t.year = g.year and (t.month = g.month or t.month = 0)) or (t.year < g.year and t.month = 0))
)

select
    toInt64(bitShiftRight(cityHash64(concat(kpi_code, '|')), 1))  as hr_kpi_key,
    branch_key                                                    as branch_key,
    toInt32(toUInt32(year) * 10000 + toUInt32(month) * 100 + 1)   as month_date_key,
    toFloat64(argMin(value_, rank_))                              as target_value,
    toFloat64(argMin(watch_, rank_))                              as watch_value,
    toUInt8(argMin(scale_, rank_))                                as scale_with_months,
    argMin(basis_, rank_)                                         as source_basis,
    toUInt8(argMin(placeholder_, rank_))                          as is_placeholder
from candidates
group by kpi_code, branch_key, year, month
