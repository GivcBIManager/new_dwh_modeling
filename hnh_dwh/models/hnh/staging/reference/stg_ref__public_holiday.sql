select
    toDate(holiday_date)   as date_day,
    any(holiday_name)      as holiday_name
from {{ source('reference', 'map_public_holiday') }}
group by date_day
