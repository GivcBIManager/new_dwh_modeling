{{ config(alias='vw_hospital_beds_utilization') }}

-- Old bsc.vw_hospital_beds_utilization (bsc spec 7.3): stays in house during the month (countable admissions),
-- discharge ALOS (SSAS ALOS (days)) and bed nights of inpatient, non-excluded wards (SSAS Bed Occupancy %) per branch
-- and month from January of last year. available_beds is the month's average available beds. Months with stays only.
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_,
    today_ - 1 as yesterday_,
    subtractYears(toStartOfYear(yesterday_), 1) as from_date_,
months as (
    select distinct start_of_month as period, end_of_month
    from {{ ref('dim_date') }}
    where date_day between from_date_ and yesterday_
),
stays as (
    select a.branch_key as branch_key, m.period as period,
           count() as stays_in_house, countIf(a.is_ltc_to_date = 1) as ltc_stays
    from {{ ref('fact_admission') }} as a
    cross join months as m
    where a.is_countable = 1 and a.branch_key between 1 and 8
      and toDate(a.admitted_at) <= m.end_of_month
      and toDate(coalesce(a.physical_discharge_at, now())) >= m.period
    group by branch_key, period
),
occupancy as (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(date_key))) as period,
           sum(is_available) as bed_days_available, sum(is_occupied) as bed_days_occupied, uniqExact(date_key) as days
    from {{ ref('fact_bed_occupancy_daily') }}
    where is_inpatient_ward = 1 and is_excluded_ward = 0 and branch_key between 1 and 8
      and date_key between toInt32(toYYYYMMDD(from_date_)) and toInt32(toYYYYMMDD(yesterday_))
    group by branch_key, period
),
discharges as (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(physical_discharge_date_key))) as period,
           avg(los_days) as alos_all, avgOrNullIf(los_days, is_ltc = 1) as alos_ltc, avgOrNullIf(los_days, is_ltc = 0) as alos_other
    from {{ ref('fact_admission') }}
    where is_countable = 1 and branch_key between 1 and 8
      and physical_discharge_date_key between toInt32(toYYYYMMDD(from_date_)) and toInt32(toYYYYMMDD(yesterday_))
    group by branch_key, period
)
select
    toUInt64(s.branch_key)                                                          as hospital_id,
    toDate32(s.period)                                                              as period,
    toUInt64(if(o.days = 0, 0, round(o.bed_days_available / o.days)))               as available_beds,
    toUInt64(s.stays_in_house)                                                      as census,
    toUInt64(s.ltc_stays)                                                           as ltc_census,
    toFloat64(ifNull(d.alos_all, 0))                                                as alos,
    CAST(d.alos_ltc AS Nullable(Float64))                                           as ltc_alos,
    CAST(d.alos_other AS Nullable(Float64))                                         as non_ltc_alos,
    toInt64(o.bed_days_occupied)                                                    as total_bed_nights,
    toFloat64(o.bed_days_available)                                                 as available_bed_nights,
    toFloat64(if(o.bed_days_available = 0, 0, o.bed_days_occupied / o.bed_days_available)) as occupancy_rate
from stays as s
left join occupancy as o on o.branch_key = s.branch_key and o.period = s.period
left join discharges as d on d.branch_key = s.branch_key and d.period = s.period
settings join_use_nulls = 0
