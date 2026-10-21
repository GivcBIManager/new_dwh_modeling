-- Staff columns for the role-playing copies Booked Doctor, Admission Treating Doctor and Anaesthetist (SSAS spec 5.2).
-- No row filter applies to the copies; their fact rows are already secured through branch and the primary staff role.
select
    toInt64(staff_key)  as staff_key,
    staff_name,
    staff_name_ar,
    staff_grade,
    category,
    specialty,
    unified_specialty,
    if(is_high_value_specialty = 1, 'Yes', 'No') as is_high_value_specialty   -- scorecard KPI 26 (booked doctor)
from {{ ref('dim_staff') }}
