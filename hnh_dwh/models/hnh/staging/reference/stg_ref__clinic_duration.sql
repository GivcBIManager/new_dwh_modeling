select
    upper(trimBoth(SPECIALTY))   as specialty,
    max(CLINIC_DURATION)         as clinic_duration_hours,
    max(SLOTS_PER_HOUR)          as slots_per_hour
from {{ source('reference', 'map_clinic_duration') }}
group by specialty
