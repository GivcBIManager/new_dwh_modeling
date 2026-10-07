{{ config(order_by='survey_service_key') }}

-- One row per Press Ganey service (spec 5.1), plus the unknown member '-1'.
with services as (
    select
        s.service_code                                      as survey_service_key,
        s.service_desc                                      as service_name,
        s.care_setting                                      as care_setting,
        s.is_enabled                                        as is_enabled,
        ifNull(q.survey_name_en, '')                        as survey_name_en,
        ifNull(q.survey_name_ar, '')                        as survey_name_ar
    from {{ ref('stg_pg__service') }} as s
    left join (select service_code, any(survey_name_en) as survey_name_en, any(survey_name_ar) as survey_name_ar
               from {{ ref('stg_pg__survey_question') }} group by service_code) as q
        on q.service_code = s.service_code
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
)

select * from services
union all
select '-1', 'Unknown', 'Unknown', toUInt8(0), '', ''
