{{ config(order_by='date_key') }}

with days as (
    select toDate('2008-01-01') + number as date_day
    from numbers(dateDiff('day', toDate('2008-01-01'), toDate(concat(toString(toYear(today()) + 2), '-12-31'))) + 1)
)

select
    toInt32(toYYYYMMDD(d.date_day))                 as date_key,
    d.date_day                                      as date_day,
    toYear(d.date_day)                              as year,
    toQuarter(d.date_day)                           as quarter,
    concat('Q', toString(toQuarter(d.date_day)))    as quarter_name,
    toYear(d.date_day) * 10 + toQuarter(d.date_day) as year_quarter,
    toMonth(d.date_day)                             as month,
    dateName('month', d.date_day)                   as month_name,
    formatDateTime(d.date_day, '%b')                as month_short,
    toYear(d.date_day) * 100 + toMonth(d.date_day)  as year_month,
    formatDateTime(d.date_day, '%Y-%b')             as year_month_name,
    toDayOfMonth(d.date_day)                        as day_of_month,
    toDayOfWeek(d.date_day)                         as day_of_week,
    dateName('weekday', d.date_day)                 as day_name,
    toISOWeek(d.date_day)                           as iso_week,
    toStartOfMonth(d.date_day)                      as start_of_month,
    toLastDayOfMonth(d.date_day)                    as end_of_month,
    toStartOfQuarter(d.date_day)                    as start_of_quarter,
    toStartOfYear(d.date_day)                       as start_of_year,
    toYear(d.date_day)                              as fiscal_year,
    toUInt8(toDayOfWeek(d.date_day) in (5, 6))      as is_weekend,
    toUInt8(toDayOfWeek(d.date_day) != 5)           as is_clinic_working_day,
    h.hijri_year                                    as hijri_year,
    h.hijri_month                                   as hijri_month,
    h.hijri_day                                     as hijri_day,
    h.hijri_month_name                              as hijri_month_name,
    toUInt8(p.holiday_name is not null)             as is_public_holiday,
    p.holiday_name                                  as holiday_name,
    dateDiff('day', d.date_day, today())            as day_offset,
    dateDiff('month', d.date_day, today())          as month_offset,
    dateDiff('quarter', d.date_day, today())        as quarter_offset,
    dateDiff('year', d.date_day, today())           as year_offset,
    toUInt8(d.date_day < today())                   as is_past
from days as d
left join {{ ref('stg_ref__hijri_calendar') }} as h on h.date_day = d.date_day
left join {{ ref('stg_ref__public_holiday') }} as p on p.date_day = d.date_day
{{ hnh_settings() }}
