{{ config(alias='vw_customer') }}

-- Old bsc.vw_customer on gold (bsc spec 7.2): revenue, visits, admissions, capacity and targets per branch and
-- month, from January of last year to yesterday, with the SSAS measure definitions. Revenue splits by payer use the
-- episode payer (co-pay stays with the insurer, as before); high-value volume uses the booked doctor; capacity is
-- the old clinic-hours rule (legacy_capacity_slots, O-B3). Targets: most-likely scenario.
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_,
    today_ - 1 as yesterday_,
    toInt32(toYYYYMMDD(subtractYears(toStartOfYear(yesterday_), 1))) as from_key_,
    toInt32(toYYYYMMDD(yesterday_)) as to_key_,
months as (
    select date_key, toDate32(start_of_month) as period
    from {{ ref('dim_date') }}
    where date_key between from_key_ and to_key_
),
referral as (
    select episode_key, is_referral_policy
    from {{ ref('fact_episode') }}
),
rev as (
    select
        c.branch_key                                                                  as branch_key,
        m.period                                                                      as period,
        sum(c.revenue_amount)                                                         as revenue,
        sumIf(c.revenue_amount, c.care_type_key = 1)                                  as op_revenue,
        sumIf(c.revenue_amount, c.care_type_key = 3 and c.is_ltc = 0)                 as non_ltc_ip_revenue,
        sumIf(c.revenue_amount, c.care_type_key = 1
              and pc.category_code in ('MD', 'MED', 'CSM', 'RTL', 'MLK', 'PH', 'LAB', 'RAD')) as ancillary_services_revenue,
        sumIf(c.revenue_amount, p.is_moh = 0)                                         as non_moh_revenue,
        sumIf(c.revenue_amount, p.category = 'Insurance')                             as insurance_revenue,
        sumIf(c.revenue_amount, ep.is_referral_policy = 1)                            as referrals_revenue,
        sumIf(c.revenue_amount, p.billing_type = 'Credit')                            as credit_revenue,
        sumIf(c.revenue_amount, s.is_high_value_specialty = 1)                        as high_value_service_revenue
    from {{ ref('fact_charge_line') }} as c
    inner join months as m on m.date_key = c.delivery_date_key
    left join {{ ref('dim_payer') }} as p on p.payer_key = c.episode_payer_key
    left join {{ ref('dim_staff') }} as s on s.staff_key = c.staff_key
    left join {{ ref('dim_product_category') }} as pc on pc.product_category_key = c.product_category_key
    left join referral as ep on ep.episode_key = c.episode_key
    where c.delivery_date_key between from_key_ and to_key_ and c.branch_key between 1 and 8
    group by branch_key, period
),
cen as (
    select
        e.branch_key                                                                  as branch_key,
        m.period                                                                      as period,
        countIf(e.encounter_type = 'OP' and e.is_arrived = 1 and e.is_cancelled = 0)
          + countIf(e.encounter_type = 'ER' and e.is_cancelled = 0)                   as census,
        countIf(((e.encounter_type = 'OP' and e.is_arrived = 1) or e.encounter_type = 'ER')
                and e.is_cancelled = 0 and p.category = 'Insurance')                  as insurance_census,
        countIf(e.encounter_type = 'OP' and e.is_arrived = 1 and e.is_cancelled = 0)  as op_census,
        uniqExactIf(e.patient_key, e.is_arrived = 1 and e.is_cancelled = 0)           as distinct_patients,
        uniqExactIf(e.patient_key, e.is_arrived = 1 and e.is_cancelled = 0 and e.is_returning = 1) as returning_patients,
        countIf(e.encounter_type = 'OP' and e.is_arrived = 1 and e.visit_type = 'New patient') as new_op_census,
        countIf(e.encounter_type = 'ER' and e.is_cancelled = 0)                       as er_census,
        countIf(((e.encounter_type = 'OP' and e.is_arrived = 1) or e.encounter_type = 'ER')
                and e.is_cancelled = 0 and ep.is_referral_policy = 1)                 as referrals_census,
        countIf(((e.encounter_type = 'OP' and e.is_arrived = 1) or e.encounter_type = 'ER')
                and e.is_cancelled = 0 and s.is_high_value_specialty = 1)             as high_value_service_census,
        sumIf(e.wait_minutes, e.encounter_type = 'OP' and e.is_arrived = 1 and e.is_cancelled = 0) as op_wait
    from {{ ref('fact_encounter') }} as e
    inner join months as m on m.date_key = e.encounter_date_key
    left join {{ ref('dim_payer') }} as p on p.payer_key = e.payer_key
    left join {{ ref('dim_staff') }} as s on s.staff_key = e.booked_staff_key
    left join referral as ep on ep.episode_key = e.episode_key
    where e.encounter_date_key between from_key_ and to_key_ and e.encounter_type in ('OP', 'ER')
      and e.branch_key between 1 and 8
    group by branch_key, period
),
epi as (
    select f.branch_key as branch_key, m.period as period,
           countIf(f.care_type_key = 1 and f.has_arrived_non_follow_up_encounter = 1) as op_episodes
    from {{ ref('fact_episode') }} as f
    inner join months as m on m.date_key = f.start_date_key
    where f.start_date_key between from_key_ and to_key_ and f.branch_key between 1 and 8
    group by branch_key, period
),
adm as (
    select
        a.branch_key                                        as branch_key,
        m.period                                            as period,
        count()                                             as admissions,
        countIf(a.is_readmission_30d = 1)                   as readmission_within_30days,
        countIf(a.is_icu_readmission_48h = 1)               as readmitted_to_icu_48h,
        countIf(p.category = 'Insurance')                   as insurance_admissions,
        countIf(ep.is_referral_policy = 1)                  as referrals_admissions,
        countIf(s.is_high_value_specialty = 1)              as high_value_service_admissions
    from {{ ref('fact_admission') }} as a
    inner join months as m on m.date_key = a.admit_date_key
    left join {{ ref('dim_payer') }} as p on p.payer_key = a.payer_key
    left join {{ ref('dim_staff') }} as s on s.staff_key = a.consultant_staff_key
    left join referral as ep on ep.episode_key = a.episode_key
    where a.admit_date_key between from_key_ and to_key_ and a.is_countable = 1 and a.branch_key between 1 and 8
    group by branch_key, period
),
disc as (
    select
        a.branch_key                                        as branch_key,
        m.period                                            as period,
        count()                                             as discharges,
        countIf(b.is_critical = 1)                          as icu_discharges,
        avgIf(a.los_days, a.is_ltc = 0)                     as alos_non_ltc_days
    from {{ ref('fact_admission') }} as a
    inner join months as m on m.date_key = a.physical_discharge_date_key
    left join {{ ref('dim_bed') }} as b on b.bed_key = a.last_bed_key
    where a.physical_discharge_date_key between from_key_ and to_key_ and a.is_countable = 1 and a.branch_key between 1 and 8
    group by branch_key, period
),
cap as (
    select k.branch_key as branch_key, m.period as period, sum(k.legacy_capacity_slots) as slots
    from {{ ref('agg_clinic_capacity_daily') }} as k
    inner join months as m on m.date_key = k.date_key
    where k.date_key between from_key_ and to_key_ and k.branch_key between 1 and 8
    group by branch_key, period
),
bud as (
    select
        t.branch_key                                                                        as branch_key,
        m.period                                                                            as period,
        sum(t.target_revenue)                                                               as revenue_target,
        round(sum(t.target_census), 0)                                                      as volume_target,
        round(sumIf(t.target_revenue, t.creditor != 'Government'), 0)                       as non_moh_revenue_target,
        round(sumIf(t.target_revenue, t.creditor = 'Insurance'), 0)                         as insurance_revenue_target,
        round(sumIf(t.target_census, t.creditor = 'Insurance'), 0)                          as insurance_census_target,
        round(sumIf(t.target_revenue, t.care_type_key = 1), 0)                              as op_revenue_target,
        round(sumIf(t.target_revenue, t.care_type_key = 3 and t.stay_type != 'LTC'), 0)     as non_ltc_ip_revenue_target,
        round(sumIf(t.target_revenue, t.care_type_key = 1), 0) * 0.6                        as ancillary_revenue_target,
        round(sumIf(t.target_census, t.care_type_key = 1), 0)                               as op_volume_target,
        round(sumIf(t.target_episodes, t.care_type_key = 1), 0)                             as op_episodes_target,
        round(sumIf(t.target_census, t.care_type_key = 2), 0)                               as er_volume_target,
        round(sumIf(t.target_census, t.care_type_key = 3), 0)                               as admissions_volume_target
    from {{ ref('fact_target_daily') }} as t
    inner join months as m on m.date_key = t.date_key
    where t.date_key between from_key_ and to_key_ and t.scenario = 'most_likely' and t.branch_key between 1 and 8
    group by branch_key, period
),
keys as (
    select b.branch_key as branch_key, m.period as period
    from {{ ref('hnh_dim_branch') }} as b
    cross join (select distinct period from months) as m
    where b.branch_key between 1 and 8
)
select
    toUInt64(k.branch_key)                                                    as branch_id,
    k.period                                                                  as period,
    CAST(round(r.revenue, 2) AS Decimal(38, 10))                              as revenue,
    CAST(round(r.op_revenue, 2) AS Decimal(38, 10))                           as op_revenue,
    CAST(round(r.non_ltc_ip_revenue, 2) AS Decimal(38, 10))                   as non_ltc_ip_revenue,
    CAST(round(r.ancillary_services_revenue, 2) AS Decimal(38, 10))           as ancillary_services_revenue,
    CAST(round(r.non_moh_revenue, 2) AS Decimal(38, 10))                      as non_moh_revenue,
    CAST(round(r.insurance_revenue, 2) AS Decimal(38, 10))                    as insurance_revenue,
    CAST(round(r.referrals_revenue, 2) AS Decimal(38, 10))                    as referrals_revenue,
    CAST(round(r.credit_revenue, 2) AS Decimal(38, 10))                       as credit_revenue,
    CAST(round(r.high_value_service_revenue, 2) AS Decimal(38, 10))           as high_value_service_revenue,
    toUInt64(a.high_value_service_admissions + c.high_value_service_census)   as high_value_service_volume,
    toUInt64(c.census)                                                        as census,
    toUInt64(c.insurance_census)                                              as insurance_census,
    toUInt64(c.op_census)                                                     as op_census,
    toUInt64(c.distinct_patients)                                             as distinct_patients,
    toUInt64(c.returning_patients)                                            as returning_patients,
    toUInt64(c.new_op_census)                                                 as new_op_census,
    toUInt64(ep.op_episodes)                                                  as op_episodes,
    toUInt64(c.er_census)                                                     as er_census,
    toUInt64(c.referrals_census + a.referrals_admissions)                     as referrals_volume,
    CAST(round(o.slots, 4) AS Decimal(38, 20))                                as available_slots,
    CAST(c.op_wait AS Nullable(Int64))                                        as op_waiting_time_in_minutes,
    toUInt64(a.admissions)                                                    as admissions,
    toUInt64(a.readmission_within_30days)                                     as readmission_within_30days,
    toUInt64(a.readmitted_to_icu_48h)                                         as readmitted_to_ICU_with_48hrs,
    toUInt64(a.insurance_admissions)                                          as insurance_admissions,
    toUInt64(d.discharges)                                                    as discharges,
    toUInt64(d.icu_discharges)                                                as icu_discharge,
    toFloat64(ifNull(d.alos_non_ltc_days, 0))                                 as alos_non_ltc,
    toFloat64(b.revenue_target)                                               as revenue_target,
    toFloat64(b.non_moh_revenue_target)                                       as non_moh_revenue_target,
    toFloat64(b.insurance_revenue_target)                                     as insurance_revenue_target,
    toFloat64(b.insurance_census_target)                                      as insurance_census_target,
    toFloat64(b.op_revenue_target)                                            as op_revenue_target,
    toFloat64(b.non_ltc_ip_revenue_target)                                    as non_ltc_ip_revenue_target,
    toFloat64(b.ancillary_revenue_target)                                     as ancillary_revenue_target,
    toFloat64(b.volume_target)                                                as volume_target,
    toFloat64(b.op_volume_target)                                             as op_volume_target,
    toFloat64(b.op_episodes_target)                                           as op_episodes_target,
    toFloat64(b.er_volume_target)                                             as er_volume_target,
    toFloat64(b.admissions_volume_target)                                     as admissions_volume_target
from keys as k
left join rev as r on r.branch_key = k.branch_key and r.period = k.period
left join cen as c on c.branch_key = k.branch_key and c.period = k.period
left join epi as ep on ep.branch_key = k.branch_key and ep.period = k.period
left join adm as a on a.branch_key = k.branch_key and a.period = k.period
left join disc as d on d.branch_key = k.branch_key and d.period = k.period
left join cap as o on o.branch_key = k.branch_key and o.period = k.period
left join bud as b on b.branch_key = k.branch_key and b.period = k.period
settings join_use_nulls = 0
