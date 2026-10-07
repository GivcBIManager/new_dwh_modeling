{{ config(order_by='question_key') }}

-- One row per Press Ganey service and question (spec 5.2), plus the unknown member '-1'. question_class: Scored when
-- the master scores it, Routing for routing items, else Background. nps_role and attribute_role come from
-- map_pg_question_role ('' when the question has none).
with questions as (
    select
        concat(q.service_code, '|', q.question_code)        as question_key,
        q.service_code                                      as service_code,
        q.question_code                                     as question_code,
        q.pg_var                                            as pg_var,
        q.survey_name_en                                    as survey_name_en,
        q.survey_name_ar                                    as survey_name_ar,
        q.item_no                                           as item_no,
        q.domain_en                                         as domain_en,
        q.domain_ar                                         as domain_ar,
        q.question_en                                       as question_en,
        q.question_ar                                       as question_ar,
        q.scale_type                                        as scale_type,
        q.scale_en                                          as scale_en,
        q.item_type                                         as item_type,
        q.is_scored                                         as is_scored,
        multiIf(q.is_scored = 1, 'Scored', q.item_type = 'Routing', 'Routing', 'Background') as question_class,
        if(ifNull(r.role, '') in ('Hospital NPS', 'Physician NPS'), assumeNotNull(r.role), '') as nps_role,
        if(ifNull(r.role, '') in ('Hospital NPS', 'Physician NPS'), '', ifNull(r.role, ''))  as attribute_role
    from {{ ref('stg_pg__survey_question') }} as q
    left join {{ ref('stg_ref__pg_question_role') }} as r
        on r.service_code = q.service_code and r.question_code = q.question_code
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
)

select * from questions
union all
select '-1', '-1', '-1', '', 'Unknown', '', toUInt16(0), 'Unknown', '', 'Unknown', '', '', '', '', toUInt8(0),
       'Background', '', ''
