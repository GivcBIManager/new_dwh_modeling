{{ config(order_by='payer_key') }}

with purchasers as (
    select
        p.branch_id        as branch_id,
        p.purchaser_code   as purchaser_code,
        ifNull(p.description, ea.account_name) as purchaser_name,
        p.account_code     as account_code,
        initcap(coalesce(pm.insurer, ea.account_name, p.description, 'Not Mapped')) as company,
        if(pm.creditor = 'TPA', 'TPA', initcap(ifNull(pm.creditor, 'Not Mapped')))  as creditor,
        initcap(ifNull(pm.category, 'Not Mapped'))      as category,
        initcap(ifNull(pm.billing_type, 'Not Mapped'))  as billing_type,
        pm.manual_submission                            as manual_submission,
        if(startsWith(ifNull(p.account_code, ''), 'INS') or ifNull(upper(p.description), '') like '%GOSI%',
           'Insurance', 'Not insurance')                as purchaser_type,
        p.is_tpa           as is_tpa,
        p.is_active        as is_active,
        p.cchi_no          as cchi_no,
        p.nphies_license   as nphies_license
    from {{ ref('stg_oasis__purchasers') }} as p
    left join {{ ref('stg_oasis__external_accounts') }} as ea
        on ea.branch_id = p.branch_id and ea.account_code = p.account_code
       and ea.account_type = p.account_type and ea.c_id = p.account_c_id
    left join {{ ref('stg_ref__purchaser_mapping') }} as pm
        on pm.branch_id = p.branch_id and pm.purchaser_code = p.purchaser_code
    where p.purchaser_code not in (9999, 8888)
),

synthetic as (
    select branch_id, toInt64(9999) as purchaser_code, 'Cash' as purchaser_name, 'Cash' as creditor
    from {{ ref('stg_ref__branch') }}
    union all
    select branch_id, toInt64(8888), 'Cash', 'Deductible'
    from {{ ref('stg_ref__branch') }}
)

select * from (

select
    {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }} as payer_key,
    branch_id                              as branch_key,
    toNullable(purchaser_code)             as purchaser_code,
    purchaser_name                         as purchaser_name,
    account_code                           as account_code,
    company                                as company,
    creditor                               as creditor,
    category                               as category,
    billing_type                           as billing_type,
    manual_submission                      as manual_submission,
    purchaser_type                         as purchaser_type,
    is_tpa                                 as is_tpa,
    toUInt8(creditor = 'Government')       as is_moh,
    is_active                              as is_active,
    cchi_no                                as cchi_no,
    nphies_license                         as nphies_license
from purchasers

union all

select
    {{ hnh_surrogate_key(['branch_id', 'purchaser_code']) }},
    branch_id, toNullable(purchaser_code), purchaser_name, 'Cash', 'Cash', creditor, 'Cash', 'Cash', 'N',
    'Cash', toUInt8(0), toUInt8(0), toUInt8(1), null, null
from synthetic

union all

select
    toInt64(-1), toUInt8(0), null, 'Unknown', null, 'Unknown', 'Unknown', 'Unknown', 'Unknown', null,
    'Unknown', toUInt8(0), toUInt8(0), toUInt8(1), null, null

)
{{ hnh_settings() }}
