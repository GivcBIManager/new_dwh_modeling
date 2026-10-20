{{ config(order_by='bsc_kpi_key') }}

-- Balanced-scorecard KPI catalogue for SSAS (bsc ssas spec 6.2): the latest config rows of map_bsc_kpi with the
-- objective and pillar, the Corporate owner (branch_id 0), the KPI's score thresholds (its own row, else '*') and
-- the corporate weight (used when several hospitals are selected). Without a '*' row the defaults are 85, 0.6, 85
-- and 70, so a deleted default never empties the list. The key equals hnh_surrogate_key(['kpi_code']).
with thresholds as (
    select kpi_code, score_base, score_slope, good_from, watch_from
    from {{ ref('stg_ref__bsc_threshold') }}
)

select
    toInt64(bitShiftRight(cityHash64(concat(k.kpi_code, '|')), 1))  as bsc_kpi_key,
    k.kpi_code                                                      as kpi_code,
    k.kpi_num                                                       as kpi_num,
    k.kpi_name                                                      as kpi_name,
    k.short_label                                                   as short_label,
    ifNull(o.pillar, '')                                            as pillar,
    ifNull(o.pillar_order, 0)                                       as pillar_order,
    ifNull(o.pillar_weight, 0)                                      as pillar_weight,
    ifNull(o.pillar_question, '')                                   as pillar_question,
    k.objective_code                                                as objective_code,
    ifNull(o.objective_title, '')                                   as objective_title,
    ifNull(o.objective_question, '')                                as objective_question,
    ifNull(o.objective_order, 0)                                    as objective_order,
    k.kpi_type                                                      as kpi_type,
    k.direction                                                     as direction,
    k.value_format                                                  as value_format,
    k.chart_hint                                                    as chart_hint,
    k.display_order                                                 as display_order,
    k.definition                                                    as definition,
    k.status                                                        as status,
    k.target_source                                                 as target_source,
    k.value_source                                                  as value_source,
    k.detail_page                                                   as detail_page,
    ifNull(ow.owner, '')                                            as owner,
    ifNull(ow.co_owners, '')                                        as co_owners,
    toFloat64(coalesce(t.score_base, (select anyOrNull(score_base) from thresholds where kpi_code = '*'), 85))   as score_base,
    toFloat64(coalesce(t.score_slope, (select anyOrNull(score_slope) from thresholds where kpi_code = '*'), 0.6)) as score_slope,
    toFloat64(coalesce(t.good_from, (select anyOrNull(good_from) from thresholds where kpi_code = '*'), 85))     as good_from,
    toFloat64(coalesce(t.watch_from, (select anyOrNull(watch_from) from thresholds where kpi_code = '*'), 70))   as watch_from,
    toFloat64(ifNull(w.weight, 0))                                  as corporate_weight,
    toUInt8(k.status = 'active')                                    as is_active
from {{ ref('stg_ref__bsc_kpi') }} as k
left join {{ ref('stg_ref__bsc_objective') }} as o on o.objective_code = k.objective_code
left join (
    select kpi_code, owner, co_owners from {{ ref('stg_ref__bsc_owner') }} where branch_id = 0
) as ow on ow.kpi_code = k.kpi_code
left join thresholds as t on t.kpi_code = k.kpi_code
left join (
    select kpi_code, weight from {{ ref('stg_ref__bsc_weight') }} where profile = 'corporate'
) as w on w.kpi_code = k.kpi_code
{{ hnh_settings() }}
