-- Legal employer (an organisation named "HNH <name>") to branch: "<name>" is a Fusion business-unit name whose
-- primary ledger is the branch's ledger (spec 4.1). Unresolved employers get branch 0, which the facts' tests reject.
select
    o.organization_id                                   as legal_employer_id,
    ifNull(o.organization_name, '')                     as legal_employer_name,
    ifNull(b.branch_key, toUInt8(0))                    as branch_key
from {{ ref('stg_fusion__organizations') }} as o
left join (select business_unit_name, primary_ledger_id from {{ ref('stg_fusion__business_units') }}) as bu
    on bu.business_unit_name = replaceOne(ifNull(o.organization_name, ''), 'HNH ', '')
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = bu.primary_ledger_id
where ifNull(o.classification_codes, '') like '%HCM_LEMP%'
{{ hnh_settings() }}
