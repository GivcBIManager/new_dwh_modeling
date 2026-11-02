{{ config(severity='warn') }}
-- Counted day-unit absences with zero or missing days.
-- Rule and records: fact_hr_dq_record, issue DQ_ABSENCE_ZERO_DAYS (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_ABSENCE_ZERO_DAYS'
