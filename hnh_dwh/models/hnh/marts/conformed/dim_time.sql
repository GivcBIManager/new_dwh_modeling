{{ config(order_by='time_key') }}

with minutes as (
    select toInt16(number) as time_key, toDateTime('2000-01-01 00:00:00') + toIntervalMinute(number) as t
    from numbers(1440)
)

select
    time_key                                             as time_key,
    formatDateTime(t, '%H:%i')                           as time_label,
    toUInt8(toHour(t))                                   as hour,
    toUInt8(toMinute(t))                                 as minute,
    formatDateTime(toStartOfFifteenMinutes(t), '%H:%i')  as quarter_hour,
    {{ hnh_shift('t') }}                                 as shift
from minutes
