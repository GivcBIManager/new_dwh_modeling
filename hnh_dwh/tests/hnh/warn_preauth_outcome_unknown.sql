{{ config(severity='warn') }}
select branch_key, nphies_final_status, authorised_flag, count() as lines
from {{ ref('fact_preauth_line') }}
-- payer advance authorisations are monitored by warn_advance_authorisations
where preauth_outcome = 'Unknown' and line_source != 'Payer advance'
group by branch_key, nphies_final_status, authorised_flag
