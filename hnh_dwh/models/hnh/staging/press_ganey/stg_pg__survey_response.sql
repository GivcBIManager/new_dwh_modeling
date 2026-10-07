-- One row per Press Ganey survey invitation (surveycode), latest version by _fetched_at (spec 3). The survey link URL
-- is not carried. sms_send_date is a timestamp at midnight in the source; only its date is used.
select
    surveycode                                          as surveycode,
    lower(trimBoth(hosp))                               as pg_branch_code,
    upper(trimBoth(service))                            as service_code,
    trimBoth(encounter_id)                              as encounter_id,
    visit_date                                          as visit_date,
    receive_date                                        as receive_date,
    if(sms_send_date is null, cast(null as Nullable(Date)), toDate(sms_send_date)) as sms_send_date,
    survey_date                                         as survey_date,
    toString(status)                                    as source_status,
    responses                                           as responses_json,
    _fetched_at                                         as fetched_at
from {{ source('press_ganey', 'pg_survey_responses') }} final
