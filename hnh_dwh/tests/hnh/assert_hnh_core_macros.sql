-- Each branch returns a row only when a core macro misbehaves.
select 'surrogate key differs by numeric type' as failure
where {{ hnh_surrogate_key(["toInt64(1)", "toInt64(25)"]) }} != {{ hnh_surrogate_key(["toUInt8(1)", "toFloat64(25)"]) }}

union all
select 'surrogate key collides across component boundary'
where {{ hnh_surrogate_key(["toInt64(1)", "toInt64(25)"]) }} = {{ hnh_surrogate_key(["toInt64(12)", "toInt64(5)"]) }}

union all
select 'surrogate key is not -1 for a null component'
where {{ hnh_surrogate_key(["toUInt8(1)", "cast(null as Nullable(Int64))"]) }} != -1

union all
select 'surrogate key is negative'
where {{ hnh_surrogate_key(["toUInt8(8)", "'R4809'"]) }} < 0

union all
select 'hnh_id keeps zero'
where {{ hnh_id("toFloat64(0)") }} is not null

union all
select 'hnh_id loses a float id'
where {{ hnh_id("toFloat64(280967596)") }} != 280967596

union all
select 'hnh_str keeps an empty string'
where {{ hnh_str("'   '") }} is not null

union all
select 'hnh_code does not trim and upper-case'
where {{ hnh_code("' r4809 '") }} != 'R4809'

union all
select 'hnh_flag wrong'
where {{ hnh_flag("'Y'") }} != 1 or {{ hnh_flag("'N'") }} != 0 or {{ hnh_flag("cast(null as Nullable(String))") }} != 0

union all
select 'wall clock is shifted'
where toString({{ hnh_ksa_wall_clock("toDateTime64('2026-10-01 06:03:21', 6, 'UTC')") }}) != '2026-10-01 06:03:21'

union all
select 'julian conversion wrong'
where {{ hnh_julian_to_date("toFloat64(2440588)") }} != toDate('1970-01-01')
   or {{ hnh_julian_to_date("toFloat64(2460585)") }} != toDate('2024-10-01')

union all
select 'date key wrong'
where {{ hnh_date_key("toDateTime('2026-10-01 23:59:59', 'Asia/Riyadh')") }} != 20261001
   or {{ hnh_date_key("cast(null as Nullable(DateTime))") }} is not null

union all
select 'time key wrong'
where {{ hnh_time_key("toDateTime('2026-10-01 16:30:59', 'Asia/Riyadh')") }} != 990

union all
select 'minutes guard wrong'
where {{ hnh_minutes_between("toDateTime('2026-10-01 10:00:00')", "toDateTime('2026-10-01 10:45:00')") }} != 45
   or {{ hnh_minutes_between("toDateTime('2026-10-01 10:00:00')", "toDateTime('2026-10-01 09:00:00')") }} is not null
   or {{ hnh_minutes_between("toDateTime('2026-10-01 10:00:00')", "toDateTime('2026-10-03 10:00:00')") }} is not null

union all
select 'left join miss is not null'
from (
    select b.v as v
    from (select 1 as k) as a
    left join (select 2 as k, 5 as v) as b on a.k = b.k
    {{ hnh_settings() }}
)
where v is not null

union all
select 'left join miss inside a wrapped union is not null'
from (
    select * from (
        select b.v as v
        from (select 1 as k) as a
        left join (select 2 as k, 5 as v) as b on a.k = b.k
        union all
        select cast(null as Nullable(UInt8))
    )
    {{ hnh_settings() }}
)
where v is not null
