{{ config(severity='warn') }}
select branch_key, primary_reason_code, count() as lines
from {{ ref('fact_claim_line') }}
where nphies_reason_key = -1
group by branch_key, primary_reason_code
