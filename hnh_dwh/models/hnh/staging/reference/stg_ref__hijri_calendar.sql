select
    toDate(gregorian_date)   as date_day,
    toUInt16(hijri_year)     as hijri_year,
    toUInt8(hijri_month)     as hijri_month,
    toUInt8(hijri_day)       as hijri_day,
    hijri_month_name         as hijri_month_name
from {{ source('reference', 'map_hijri_calendar') }}
