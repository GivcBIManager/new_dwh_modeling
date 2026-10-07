-- Role of a Press Ganey question per service: 'Hospital NPS', 'Physician NPS' or a background attribute (spec 4.1).
select
    upper(trimBoth(SERVICE))                            as service_code,
    trimBoth(QUESTION_CODE)                             as question_code,
    trimBoth(ROLE)                                      as role
from {{ source('reference', 'map_pg_question_role') }}
