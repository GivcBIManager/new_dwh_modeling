{{ config(severity='warn') }}
-- Months where branch 8's Oasis payroll equals branch 7's in paid staff and amount (source duplication, spec H11).
-- Rule and records: fact_hr_dq_record, issue DQ_B8_PAYROLL_COPY (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_B8_PAYROLL_COPY'
