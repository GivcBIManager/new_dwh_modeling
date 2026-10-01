{{ config(severity='warn') }}
-- Raw timestamps outside the DateTime range (before 1970-01-01 03:00 or from 2106) that
-- hnh_ksa_wall_clock turns into NULL. Review when a count grows. appointments is filtered
-- to real patients to keep the scan cheap.
select * from (
select 'staff_posts.date_started' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('staff_posts') }} final
where isNotNull(date_started) and isNull({{ hnh_ksa_wall_clock('date_started') }})

union all

select 'staff_posts.date_ended' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('staff_posts') }} final
where isNotNull(date_ended) and isNull({{ hnh_ksa_wall_clock('date_ended') }})

union all

select 'bed_details.start_date' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('bed_details') }} final
where isNotNull(start_date) and isNull({{ hnh_ksa_wall_clock('start_date') }})

union all

select 'bed_details.end_date' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('bed_details') }} final
where isNotNull(end_date) and isNull({{ hnh_ksa_wall_clock('end_date') }})

union all

select 'patient_ad.admit_date' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('patient_ad') }} final
where isNotNull(admit_date) and isNull({{ hnh_ksa_wall_clock('admit_date') }})

union all

select 'patient_ad.physical_discharge_date' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('patient_ad') }} final
where isNotNull(physical_discharge_date) and isNull({{ hnh_ksa_wall_clock('physical_discharge_date') }})

union all

select 'patient_ad.financial_discharge_date' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('patient_ad') }} final
where isNotNull(financial_discharge_date) and isNull({{ hnh_ksa_wall_clock('financial_discharge_date') }})

union all

select 'appointments.time_complete' as source_column, count() as out_of_range_rows
from {{ hnh_oasis_source('appointments') }} final
where isNotNull(time_complete) and isNull({{ hnh_ksa_wall_clock('time_complete') }}) and patient_id > 0
)
where out_of_range_rows > 0
