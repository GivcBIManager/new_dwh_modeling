-- Press Ganey answer options: label and score per service, question and answer code (spec P3). Workbook options
-- (background and routing questions) have no score.
select
    upper(trimBoth(service))                            as service_code,
    trimBoth(question_code)                             as question_code,
    trimBoth(answer_code)                               as answer_code,
    toUInt8(sort_order)                                 as sort_order,
    label_en                                            as label_en,
    label_ar                                            as label_ar,
    if(score is null, cast(null as Nullable(Float64)), toFloat64(score)) as score,
    toString(label_source)                              as label_source
from {{ source('press_ganey', 'pg_survey_answer_options') }}
