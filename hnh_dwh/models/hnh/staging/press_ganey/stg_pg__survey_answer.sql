-- One row per survey and answered question: the responses JSON expanded (spec 3, P2). Null answers are dropped; the
-- always-empty comments key and the stray initial_response array are skipped. An array value takes its first element.
select surveycode, service_code, question_code, answer_code
from (
    select
        surveycode                                      as surveycode,
        upper(trimBoth(service))                        as service_code,
        kv.1                                            as question_code,
        trimBoth(if(startsWith(kv.2, '['), ifNull(JSONExtract(kv.2, 1, 'Nullable(String)'), ''), kv.2)) as answer_code
    from {{ source('press_ganey', 'pg_survey_responses') }} final
    array join JSONExtractKeysAndValues(responses, 'Nullable(String)') as kv
    where kv.2 is not null and kv.1 not in ('comments', 'initial_response')
)
where answer_code != ''
