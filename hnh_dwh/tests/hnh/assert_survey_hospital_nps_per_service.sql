-- Every service with survey invitations has exactly one Hospital NPS question in map_pg_question_role (spec 8).
select r.service_code as service_code, countIf(q.role = 'Hospital NPS') as hospital_nps_questions
from (select distinct service_code from {{ ref('stg_pg__survey_response') }}) as r
left join {{ ref('stg_ref__pg_question_role') }} as q on q.service_code = r.service_code
group by r.service_code
having hospital_nps_questions != 1
