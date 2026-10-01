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

select * from (

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.patient_id']) }} as patient_key,
    p.branch_id                                              as branch_key,
    toNullable(p.patient_id)                                 as patient_id,
    mrn.mrn                                                  as mrn,
    multiIf(p.sex = 'M', 'Male', p.sex = 'F', 'Female', 'Unknown') as gender,
    p.birth_date                                             as birth_date,
    ifNull(initcap(nat.description), 'Unknown')              as nationality,
    toUInt8(ifNull(nat.description_upper, '') = 'SAUDI ARABIA') as is_saudi,
    ifNull(initcap(mar.description), 'Unknown')              as marital_status,
    ifNull(initcap(occ.description), 'Unknown')              as occupation,
    p.registered_date                                        as registered_date,
    p.registered_dept                                        as registered_dept,
    p.status                                                 as status,
    p.is_chronic                                             as is_chronic,
    p.is_at_risk                                             as is_at_risk,
    toUInt8(p.merged_into_patient_id is not null)            as is_merged,
    toInt64(bitShiftRight(cityHash64(
        {{ hnh_person_identifier('ids.national_id', 'ids.passport_no', 'ids.border_no', 'p.branch_id', 'p.patient_id') }}
    ), 1))                                                   as person_key,
    {{ hnh_person_identifier_source('ids.national_id', 'ids.passport_no', 'ids.border_no') }} as person_key_source
from {{ ref('stg_oasis__patients') }} as p
left join mrn on mrn.branch_id = p.branch_id and mrn.patient_id = p.patient_id
left join ids on ids.branch_id = p.branch_id and ids.patient_id = p.patient_id
left join {{ ref('int_code_decode') }} as nat on nat.branch_id = p.branch_id and nat.code = p.nationality_code
left join {{ ref('int_code_decode') }} as mar on mar.branch_id = p.branch_id and mar.code = p.marital_code
left join {{ ref('int_code_decode') }} as occ on occ.branch_id = p.branch_id and occ.code = p.occupation_code

union all

select
    toInt64(-1), toUInt8(0), null, null, 'Unknown', null, 'Unknown', toUInt8(0), 'Unknown', 'Unknown',
    null, null, null, toUInt8(0), toUInt8(0), toUInt8(0), toInt64(-1), 'Unknown'

)
{{ hnh_settings() }}
