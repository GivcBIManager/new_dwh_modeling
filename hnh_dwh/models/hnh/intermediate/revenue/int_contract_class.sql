{{ config(order_by='(branch_id, contract_no)') }}

-- The insurance class (VIP, A, B, C) of each contract that has one (policy class design 2026-11-18).
-- 1. The Oasis class description (contract -> class_id -> policy_classes), upper-cased: a class after a caret
--    ("NTW2+^B", "GOSI^C"), else a stand-alone VIP, A, B or C ("VIP", "CLASS A"). The patterns are the old server's.
-- 2. Else the old server's hand mapping (stg_ref__contract_class), for contracts whose description has no class.
-- The description wins when both give a class; the old server did the opposite. Contracts with neither have no row.
-- Referral policies (REF) are decided per charge line in int_charge_line_links.

with described as (
    select
        c.branch_id                                                 as branch_id,
        c.contract_no                                               as contract_no,
        upperUTF8(ifNull(pc.description, ''))                       as class_text,
        coalesce(nullIf(extract(class_text, '\\^\\s*(VIP|A|B|C)'), ''),
                 nullIf(extract(class_text, '(?:^|\\s)(VIP|A|B|C)(?:\\s|$)'), '')) as description_class
    from {{ ref('stg_oasis__contracts') }} as c
    left join {{ ref('stg_oasis__policy_classes') }} as pc
        on pc.branch_id = c.branch_id and pc.class_id = c.class_id
),

contracts as (
    select branch_id, contract_no from described
    union distinct
    select branch_id, contract_no from {{ ref('stg_ref__contract_class') }}
)

select
    k.branch_id                                                     as branch_id,
    k.contract_no                                                   as contract_no,
    assumeNotNull(coalesce(d.description_class, m.classification))  as policy_class,
    if(d.description_class is not null, 'Description', 'Mapping')   as class_source
from contracts as k
left join described as d
    on d.branch_id = k.branch_id and d.contract_no = k.contract_no
left join (select branch_id, contract_no, classification from {{ ref('stg_ref__contract_class') }}) as m
    on m.branch_id = k.branch_id and m.contract_no = k.contract_no
where coalesce(d.description_class, m.classification) is not null
{{ hnh_settings() }}
