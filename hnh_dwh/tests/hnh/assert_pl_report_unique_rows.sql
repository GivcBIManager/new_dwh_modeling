-- One P&L report row per branch, month, source, report line, account and Fusion slicer values.
select branch_key, month_start, source_system, pl_line_code, account_code, specialty_name, service_location_name,
       service_group_name, count() as row_count
from {{ ref('fact_pl_report_monthly') }}
group by branch_key, month_start, source_system, pl_line_code, account_code, specialty_name, service_location_name,
         service_group_name
having count() > 1
