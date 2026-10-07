{{ config(severity='warn') }}
-- Payer advance authorisations (spec Phase 2B section 12) that report poorly: no patient (identity value held by
-- no patient or by several patients of the branch) or an unknown outcome; episode links shown for context.
select
    branch_id,
    toStartOfMonth(toDate(created_at))      as month_start,
    count()                                 as authorisations,
    countIf(patient_id is null)             as no_patient,
    countIf(outcome = 'Unknown')            as unknown_outcome,
    countIf(episode_no is null)             as no_episode,
    countIf(episode_match_count > 1)        as ambiguous_episode
from {{ ref('int_nphies_advance_authorisation') }}
group by branch_id, month_start
having no_patient > 0 or unknown_outcome > 0
