{{ config(order_by='policy_key') }}

-- One row per Oasis policy (branch + policy code) with its insurer and client company, plus three members per branch
-- for charge lines without a policy code: -2 Cash, -3 Deductible, -1 Not Recorded; and the Unknown row (key -1).
-- client_company is the BI manager's name from default.map_policy_client as written, or the client name taken from
-- the description by int_policy_client, title-cased here.

with policies as (
    select
        p.branch_id       as branch_id,
        p.policy_code     as policy_code,
        p.policy_name     as policy_name,
        py.company        as insurer,
        p.client_company  as client_company,
        p.is_client_from_rule as is_client_from_rule,
        p.is_referral     as is_referral,
        p.is_active       as is_active
    from {{ ref('int_policy_client') }} as p
    left join (select branch_key, purchaser_code, company from {{ ref('dim_payer') }}) as py
        on py.branch_key = p.branch_id and py.purchaser_code = p.purchaser_code
),

members as (
    select b.branch_key as branch_id, m.policy_code as policy_code, m.label as label, m.insurer as insurer
    from (select branch_key from {{ ref('hnh_dim_branch') }}) as b
    cross join (
        select toInt64(c) as policy_code, l as label, i as insurer
        from values('c Int64, l String, i String', (-2, 'Cash', 'Cash'), (-3, 'Deductible', 'Deductible'),
                    (-1, 'Not Recorded', 'Not Recorded'))
    ) as m
)

select * from (

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.policy_code']) }} as policy_key,
    p.branch_id                                            as branch_key,
    toNullable(p.policy_code)                              as policy_code,
    ifNull({{ hnh_title('p.policy_name') }}, 'Not named')  as policy_name,
    ifNull(p.insurer, 'Unknown')                           as insurer,
    if(p.is_client_from_rule = 1, p.client_company, {{ hnh_title('p.client_company') }}) as client_company,
    p.is_referral                                          as is_referral,
    p.is_active                                            as is_active
from policies as p

union all

select
    {{ hnh_surrogate_key(['m.branch_id', 'm.policy_code']) }},
    m.branch_id, toNullable(m.policy_code), m.label, m.insurer, m.label, toUInt8(0), toUInt8(1)
from members as m

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', 'Unknown', toUInt8(0), toUInt8(1)

)
{{ hnh_settings() }}
