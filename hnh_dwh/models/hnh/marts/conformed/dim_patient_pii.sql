{{ config(order_by='patient_key') }}

with mrn as (
    select branch_id, patient_id, min(user_file_id) as mrn
    from {{ ref('stg_oasis__patient_files') }}
    where patient_id is not null and user_file_id is not null
    group by branch_id, patient_id
),

ids as (
    select
        i.branch_id   as branch_id,
        i.patient_id  as patient_id,
        minIf(i.id_number, d.description_upper in ('NATIONAL NUMBER', 'IQAMA')) as national_id,
        minIf(i.id_number, d.description_upper = 'PASSPORT')                    as passport_no,
        minIf(i.id_number, d.description_upper = 'BOARDER NUMBER')              as border_no
    from {{ ref('stg_oasis__patient_ids') }} as i
    inner join {{ ref('int_code_decode') }} as d
        on d.branch_id = i.branch_id and d.code = i.id_type_code
    where i.patient_id is not null and i.id_number is not null
    group by i.branch_id, i.patient_id
)

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.patient_id']) }} as patient_key,
    p.branch_id                as branch_key,
    p.patient_id               as patient_id,
    mrn.mrn                    as mrn,
    nullIf(replaceRegexpAll(trimBoth(concat(
        ifNull(p.name_1, ''), ' ', ifNull(p.name_2, ''), ' ', ifNull(p.name_3, ''), ' ', ifNull(p.family_name, '')
    )), '\\s+', ' '), '')      as full_name,
    nullIf(replaceRegexpAll(trimBoth(concat(
        ifNull(p.name_ar_1, ''), ' ', ifNull(p.name_ar_2, ''), ' ', ifNull(p.name_ar_3, ''), ' ', ifNull(p.family_name_ar, '')
    )), '\\s+', ' '), '')      as full_name_ar,
    ids.national_id            as national_id,
    ids.passport_no            as passport_no,
    ids.border_no              as border_no,
    p.mobile_no                as mobile_no,
    p.email_address            as email_address
from {{ ref('stg_oasis__patients') }} as p
left join mrn on mrn.branch_id = p.branch_id and mrn.patient_id = p.patient_id
left join ids on ids.branch_id = p.branch_id and ids.patient_id = p.patient_id
{{ hnh_settings() }}
