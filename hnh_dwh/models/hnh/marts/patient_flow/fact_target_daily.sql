{{ config(order_by='(branch_key, date_key, scenario)') }}

select
    branch_id                                            as branch_key,
    toInt32(toYYYYMMDD(target_date))                     as date_key,
    {{ hnh_care_type_key('care_type') }}                 as care_type_key,
    scenario                                             as scenario,
    stay_type                                            as stay_type,
    ifNull(creditor, 'Not Mapped')                       as creditor,
    ifNull(specialty, 'Not Mapped')                      as specialty,
    sum(census)                                          as target_census,
    sum(episodes)                                        as target_episodes,
    sum(revenue)                                         as target_revenue,
    sum(cost_per_episode * episodes)                     as target_cost_total,
    sum(alos * episodes)                                 as target_patient_days,
    -- Non-additive helpers (episode-weighted averages); sum the two additive columns above and divide in the model.
    if(sum(episodes) = 0, 0, sum(cost_per_episode * episodes) / sum(episodes)) as target_cost_per_episode,
    if(sum(episodes) = 0, 0, sum(alos * episodes) / sum(episodes))             as target_alos,
    now()                                                as _loaded_at
from {{ ref('stg_ref__budget') }}
where is_latest = 1
group by branch_key, date_key, care_type_key, scenario, stay_type, creditor, specialty
