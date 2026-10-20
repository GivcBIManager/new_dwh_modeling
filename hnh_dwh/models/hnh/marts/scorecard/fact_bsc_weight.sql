{{ config(order_by='(bsc_kpi_key, branch_key)') }}

-- Weight of each active KPI inside its pillar, per hospital (bsc ssas spec 6.2). A hospital with a 'branch:<id>'
-- profile uses only that profile: a KPI the profile leaves out weighs 0 (the handover profiles omit KPIs on purpose
-- and sum to 1). A hospital without any profile uses the 'corporate' profile. Branches 1-8.
with weights as (
    select profile, kpi_code, weight from {{ ref('stg_ref__bsc_weight') }}
),

branches as (
    select toUInt8(number + 1) as branch_key, concat('branch:', toString(number + 1)) as profile
    from numbers(8)
),

profiled as (
    select distinct profile from weights where startsWith(profile, 'branch:')
)

select
    toInt64(bitShiftRight(cityHash64(concat(k.kpi_code, '|')), 1))  as bsc_kpi_key,
    b.branch_key                                                    as branch_key,
    toFloat64(if(p.profile is not null, ifNull(bw.weight, 0), ifNull(cw.weight, 0))) as weight
from {{ ref('stg_ref__bsc_kpi') }} as k
cross join branches as b
left join profiled as p on p.profile = b.profile
left join weights as bw on bw.profile = b.profile and bw.kpi_code = k.kpi_code
left join (select kpi_code, weight from weights where profile = 'corporate') as cw on cw.kpi_code = k.kpi_code
where k.status = 'active'
{{ hnh_settings() }}
