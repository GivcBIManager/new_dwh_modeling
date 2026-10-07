-- Press Ganey question master: one row per service and question code (spec 5.2).
select
    upper(trimBoth(service))                            as service_code,
    trimBoth(question_code)                             as question_code,
    pg_var                                              as pg_var,
    toString(survey_sheet)                              as survey_sheet,
    survey_name_en                                      as survey_name_en,
    survey_name_ar                                      as survey_name_ar,
    toUInt16(item_no)                                   as item_no,
    toUInt8(included)                                   as is_included,
    domain_en                                           as domain_en,
    domain_ar                                           as domain_ar,
    question_en                                         as question_en,
    question_ar                                         as question_ar,
    scale_en                                            as scale_en,
    toString(scale_type)                                as scale_type,
    toString(item_type)                                 as item_type,
    toUInt8(is_scored)                                  as is_scored
from {{ source('press_ganey', 'pg_survey_questions') }}
