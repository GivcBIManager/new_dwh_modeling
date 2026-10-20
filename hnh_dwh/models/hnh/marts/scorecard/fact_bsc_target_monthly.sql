{{ config(order_by='(bsc_kpi_key, branch_key, month_date_key)') }}

-- Fixed KPI targets per hospital and month (bsc ssas spec 6.2), from the first target year to the current year.
-- For a KPI, branch and month the first match wins:
--   1. rows of that year: the branch's row for the month, the branch's annual row (month 0), the all-hospitals row
--      (branch_id 0) for the month, the all-hospitals annual row;
--   2. otherwise the latest earlier annual row, the branch's before the all-hospitals one, so a standing target
--      carries on into a new year until the BI manager enters a newer one.
-- Targets of a KPI code missing from the catalogue are ignored. Branches 1-8 only.
with
    toYear(ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today())) as this_year_,
targets as (
    select t.kpi_code as kpi_code, t.branch_id as branch_id, t.year as year, t.month as month,
           t.target_value as target_value, t.scale_with_months as scale_with_months, t.source_basis as source_basis
    from {{ ref('stg_ref__bsc_target') }} as t
    inner join {{ ref('stg_ref__bsc_kpi') }} as k on k.kpi_code = t.kpi_code
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
        t.scale_with_months                                                       as scale_,
        t.source_basis                                                            as basis_
    from grid as g
    inner join targets as t on t.kpi_code = g.kpi_code
    where (t.branch_id = g.branch_key or t.branch_id = 0)
      and ((t.year = g.year and (t.month = g.month or t.month = 0)) or (t.year < g.year and t.month = 0))
)

select
    toInt64(bitShiftRight(cityHash64(concat(kpi_code, '|')), 1))  as bsc_kpi_key,
    branch_key                                                    as branch_key,
    toInt32(toUInt32(year) * 10000 + toUInt32(month) * 100 + 1)   as month_date_key,
    toFloat64(argMin(value_, rank_))                              as target_value,
    toUInt8(argMin(scale_, rank_))                                as scale_with_months,
    argMin(basis_, rank_)                                         as source_basis
from candidates
group by kpi_code, branch_key, year, month
