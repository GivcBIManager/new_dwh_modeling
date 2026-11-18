{{ config(order_by='(branch_key, month_start, pl_line_key, account_code)') }}

-- The P&L report (Fusion HNH profitability report) by branch, month and report line, credit positive (pl report spec
-- section 3). Branches 1-8: the Oasis income-statement rows of fact_gl_fs_monthly, which stop at the branch's first
-- Fusion GL month; from it, the Fusion GL read here at account-combination grain for the slicers
-- (hnh_pl_report_fusion_details, including unposted, opening-balance journals out). Head Office (100): always Fusion.
-- Labels resolve to report lines and subtotals add their sections in hnh_pl_report_rows.
with oasis as (
    select
        branch_key, month_start, cast(source_system as String) as source_system, account_code, account_name,
        cast(fs_category as String) as fs_category, cast(fs_caption as String) as fs_caption,
        cast(fs_line as String) as fs_line, 'Unallocated' as specialty_name, 'Unallocated' as service_location_name,
        'Unallocated' as service_group_name, -movement as amount
    from {{ ref('fact_gl_fs_monthly') }}
    where source_system = 'oasis' and fs_type = 'is'
),

-- Fusion: the natural account name, title-cased here (Oasis names come title-cased from fact_gl_fs_monthly); the code
-- stands in for a missing name
fusion as (
    select
        f.branch_key as branch_key, f.month_start as month_start, f.source_system as source_system,
        f.account_code as account_code,
        ifNull(nullIf({{ hnh_title('f.account_name') }}, ''), f.account_code) as account_name,
        f.fs_category as fs_category, f.fs_caption as fs_caption, f.fs_line as fs_line,
        f.specialty_name as specialty_name, f.service_location_name as service_location_name,
        f.service_group_name as service_group_name, f.amount as amount
    from ({{ hnh_pl_report_fusion_details('including_unposted') }}) as f
),

details as (
    select branch_key, month_start, source_system, account_code, account_name, fs_category, fs_caption, fs_line,
           specialty_name, service_location_name, service_group_name, amount
    from oasis
    union all
    select branch_key, month_start, source_system, account_code, account_name, fs_category, fs_caption, fs_line,
           specialty_name, service_location_name, service_group_name, amount
    from fusion
)

select
    toUInt8(branch_key)                         as branch_key,
    month_start,
    toLowCardinality(source_system)             as source_system,
    toUInt16(pl_line_key)                       as pl_line_key,
    toLowCardinality(pl_line_code)              as pl_line_code,
    account_code,
    account_name,
    toLowCardinality(fs_category)               as fs_category,
    toLowCardinality(fs_caption)                as fs_caption,
    toLowCardinality(fs_line)                   as fs_line,
    toLowCardinality(specialty_name)            as specialty_name,
    toLowCardinality(service_location_name)     as service_location_name,
    toLowCardinality(service_group_name)        as service_group_name,
    amount,
    now()                                       as _loaded_at
from ({{ hnh_pl_report_rows('details') }})
{{ hnh_settings() }}
