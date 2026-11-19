{#- Physician review columns from dim_review_physician (one row per staff_key). is_review_physician stays a number, as the
    int_flags of other views: the measures filter it = 1. -#}
{{ hnh_ssas_view('dim_staff', drop=['national_id_hash', 'home_department_key'], floats=['clinic_duration_hours', 'slots_per_hour'],
    extra=['toInt64(ifNull(rp.is_review_physician, 0)) as is_review_physician', "ifNull(rp.job_title, 'Not linked') as job_title",
           "ifNull(rp.pay_grade, 'Not linked') as pay_grade", "ifNull(rp.employment_type, 'Not linked') as employment_type",
           'rp.hire_date as hire_date', 'toInt64(ifNull(rp.review_physician_key, -1)) as review_physician_key'],
    joins='left join ' ~ ref('dim_review_physician') ~ ' as rp on rp.staff_key = t.staff_key') }}
