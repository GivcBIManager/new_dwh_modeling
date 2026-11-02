{{ config(severity='warn') }}
-- Current annual-leave balances with no monthly salary, so no liability (spec 6.6).
-- Rule and records: fact_hr_dq_record, issue DQ_LEAVE_NO_SALARY (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_LEAVE_NO_SALARY'
