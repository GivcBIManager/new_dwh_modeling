{% set null_s = "cast(null as Nullable(String))" %}
{% set null_d = "cast(null as Nullable(Date32))" %}

select 'movement group wrong' as failure
where not ({{ hnh_movement_group("'HIRE'") }} = 'Hire' and {{ hnh_movement_group("'ADD_CWK'") }} = 'Hire'
       and {{ hnh_movement_group("'REHIRE'") }} = 'Rehire' and {{ hnh_movement_group("'GLB_TRANSFER'") }} = 'Transfer'
       and {{ hnh_movement_group("'ASG_CHANGE'") }} = 'Position change' and {{ hnh_movement_group("'POSITION_CHANGE'") }} = 'Position change'
       and {{ hnh_movement_group("'RESIGNATION'") }} = 'Voluntary leaver'
       and {{ hnh_movement_group("'TERMINATION_ARTICLE_80'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'TERMINATION_ARTICLE_74'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'END_OF_CONTRACT'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'END_CONTRACT_IN_PROB_PERIOD'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'TERMINATION_OTHER'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'CONTRACT_EXTENSION'") }} = 'Contract extension'
       and {{ hnh_movement_group("'MANAGER_CHANGE'") }} = 'Other' and {{ hnh_movement_group(null_s) }} = 'Other')

union all
select 'absence status wrong'
where not ({{ hnh_absence_status("'SUBMITTED'", "'APPROVED'") }} = 'Approved'
       and {{ hnh_absence_status("'SUBMITTED'", "'AWAITING'") }} = 'Awaiting'
       and {{ hnh_absence_status("'SUBMITTED'", "'DENIED'") }} = 'Denied'
       and {{ hnh_absence_status("'ORA_WITHDRAWN'", "'APPROVED'") }} = 'Withdrawn'
       and {{ hnh_absence_status("'SAVED'", null_s) }} = 'Saved'
       and {{ hnh_absence_status(null_s, null_s) }} = 'Other')

union all
select 'counted absence wrong'
where not ({{ hnh_is_counted_absence("'SUBMITTED'", "'APPROVED'") }} = 1
       and {{ hnh_is_counted_absence("'ORA_WITHDRAWN'", "'APPROVED'") }} = 0
       and {{ hnh_is_counted_absence("'SUBMITTED'", "'AWAITING'") }} = 0
       and {{ hnh_is_counted_absence(null_s, null_s) }} = 0)

union all
select 'absence category wrong'
where not ({{ hnh_absence_category("'Sick Leave'") }} = 'Sick' and {{ hnh_absence_category("'HQ Annual Leave - NS'") }} = 'Annual'
       and {{ hnh_absence_category("'Unpaid Leave'") }} = 'Unpaid' and {{ hnh_absence_category("'Permission Leave'") }} = 'Permission'
       and {{ hnh_absence_category("'Time Back'") }} = 'Time back' and {{ hnh_absence_category("'Maternity'") }} = 'Other'
       and {{ hnh_absence_category(null_s) }} = 'Other')

union all
select 'age band wrong'
where not ({{ hnh_age_band("toDate32('2002-06-01')", "toDate32('2026-05-31')") }} = '<25'
       and {{ hnh_age_band("toDate32('2001-01-01')", "toDate32('2026-06-01')") }} = '25-34'
       and {{ hnh_age_band("toDate32('1990-01-01')", "toDate32('2026-06-01')") }} = '35-44'
       and {{ hnh_age_band("toDate32('1980-01-01')", "toDate32('2026-06-01')") }} = '45-54'
       and {{ hnh_age_band("toDate32('1960-01-01')", "toDate32('2026-06-01')") }} = '55+'
       and {{ hnh_age_band(null_d, "toDate32('2026-06-01')") }} = 'Unknown')

union all
select 'tenure band wrong'
where not ({{ hnh_tenure_band("toDate32('2026-01-01')", "toDate32('2026-06-01')") }} = '<1'
       and {{ hnh_tenure_band("toDate32('2024-01-01')", "toDate32('2026-06-01')") }} = '1-3'
       and {{ hnh_tenure_band("toDate32('2022-01-01')", "toDate32('2026-06-01')") }} = '3-5'
       and {{ hnh_tenure_band("toDate32('2018-01-01')", "toDate32('2026-06-01')") }} = '5-10'
       and {{ hnh_tenure_band("toDate32('2000-01-01')", "toDate32('2026-06-01')") }} = '10+'
       and {{ hnh_tenure_band(null_d, "toDate32('2026-06-01')") }} = 'Unknown')

union all
select 'fte wrong'
where not ({{ hnh_fte('toFloat64(0.5)') }} = 0.5 and {{ hnh_fte('toFloat64(1.5)') }} = 1.5 and {{ hnh_fte('toFloat64(0)') }} = 1
       and {{ hnh_fte('toFloat64(2)') }} = 1 and {{ hnh_fte('cast(null as Nullable(Float64))') }} = 1)

union all
select 'dept prefix branch wrong'
where not ({{ hnh_hr_dept_prefix_branch("'RBW'") }} = 1 and {{ hnh_hr_dept_prefix_branch("'KHM'") }} = 2
       and {{ hnh_hr_dept_prefix_branch("'JAZ'") }} = 3 and {{ hnh_hr_dept_prefix_branch("'UNI'") }} = 4
       and {{ hnh_hr_dept_prefix_branch("'MAD'") }} = 5 and {{ hnh_hr_dept_prefix_branch("'ABH'") }} = 6
       and {{ hnh_hr_dept_prefix_branch("'GHI'") }} = 7 and {{ hnh_hr_dept_prefix_branch("'MHL'") }} = 8
       and {{ hnh_hr_dept_prefix_branch("'HQ'") }} = 100 and {{ hnh_hr_dept_prefix_branch("'XXX'") }} = 0)

union all
select 'worker type wrong'
where not ({{ hnh_worker_type_label("'EMP'") }} = 'Employee' and {{ hnh_worker_type_label("'EX_EMP'") }} = 'Ex-employee'
       and {{ hnh_worker_type_label("'CWK'") }} = 'Contingent worker' and {{ hnh_worker_type_label("'CON'") }} = 'Contractor'
       and {{ hnh_worker_type_label("'CANCELED_HIRE'") }} = 'Cancelled hire' and {{ hnh_worker_type_label(null_s) }} = 'Unknown')

union all
select 'age band anniversary wrong'
where not ({{ hnh_age_band("toDate32('2001-06-01')", "toDate32('2026-06-01')") }} = '25-34'
       and {{ hnh_age_band("toDate32('2001-06-01')", "toDate32('2026-05-31')") }} = '<25')

union all
select 'tenure anniversary wrong'
where not ({{ hnh_tenure_band("toDate32('2025-06-01')", "toDate32('2026-06-01')") }} = '1-3'
       and {{ hnh_tenure_band("toDate32('2025-06-01')", "toDate32('2026-05-31')") }} = '<1')

union all
select 'month ends wrong'
where (select min(month_end) from ({{ hnh_hr_month_ends() }})) != toDate('2026-01-31')
   or (select count() from ({{ hnh_hr_month_ends() }})) != dateDiff('month', toDate('2026-01-01'), today()) + 1
