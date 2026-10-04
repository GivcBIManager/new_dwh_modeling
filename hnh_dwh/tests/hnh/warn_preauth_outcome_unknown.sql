{{ config(severity='warn') }}
select branch_key, nphies_final_status, authorised_flag, count() as lines
from {{ ref('fact_preauth_line') }}
where preauth_outcome = 'Unknown'
group by branch_key, nphies_final_status, authorised_flag
