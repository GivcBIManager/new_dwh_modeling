{{ config(severity='warn') }}
-- Payroll rows whose pay code has no pay category (not counted in cost).
-- Rule and records: fact_hr_dq_record, issue DQ_PAY_CODE_UNMAPPED (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_PAY_CODE_UNMAPPED'
