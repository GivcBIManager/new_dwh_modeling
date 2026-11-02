{{ config(severity='warn') }}
-- FTE work measures outside (0, 1.5] (replaced by 1 in the snapshot).
-- Rule and records: fact_hr_dq_record, issue DQ_FTE_ZERO (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_FTE_ZERO'
