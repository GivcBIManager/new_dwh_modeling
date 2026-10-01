{{ config(order_by='(branch_key, date_key, bed_key)') }}

with d as (
    select
        *,
        {{ hnh_surrogate_key(['branch_id', 'bed_location']) }}   as bed_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'work_entity']) }}    as department_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'patient_id']) }}     as patient_key_raw,
        {{ hnh_surrogate_key(['branch_id', 'admission_no']) }}   as admission_key
    from {{ ref('int_bed_day') }}
)

select
    d.branch_id                                 as branch_key,
    toInt32(toYYYYMMDD(d.date_day))             as date_key,
    ifNull(db.bed_key, toInt64(-1))             as bed_key,
    ifNull(dd.department_key, toInt64(-1))      as department_key,
    ifNull(dp.patient_key, toInt64(-1))         as patient_key,
    d.admission_key                             as admission_key,
    d.is_available                              as is_available,
    d.is_occupied                               as is_occupied,
    d.is_excluded_ward                          as is_excluded_ward,
    d.is_inpatient_ward                         as is_inpatient_ward,
    now()                                       as _loaded_at
from d
left join (select bed_key from {{ ref('dim_bed') }}) as db on db.bed_key = d.bed_key_raw
left join (select department_key from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = d.department_key_raw
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = d.patient_key_raw
{{ hnh_settings() }}
