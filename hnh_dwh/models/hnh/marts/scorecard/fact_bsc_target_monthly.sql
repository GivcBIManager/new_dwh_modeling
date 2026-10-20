{{ config(order_by='(bsc_kpi_key, branch_key, month_date_key)') }}

-- Fixed KPI targets per hospital and month (bsc ssas spec 6.2). For a KPI, branch and month the most specific row
-- wins: the branch's row for that month, the branch's annual row (month 0), the all-hospitals row (branch_id 0) for
-- that month, the all-hospitals annual row. Annual rows repeat on each month of their year. Branches 1-8 only.
with targets as (
    select kpi_code, branch_id, year, month, target_value, scale_with_months, source_basis
    from {{ ref('stg_ref__bsc_target') }}
),

grid as (
    select b.branch_key as branch_key, toUInt8(m.number + 1) as month
    from (select toUInt8(number + 1) as branch_key from numbers(8)) as b
    cross join (select number from numbers(12)) as m
),

candidates as (
    select
        t.kpi_code                                                as kpi_code,
        g.branch_key                                              as branch_key,
        t.year                                                    as year,
        g.month                                                   as month,
        toUInt8(t.branch_id = 0) * 2 + toUInt8(t.month = 0)       as priority,
        t.target_value                                            as value_,
        t.scale_with_months                                       as scale_,
        t.source_basis                                            as basis_
    from targets as t
    cross join grid as g
    where (t.branch_id = g.branch_key or t.branch_id = 0) and (t.month = g.month or t.month = 0)
)

select
    toInt64(bitShiftRight(cityHash64(concat(kpi_code, '|')), 1))  as bsc_kpi_key,
    branch_key                                                    as branch_key,
    toInt32(toUInt32(year) * 10000 + toUInt32(month) * 100 + 1)   as month_date_key,
    toFloat64(argMin(value_, priority))                           as target_value,
    toUInt8(argMin(scale_, priority))                             as scale_with_months,
    argMin(basis_, priority)                                      as source_basis
from candidates
group by kpi_code, branch_key, year, month
