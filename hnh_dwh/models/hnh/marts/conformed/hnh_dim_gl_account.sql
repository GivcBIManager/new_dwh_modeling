{{ config(alias='dim_gl_account', order_by='gl_account_key') }}

with branches as (
    select branch_key, fusion_branch_code from {{ ref('hnh_dim_branch') }} where fusion_branch_code is not null
),

seg as (select segment_column_name, segment_value, segment_value_name from {{ ref('stg_fusion__coa_segment_values') }}),

base as (
    select
        a.code_combination_id                                               as code_combination_id,
        a.branch_segment                                                    as branch_segment,
        a.natural_account                                                   as natural_account,
        a.specialty_code                                                    as specialty_code,
        a.service_location_code                                             as service_location_code,
        a.service_group_code                                                as service_group_code,
        a.intercompany_segment                                              as intercompany_segment,
        a.account_type                                                      as account_type,
        a.is_enabled                                                        as is_enabled,
        a.is_summary                                                        as is_summary,
        {{ hnh_gl_care_type('a.service_location_code') }}                   as revenue_care_type,
        {{ hnh_gl_balance_side('f.fs_type', 'a.account_type') }}            as balance_side,
        multiIf(f.natural_account is null, 'not mapped', f.mapped_in = 'inferred', 'inferred', 'supplied') as fs_mapping_source,
        ifNull(f.fs_element, {{ hnh_not_mapped_element('a.account_type') }}) as fs_element_r,
        ifNull(f.fs_category, 'Not mapped')                                 as fs_category_r,
        ifNull(f.fs_caption, 'Not mapped')                                  as fs_caption_r,
        ifNull(f.fs_line, 'Not mapped')                                     as fs_line_r
    from {{ ref('stg_fusion__gl_accounts') }} as a
    left join {{ ref('stg_ref__fs_account') }} as f on f.natural_account = a.natural_account
    {{ hnh_settings() }}
),

candidates as (
    -- every budget rule that matches an income-statement account; the most specific level wins
    select b.code_combination_id as code_combination_id, m.line_item_code as line_item_code,
           multiIf(m.match_level = 'account', 1, m.match_level = 'line', 2, m.match_level = 'caption', 3, 4) as match_rank
    from base as b
    cross join {{ ref('stg_ref__budget_fs_line') }} as m
    where b.balance_side = 'IS'
      and (m.care_type is null or m.care_type = b.revenue_care_type)
      and ((m.match_level = 'account' and m.match_value_lower = toString(b.natural_account))
        or (m.match_level = 'line' and m.match_value_lower = lower(b.fs_line_r))
        or (m.match_level = 'caption' and m.match_value_lower = lower(b.fs_caption_r))
        or (m.match_level = 'category' and m.match_value_lower = lower(b.fs_category_r)))
),

picked as (
    select code_combination_id, argMin(line_item_code, match_rank) as picked_code
    from candidates
    group by code_combination_id
),

mapped_accounts as (
select
    {{ hnh_surrogate_key(['b.code_combination_id']) }}                      as gl_account_key,
    toNullable(b.code_combination_id)                                       as code_combination_id,
    ifNull(br.branch_key, toUInt8(0))                                       as branch_key,
    b.branch_segment                                                        as branch_segment,
    b.natural_account                                                       as natural_account,
    s2.segment_value_name                                                   as natural_account_name,
    b.specialty_code                                                        as specialty_code,
    s3.segment_value_name                                                   as specialty_name,
    b.service_location_code                                                 as service_location_code,
    s4.segment_value_name                                                   as service_location_name,
    b.service_group_code                                                    as service_group_code,
    s5.segment_value_name                                                   as service_group_name,
    b.intercompany_segment                                                  as intercompany_segment,
    ic.branch_key                                                           as intercompany_branch_key,
    b.account_type                                                          as account_type,
    b.balance_side                                                          as balance_side,
    {{ hnh_fs_line_key('b.balance_side', 'b.fs_element_r', 'b.fs_category_r', 'b.fs_caption_r', 'b.fs_line_r') }} as fs_line_key,
    b.fs_mapping_source                                                     as fs_mapping_source,
    b.revenue_care_type                                                     as revenue_care_type,
    if(b.balance_side = 'IS', ifNull(p.picked_code, 'UNBUDGETED'), cast(null as Nullable(String))) as budget_line_code,
    sp.unified_department                                                   as unified_department,
    b.is_enabled                                                            as is_enabled,
    b.is_summary                                                            as is_summary
from base as b
left join picked as p on p.code_combination_id = b.code_combination_id
left join branches as br on br.fusion_branch_code = b.branch_segment
left join branches as ic on ic.fusion_branch_code = toInt64OrNull(b.intercompany_segment)
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT2') as s2 on s2.segment_value = toString(b.natural_account)
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT3') as s3 on s3.segment_value = b.specialty_code
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT4') as s4 on s4.segment_value = b.service_location_code
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT5') as s5 on s5.segment_value = b.service_group_code
left join {{ ref('stg_ref__fusion_specialty_unified') }} as sp on sp.specialty_code = b.specialty_code
    {{ hnh_settings() }}
)

select * from mapped_accounts

union all

-- one account per branch that carries the income-statement result of earlier fiscal years (spec 6.2)
select
    {{ hnh_prior_year_results_key('branch_key') }}, cast(null as Nullable(Int64)), branch_key,
    toNullable(fusion_branch_code), toNullable(toUInt32(36101101)), toNullable('Prior-year results'),
    null, null, null, null, null, null, null, cast(null as Nullable(UInt8)), toNullable('O'), 'BS',
    {{ hnh_fs_line_key("'BS'", "'Equity'", "'Equity'", "'Retained earnings'", "'Retained earnings'") }},
    'prior-year roll', 'Unallocated', cast(null as Nullable(String)), cast(null as Nullable(String)), toUInt8(1), toUInt8(0)
from branches

union all

select
    toInt64(-1), cast(null as Nullable(Int64)), toUInt8(0), null, null, toNullable('Unknown'),
    null, null, null, null, null, null, null, cast(null as Nullable(UInt8)), null, 'BS',
    {{ hnh_fs_line_key("'BS'", "'Assets'", "'Not mapped'", "'Not mapped'", "'Not mapped'") }},
    'not mapped', 'Unallocated', cast(null as Nullable(String)), cast(null as Nullable(String)), toUInt8(0), toUInt8(0)
{{ hnh_settings() }}
