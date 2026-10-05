{{ config(alias='dim_branch', order_by='branch_key') }}

select * from (

select
    b.branch_id                          as branch_key,
    b.branch_name                        as branch_name,
    b.city                               as city,
    b.licensed_beds                      as licensed_beds,
    c.clinics_count                      as clinics_count,
    toNullable(b.fusion_branch_code)     as fusion_branch_code,
    toNullable(b.fusion_ledger_id)       as fusion_ledger_id,
    b.pg_branch_code                     as pg_branch_code,
    toUInt64(ifNull(lb.beds, 0))         as legacy_current_available_beds
from {{ ref('stg_ref__branch') }} as b
left join {{ ref('stg_ref__clinic_count') }} as c on c.branch_id = b.branch_id
left join (
    select branch_key, count() as beds
    from {{ ref('dim_bed') }}
    where is_currently_available = 1 and bed_key != -1
    group by branch_key
) as lb on lb.branch_key = b.branch_id

union all

select
    toUInt8(0), 'Group', 'Group',
    toInt32((select sum(licensed_beds) from {{ ref('stg_ref__branch') }})),
    toInt32((select sum(clinics_count) from {{ ref('stg_ref__clinic_count') }})),
    null, null, null,
    toUInt64((select count() from {{ ref('dim_bed') }} where is_currently_available = 1 and bed_key != -1))

union all

select
    toUInt8(100), 'Head Office', 'Riyadh', toInt32(0), toInt32(0),
    toNullable(toInt64({{ var('hnh_head_office_fusion_branch_code') }})),
    toNullable(toInt64({{ var('hnh_head_office_ledger_id') }})),
    null,
    toUInt64(0)

)
{{ hnh_settings() }}
