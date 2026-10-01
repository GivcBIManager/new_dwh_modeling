{{ config(order_by='(branch_key, month_start)') }}

with encounters as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(encounter_date_key))) as month_start,
        uniqExactIf(encounter_key, encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0)  as census,
        uniqExactIf(encounter_key, encounter_type = 'OP' and is_arrived = 1 and is_cancelled = 0)           as op_visits,
        uniqExactIf(encounter_key, encounter_type = 'ER' and is_cancelled = 0)                              as er_visits,
        uniqExactIf(episode_key, encounter_type in ('OP', 'ER') and is_arrived = 1 and is_cancelled = 0 and is_follow_up = 0) as episodes,
        -- old bsc.vw_customer: OP and ER together, arrived, old cancellation list
        uniqExactIf(encounter_key, legacy_in_op_census = 1 and is_arrived = 1)                              as legacy_census,
        uniqExactIf(encounter_key, legacy_in_op_census = 1 and is_arrived = 1 and encounter_type = 'OP')    as legacy_op_census,
        uniqExactIf(encounter_key, legacy_in_op_census = 1 and is_arrived = 1 and encounter_type = 'ER')    as legacy_er_census,
        sumIf(wait_minutes_raw, legacy_in_op_census = 1 and is_arrived = 1 and encounter_type = 'OP')       as legacy_wait_minutes_sum
    from {{ ref('fact_encounter') }}
    group by branch_key, month_start
),

admissions as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(admit_date_key))) as month_start,
        countIf(is_countable = 1)                                                    as admissions,
        countIf(legacy_in_vw_inpatients = 1 and legacy_is_wrong_admission = 0)       as legacy_admissions
    from {{ ref('fact_admission') }}
    group by branch_key, month_start
),

discharges as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(physical_discharge_date_key)))) as month_start,
        countIf(is_countable = 1)                                                    as discharges,
        avgIf(los_days, is_countable = 1 and is_ltc = 0)                             as alos_non_ltc,
        countIf(legacy_in_vw_inpatients = 1 and legacy_is_wrong_admission = 0)       as legacy_discharges,
        avgIf(los_days, legacy_in_vw_inpatients = 1 and legacy_is_wrong_admission = 0 and legacy_is_ltc = 0) as legacy_alos_non_ltc
    from {{ ref('fact_admission') }}
    where physical_discharge_date_key is not null
    group by branch_key, month_start
),

beds as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(date_key))) as month_start,
        sumIf(is_occupied, is_excluded_ward = 0 and is_inpatient_ward = 1)   as occupied_bed_nights,
        sumIf(is_available, is_excluded_ward = 0 and is_inpatient_ward = 1)  as available_bed_nights
    from {{ ref('fact_bed_occupancy_daily') }}
    group by branch_key, month_start
),

spine as (
    select branch_key, month_start from encounters
    union distinct select branch_key, month_start from admissions
    union distinct select branch_key, month_start from discharges
    union distinct select branch_key, month_start from beds
),

branches as (
    select branch_key, legacy_current_available_beds
    from {{ ref('hnh_dim_branch') }}
)

select
    s.branch_key                           as branch_key,
    s.month_start                          as month_start,
    ifNull(e.census, 0)                    as census,
    ifNull(e.op_visits, 0)                 as op_visits,
    ifNull(e.er_visits, 0)                 as er_visits,
    ifNull(e.episodes, 0)                  as episodes,
    ifNull(a.admissions, 0)                as admissions,
    ifNull(d.discharges, 0)                as discharges,
    d.alos_non_ltc                         as alos_non_ltc,
    ifNull(b.occupied_bed_nights, 0)       as occupied_bed_nights,
    ifNull(b.available_bed_nights, 0)      as available_bed_nights,
    if(ifNull(b.available_bed_nights, 0) = 0, null, b.occupied_bed_nights / b.available_bed_nights) as occupancy_rate,
    -- old bsc.vw_hospital_beds_utilization: today's bed count x (days in month - 1)
    ifNull(br.legacy_current_available_beds, 0) * (toDayOfMonth(toLastDayOfMonth(s.month_start)) - 1) as legacy_available_bed_nights,
    if(legacy_available_bed_nights = 0, null, ifNull(b.occupied_bed_nights, 0) / legacy_available_bed_nights) as legacy_occupancy_rate,
    ifNull(e.legacy_census, 0)             as legacy_census,
    ifNull(e.legacy_op_census, 0)          as legacy_op_census,
    ifNull(e.legacy_er_census, 0)          as legacy_er_census,
    ifNull(a.legacy_admissions, 0)         as legacy_admissions,
    ifNull(d.legacy_discharges, 0)         as legacy_discharges,
    d.legacy_alos_non_ltc                  as legacy_alos_non_ltc,
    ifNull(e.legacy_wait_minutes_sum, 0)   as legacy_wait_minutes_sum
from spine as s
left join encounters as e on e.branch_key = s.branch_key and e.month_start = s.month_start
left join admissions as a on a.branch_key = s.branch_key and a.month_start = s.month_start
left join discharges as d on d.branch_key = s.branch_key and d.month_start = s.month_start
left join beds as b on b.branch_key = s.branch_key and b.month_start = s.month_start
left join branches as br on br.branch_key = s.branch_key
{{ hnh_settings() }}
