select
    per_absence_entry_id                        as absence_entry_id,
    person_id,
    absence_type_id,
    legal_employer_id,
    {{ hnh_code('absence_status_code') }}       as absence_status_code,
    {{ hnh_code('approval_status_code') }}      as approval_status_code,
    toDate32(absence_start_date)                as start_date,
    toDate32(absence_end_date)                  as end_date,
    toFloat64OrNull(trimBoth(ifNull(duration, ''))) as duration,
    {{ hnh_code('duration_uom') }}              as duration_uom
from {{ hnh_fusion_source('fact_absence_entry') }} final
