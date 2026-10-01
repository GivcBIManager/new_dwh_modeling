{{ config(order_by='(branch_id, code)') }}

with codes as (
    select * from {{ ref('stg_oasis__codes_data') }} where code > 0
),

moh as (
    select branch_id, reason_upper, any(moh_code) as moh_code
    from (
        select branch_id, upper(reason) as reason_upper, moh_code from {{ ref('stg_oasis__discharge_mode_moh') }}
        union all
        select branch_id, upper(reason) as reason_upper, moh_code from {{ ref('stg_oasis__admission_reason_moh') }}
    )
    where reason_upper is not null
    group by branch_id, reason_upper
)

select
    c.branch_id          as branch_id,
    c.code               as code,
    c.code_type          as code_type,
    c.description        as description,
    upper(c.description) as description_upper,
    c.description_ar     as description_ar,
    c.user_code          as user_code,
    c.prog_code          as prog_code,
    m.moh_code           as moh_code
from codes as c
left join moh as m
    on m.branch_id = c.branch_id and m.reason_upper = upper(c.description)
{{ hnh_settings() }}
