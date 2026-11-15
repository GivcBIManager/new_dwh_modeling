{{ config(order_by='(bsc_kpi_key, branch_key)') }}

-- Weight of each active KPI as a share of the hospital's whole scorecard (a pillar's weights add up to the pillar's
-- share), per hospital (bsc ssas spec 6.2). Each hospital uses one whole profile: its own 'branch:<id>' profile if
-- there is one, else its scorecard category's 'category:<category>' profile (map_bsc_hospital_category), else the
-- 'corporate' profile. A KPI the chosen profile leaves out weighs 0. Branches 1-8.
with weights as (
    select profile, kpi_code, weight from {{ ref('stg_ref__bsc_weight') }}
),

profiles as (
    select distinct profile from weights
),

branches as (
    select toUInt8(number + 1) as branch_key from numbers(8)
),

chosen as (
    select
        b.branch_key as branch_key,
        multiIf(bp.profile is not null, bp.profile, cp.profile is not null, cp.profile, 'corporate') as profile
    from branches as b
    left join {{ ref('stg_ref__bsc_hospital_category') }} as c on c.branch_id = b.branch_key
    left join profiles as bp on bp.profile = concat('branch:', toString(b.branch_key))
    left join profiles as cp on cp.profile = concat('category:', c.category)
)

select
    toInt64(bitShiftRight(cityHash64(concat(k.kpi_code, '|')), 1))  as bsc_kpi_key,
    ch.branch_key                                                   as branch_key,
    toFloat64(ifNull(w.weight, 0))                                  as weight
from {{ ref('stg_ref__bsc_kpi') }} as k
cross join chosen as ch
left join weights as w on w.profile = ch.profile and w.kpi_code = k.kpi_code
where k.status = 'active'
{{ hnh_settings() }}
