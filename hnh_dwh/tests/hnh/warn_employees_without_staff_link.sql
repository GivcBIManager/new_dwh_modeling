{{ config(severity='warn') }}
-- Current hospital employees whose worker number matches no Oasis staff in their branch.
-- Rule and records: fact_hr_dq_record, issue DQ_EMP_NO_STAFF (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_EMP_NO_STAFF'
