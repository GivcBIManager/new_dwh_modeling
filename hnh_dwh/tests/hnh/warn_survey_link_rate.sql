{{ config(severity='warn') }}
-- Branch-service-months (100+ invitations) where under 80% of surveys link to an encounter (spec 8). Khamis (2) from
-- December 2025 to July 2026 is the known outpatient appointment gap (O-P6-1) and is left out.
select branch_key, survey_service_key, month_start, source_invitations, link_rate
from {{ ref('rec_survey_monthly') }}
where source_invitations >= 100 and link_rate < 0.8
  and not (branch_key = 2 and month_start between toDate('2025-12-01') and toDate('2026-07-01'))
