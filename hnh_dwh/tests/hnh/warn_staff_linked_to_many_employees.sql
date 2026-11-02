{{ config(severity='warn') }}
-- Oasis staff records linked to more than one Fusion employee (rehires or reused worker numbers); one row per linked employee.
-- Rule and records: fact_hr_dq_record, issue DQ_STAFF_MANY_EMP (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_STAFF_MANY_EMP'
