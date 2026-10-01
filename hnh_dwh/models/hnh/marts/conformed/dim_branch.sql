{{ config(order_by='branch_key') }}

select * from (

select
    b.branch_id                          as branch_key,
    b.branch_name                        as branch_name,
    b.city                               as city,
    b.licensed_beds                      as licensed_beds,
    c.clinics_count                      as clinics_count,
    toNullable(b.fusion_branch_code)     as fusion_branch_code,
    toNullable(b.fusion_ledger_id)       as fusion_ledger_id,
    b.pg_branch_code                     as pg_branch_code
from {{ ref('stg_ref__branch') }} as b
left join {{ ref('stg_ref__clinic_count') }} as c on c.branch_id = b.branch_id

union all

select
    toUInt8(0), 'Group', 'Group',
    toInt32((select sum(licensed_beds) from {{ ref('stg_ref__branch') }})),
    toInt32((select sum(clinics_count) from {{ ref('stg_ref__clinic_count') }})),
    null, null, null

)
{{ hnh_settings() }}
