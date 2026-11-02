{{ config(severity='warn') }}
-- Oasis staff IDs of a branch that differ only in format (case, spaces); one row per raw ID.
-- Rule and records: fact_hr_dq_record, issue DQ_STAFF_ID_FORMAT (shown on the HR dashboard's Data quality page).
select * from {{ ref('fact_hr_dq_record') }} where issue_code = 'DQ_STAFF_ID_FORMAT'
