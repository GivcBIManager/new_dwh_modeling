{{ config(alias='vw_date_dim') }}

-- Old bsc.vw_date_dim (bsc spec 7.1) on gold.dim_date, from the start of the year five years back to today. The
-- expressions reproduce the old table exactly (2,111 rows checked, 0 differences), including its fiscal columns
-- (FiscalYear = year + 1, FiscalMonth starting at December). Offsets are computed at query time.
with ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_
select
    toDate32(date_day)                                               as `Date`,
    toUInt16(year)                                                   as Year,
    toDate32(start_of_year)                                          as StartOfYear,
    toDate32(toLastDayOfMonth(addMonths(start_of_year, 11)))         as EndOfYear,
    toUInt8(month)                                                   as Month,
    toDate32(start_of_month)                                         as StartOfMonth,
    toDate32(end_of_month)                                           as EndOfMonth,
    toInt64(toDayOfMonth(end_of_month))                              as DaysInMonth,
    toUInt64(year_month)                                             as YearMonthNumber,
    year_month_name                                                  as YearMonthName,
    toUInt8(day_of_month)                                            as Day,
    day_name                                                         as DayName,
    formatDateTime(date_day, '%a')                                   as DayNameShort,
    toUInt8(day_of_week)                                             as DayOfWeek,
    toUInt16(toDayOfYear(date_day))                                  as DayOfYear,
    month_name                                                       as MonthName,
    month_short                                                      as MonthNameShort,
    toUInt8(quarter)                                                 as Quarter,
    quarter_name                                                     as QuarterName,
    toUInt64(year_quarter)                                           as YearQuarterNumber,
    concat(toString(year), ' ', quarter_name)                        as YearQuarterName,
    toDate32(start_of_quarter)                                       as StartOfQuarter,
    toDate32(toLastDayOfMonth(addMonths(start_of_quarter, 2)))       as EndOfQuarter,
    toUInt8(iso_week)                                                as WeekOfYear,
    toDate32(toMonday(date_day))                                     as StartOfWeek,
    toDate32(toMonday(date_day) + 6)                                 as EndOfWeek,
    toInt64(year + 1)                                                as FiscalYear,
    toInt32(month % 12 + 1)                                          as FiscalMonth,
    toInt32(intDiv(month % 12, 3) + 1)                               as FiscalQuarter,
    toInt64(dateDiff('day', date_day, today_))                       as DayOffset,
    toInt64(dateDiff('month', date_day, today_))                     as MonthOffset,
    toInt64(dateDiff('quarter', date_day, today_))                   as QuarterOffset,
    toInt64(dateDiff('year', date_day, today_))                      as YearOffset
from {{ ref('dim_date') }}
where date_day between toStartOfYear(subtractYears(today_, 5)) and today_
