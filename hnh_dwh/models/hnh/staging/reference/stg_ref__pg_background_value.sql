-- Conformed value of each background or routing answer code per service (spec 4.2).
select
    upper(trimBoth(SERVICE))                            as service_code,
    trimBoth(QUESTION_CODE)                             as question_code,
    trimBoth(ANSWER_CODE)                               as answer_code,
    trimBoth(CONFORMED_VALUE)                           as conformed_value
from {{ source('reference', 'map_pg_background_value') }}
