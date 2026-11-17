{{ config(order_by='(branch_key, month_start, pl_line_key)') }}

-- Explains the warehouse P&L report (fact_pl_report_monthly) against the Fusion report, per branch, month and report
-- line (detail and subtotal). Fusion months: posted_amount is the same pipeline on the posted balance view, so
-- unposted_amount = report - posted is what the Fusion report shows only because it includes unposted journals.
-- moved_accounts_amount is the part of report_amount on accounts that finance moved to another report line in the
-- reference mapping (effective mapped_in 'pl-report': the branch's own row if it has one, else the row for all
-- branches, as hnh_dim_gl_account applies branch rows). Oasis months have no posted view: posted = report, compare with the Oasis
-- trial balance. Each side is summed per line, so a line only one side has still shows.
with report as (
    select branch_key, month_start, source_system, pl_line_key, pl_line_code, sum(amount) as amount
    from {{ ref('fact_pl_report_monthly') }}
    group by branch_key, month_start, source_system, pl_line_key, pl_line_code
),

posted_details as (
    {{ hnh_pl_report_fusion_details('posted') }}
),

-- the Fusion details of the report, kept to the accounts whose effective mapping row is 'pl-report': the row of the
-- account's Fusion branch code where there is one, else the row for all branches (as hnh_dim_gl_account picks it)
moved_details as (
    select d.*
    from ({{ hnh_pl_report_fusion_details('including_unposted') }}) as d
    left join (
        select branch_key, fusion_branch_code from {{ ref('hnh_dim_branch') }}
    ) as b on b.branch_key = d.branch_key
    left join (
        select toString(natural_account) as account_code, mapped_in
        from {{ ref('stg_ref__fs_account') }}
        where branch_segment is null
    ) as fd on fd.account_code = d.account_code
    left join (
        select toString(natural_account) as account_code, branch_segment, mapped_in
        from {{ ref('stg_ref__fs_account') }}
        where branch_segment is not null
    ) as fb on fb.account_code = d.account_code and fb.branch_segment = b.fusion_branch_code
    where ifNull(fb.mapped_in, fd.mapped_in) = 'pl-report'
),

posted as ({{ hnh_pl_report_rows('posted_details') }}),

moved as ({{ hnh_pl_report_rows('moved_details') }}),

parts as (
    select branch_key, month_start, source_system, pl_line_key, pl_line_code,
           amount as report_amount, if(source_system = 'oasis', amount, 0) as posted_amount, 0 as moved_amount
    from report
    union all
    select branch_key, month_start, source_system, pl_line_key, pl_line_code, 0, sum(amount), 0
    from posted
    group by branch_key, month_start, source_system, pl_line_key, pl_line_code
    union all
    select branch_key, month_start, source_system, pl_line_key, pl_line_code, 0, 0, sum(amount)
    from moved
    group by branch_key, month_start, source_system, pl_line_key, pl_line_code
),

summed as (
    select
        branch_key, month_start, source_system, pl_line_key, pl_line_code,
        sum(report_amount) as report_amount, sum(posted_amount) as posted_amount, sum(moved_amount) as moved_accounts_amount
    from parts
    group by branch_key, month_start, source_system, pl_line_key, pl_line_code
)

select
    toUInt8(branch_key)                                     as branch_key,
    month_start                                             as month_start,
    toLowCardinality(source_system)                         as source_system,
    toUInt16(pl_line_key)                                   as pl_line_key,
    toLowCardinality(pl_line_code)                          as pl_line_code,
    report_amount                                           as report_amount,
    posted_amount                                           as posted_amount,
    report_amount - posted_amount                           as unposted_amount,
    moved_accounts_amount                                   as moved_accounts_amount,
    concat(
        if(source_system = 'oasis', 'Oasis month: compare with the Oasis trial balance',
           if(abs(report_amount - posted_amount) >= 0.005, 'Fusion: includes unposted', 'Fusion')),
        if(abs(moved_accounts_amount) >= 0.005, '; moved', '')
    )                                                       as note
from summed
{{ hnh_settings() }}
