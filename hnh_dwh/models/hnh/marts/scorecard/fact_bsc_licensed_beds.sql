{{ config(order_by='(branch_key, year_date_key)') }}

-- Licensed beds per hospital and year (KPI 60), keyed on 1 January. A year without a row takes the latest earlier
-- year, up to the current year, so the figure carries on until the BI manager enters a new one. Branches 1-8.
with
    toYear(ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today())) as this_year_,
beds as (
    select branch_id, year, licensed_beds
    from {{ ref('stg_ref__bsc_licensed_beds') }}
    where branch_id between 1 and 8
),

years as (
    select branch_id, toUInt16(arrayJoin(range(toUInt32(min(year)), toUInt32(greatest(max(year), this_year_)) + 1))) as year
    from beds
    group by branch_id
)

select
    toUInt8(y.branch_id)                                          as branch_key,
    toInt32(toUInt32(y.year) * 10000 + 101)                       as year_date_key,
    toFloat64(argMax(b.licensed_beds, b.year))                    as licensed_beds
from years as y
inner join beds as b on b.branch_id = y.branch_id and b.year <= y.year
group by y.branch_id, y.year
