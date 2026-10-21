{{ config(order_by='bsc_parameter_key') }}

-- Scorecard parameters as one row for SSAS (bsc ssas spec, further definitions of 2026-10-21). A missing parameter
-- takes its default (8 clinic hours per day, 4 patients per hour, ancillary target share 0.6).
with p as (
    select name, value from {{ ref('stg_ref__bsc_parameter') }}
)

select
    toInt64(1)                                                                                      as bsc_parameter_key,
    toFloat64(ifNull((select anyOrNull(value) from p where name = 'clinic_hours_per_day'), 8))      as clinic_hours_per_day,
    toFloat64(ifNull((select anyOrNull(value) from p where name = 'clinic_patients_per_hour'), 4))  as clinic_patients_per_hour,
    toFloat64(ifNull((select anyOrNull(value) from p where name = 'ancillary_target_share'), 0.6))  as ancillary_target_share
