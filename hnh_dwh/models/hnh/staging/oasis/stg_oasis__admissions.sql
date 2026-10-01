select
    toUInt8(branch_id)                                    as branch_id,
    toInt64(admission_no)                                 as admission_no,
    {{ hnh_id('patient_id') }}                            as patient_id,
    {{ hnh_id('episode_no') }}                            as episode_no,
    {{ hnh_ksa_wall_clock('admit_date') }}                as admitted_at,
    {{ hnh_ksa_wall_clock('seen_date') }}                 as seen_at,
    {{ hnh_ksa_wall_clock('est_discharge_date') }}        as estimated_discharge_at,
    {{ hnh_ksa_wall_clock('clinical_discharge_date') }}   as clinical_discharge_at,
    {{ hnh_ksa_wall_clock('physical_discharge_date') }}   as physical_discharge_at,
    {{ hnh_ksa_wall_clock('financial_discharge_date') }}  as financial_discharge_at,
    {{ hnh_id('status') }}                                as status_code,
    {{ hnh_id('outcome') }}                               as outcome_code,
    {{ hnh_id('bed_class') }}                             as bed_class,
    {{ hnh_id('referred_type') }}                         as referred_type_code,
    {{ hnh_id('admission_mode') }}                        as admission_mode_code,
    {{ hnh_code('treated_by') }}                          as treating_staff_id
from {{ hnh_oasis_source('patient_ad') }} final
