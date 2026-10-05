{{ config(alias='dim_gl_period', order_by='period_key') }}

-- Monthly and quarterly adjustment periods of calendar "Monthly 12 4"; the stray yearly period (period_year 1) is left out.
-- period_key = year * 100 + period number, so it also gives the running order (an adjustment period follows its quarter).
select
    toInt32(assumeNotNull(period_year) * 100 + assumeNotNull(period_num))  as period_key,
    period_name,
    toUInt16(assumeNotNull(period_year))                                   as fiscal_year,
    toUInt8(assumeNotNull(period_num))                                     as period_num,
    toUInt8(ifNull(quarter_num, 0))                                        as quarter_num,
    assumeNotNull(start_date)                                              as start_date,
    assumeNotNull(end_date)                                                as end_date,
    {{ hnh_date_key('assumeNotNull(end_date)') }}                          as end_date_key,
    toStartOfMonth(assumeNotNull(end_date))                                as month_start,
    is_adjustment
from {{ ref('stg_fusion__gl_periods') }}
where ifNull(period_year, 0) >= 1900 and start_date is not null and end_date is not null
