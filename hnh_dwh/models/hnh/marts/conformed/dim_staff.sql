{{ config(order_by='staff_key') }}

with latest_post as (
    -- Latest post by start; ties broken by the highest posts_id.
    select
        branch_id, staff_id,
        argMax(work_entity, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), ifNull(posts_id, 0)))   as work_entity,
        argMax(position_type, tuple(ifNull(started_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh')), ifNull(posts_id, 0))) as position_type
    from {{ ref('stg_oasis__staff_posts') }}
    where staff_id is not null
    group by branch_id, staff_id
),

latest_contract as (
    select
        branch_id, staff_id,
        argMax(terminated_at, tuple(ifNull(started_at, toDate32('1970-01-01')), staff_contract_no))           as terminated_at,
        argMax(termination_reason_code, tuple(ifNull(started_at, toDate32('1970-01-01')), staff_contract_no)) as termination_reason_code
    from {{ ref('stg_oasis__staff_contracts') }}
    where staff_id is not null
    group by branch_id, staff_id
),

doctor_department as (
    select branch_id, staff_id,
           argMax(department, ifNull(created_at, toDateTime('1970-01-01 03:00:00', 'Asia/Riyadh'))) as home_dept
    from {{ ref('stg_oasis__doctor_departments') }}
    where staff_id is not null and department is not null
    group by branch_id, staff_id
),

classification as (
    select branch_id, staff_type,
           any(classification) as classification, any(category) as category, any(med_nonmed) as med_nonmed
    from {{ ref('stg_oasis__staff_type_classifications') }}
    group by branch_id, staff_type
),

licence as (
    select pd.branch_id as branch_id, pd.staff_id as staff_id,
           argMax(pd.doc_number, tuple(ifNull(pd.valid_from, toDate32('1970-01-01')), pd.document_id)) as licence_no
    from {{ ref('stg_oasis__personnel_documents') }} as pd
    inner join {{ ref('int_code_decode') }} as d
        on d.branch_id = pd.branch_id and d.code = pd.doc_type
    where pd.staff_id is not null
      and pd.doc_number is not null
      and d.description_upper = 'SAUDI COMMISSION FOR HEALTH SPECIALISTS'
    group by pd.branch_id, pd.staff_id
),

base as (
    select
        s.branch_id                as branch_id,
        s.staff_id                 as staff_id,
        s.name_1 as name_1, s.name_2 as name_2, s.name_3 as name_3, s.family_name as family_name,
        s.name_ar_1 as name_ar_1, s.name_ar_2 as name_ar_2, s.name_ar_3 as name_ar_3, s.family_name_ar as family_name_ar,
        s.sex                      as sex,
        s.staff_type               as staff_type,
        s.nationality_code         as nationality_code,
        s.service_start_date       as service_start_date,
        s.national_id              as national_id,
        lp.work_entity             as home_work_entity,
        lp.position_type           as position_type,
        hd.work_entity is not null as has_home_department,
        lc.staff_id is not null    as has_contract,
        lc.terminated_at           as terminated_at,
        lc.termination_reason_code as termination_reason_code,
        upper(coalesce(dd.home_dept, hd.service_department_name, hd.department_name)) as specialty_upper,
        lic.licence_no             as licence_no
    from {{ ref('stg_oasis__staff') }} as s
    left join latest_post as lp on lp.branch_id = s.branch_id and lp.staff_id = s.staff_id
    left join latest_contract as lc on lc.branch_id = s.branch_id and lc.staff_id = s.staff_id
    left join doctor_department as dd on dd.branch_id = s.branch_id and dd.staff_id = s.staff_id
    left join {{ ref('int_department_conformed') }} as hd
        on hd.branch_id = s.branch_id and hd.work_entity = lp.work_entity
    left join licence as lic on lic.branch_id = s.branch_id and lic.staff_id = s.staff_id
    where s.staff_id is not null
)

select * from (

select
    {{ hnh_surrogate_key(['b.branch_id', 'b.staff_id']) }}   as staff_key,
    b.branch_id                                              as branch_key,
    toNullable(b.staff_id)                                   as staff_id,
    nullIf(replaceRegexpAll(trimBoth(concat(
        initcap(concat(ifNull(b.name_1, ''), ' ', ifNull(b.name_2, ''), ' ', ifNull(b.name_3, ''))), ' ', upper(ifNull(b.family_name, ''))
    )), '\\s+', ' '), '')                                    as staff_name,
    nullIf(replaceRegexpAll(trimBoth(concat(
        ifNull(b.name_ar_1, ''), ' ', ifNull(b.name_ar_2, ''), ' ', ifNull(b.name_ar_3, ''), ' ', ifNull(b.family_name_ar, '')
    )), '\\s+', ' '), '')                                    as staff_name_ar,
    multiIf(b.sex = 'M', 'Male', b.sex = 'F', 'Female', 'Unknown') as gender,
    ifNull(initcap(nat.description), 'Unknown')              as nationality,
    toUInt8(ifNull(nat.description_upper, '') = 'SAUDI ARABIA') as is_saudi,
    st.description                                           as staff_grade,
    cl.classification                                        as classification,
    cl.category                                              as category,
    cl.med_nonmed                                            as med_nonmed,
    toUInt8(ifNull(st.is_consultant, 0))                     as is_consultant,
    pos.description                                          as position_name,
    if(b.has_home_department, {{ hnh_surrogate_key(['b.branch_id', 'b.home_work_entity']) }}, toInt64(-1)) as home_department_key,
    ifNull(initcap(b.specialty_upper), 'Unknown')            as specialty,
    ifNull(ud.unified_department, 'Not Mapped')              as unified_specialty,
    toUInt8(ifNull(ud.not_admitting, 0))                     as is_non_admitting_specialty,
    toUInt8(ifNull(ud.high_value, 0))                        as is_high_value_specialty,
    cd.clinic_duration_hours                                 as clinic_duration_hours,
    cd.slots_per_hour                                        as slots_per_hour,
    b.licence_no                                             as scfhs_licence_no,
    multiIf(not b.has_contract, 'No contract', b.terminated_at is null, 'Active', 'Terminated') as contract_status,
    b.terminated_at                                          as termination_date,
    tr.unified_reason                                        as termination_reason,
    b.service_start_date                                     as service_start_date,
    if({{ hnh_is_valid_national_id('b.national_id') }}, toInt64(bitShiftRight(cityHash64(concat('N:', {{ hnh_normalise_identifier('b.national_id') }})), 1)), null) as national_id_hash
from base as b
left join {{ ref('int_code_decode') }} as nat on nat.branch_id = b.branch_id and nat.code = b.nationality_code
left join {{ ref('stg_oasis__staff_types') }} as st on st.branch_id = b.branch_id and st.staff_type = b.staff_type
left join classification as cl on cl.branch_id = b.branch_id and cl.staff_type = b.staff_type
left join {{ ref('stg_oasis__positions') }} as pos on pos.branch_id = b.branch_id and pos.position_type = b.position_type
left join {{ ref('stg_ref__unified_department') }} as ud on ud.department = b.specialty_upper
left join {{ ref('stg_ref__clinic_duration') }} as cd on cd.specialty = b.specialty_upper
left join {{ ref('stg_ref__termination_reason') }} as tr
    on tr.branch_id = b.branch_id and tr.termination_reason_code = b.termination_reason_code

union all

select
    toInt64(-1), toUInt8(0), null, 'Unknown', null, 'Unknown', 'Unknown', toUInt8(0), null, null, null, null,
    toUInt8(0), null, toInt64(-1), 'Unknown', 'Unknown', toUInt8(0), toUInt8(0), null, null, null,
    'Unknown', null, null, null, null

)
{{ hnh_settings() }}
