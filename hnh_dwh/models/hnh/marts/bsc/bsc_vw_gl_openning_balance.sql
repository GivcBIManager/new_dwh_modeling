{{ config(alias='vw_gl_openning_balance') }}

-- Old bsc.vw_gl_openning_balance (bsc spec 6.1) on fact_gl_fs_monthly: opening balance and the month's
-- brought-forward (Oasis) or go-live (Fusion) journals per branch, month and FS level; one GL source per branch-month.
select
    toUInt64(branch_key)                                              as BranchId,
    toNullable(toDate32(month_start))                                 as Period,
    toLowCardinality(upper(fs_type))                                  as AccountType,
    toLowCardinality(fs_element)                                      as FS_ELEMENT,
    toLowCardinality(fs_category)                                     as FS_CATEGORY,
    toLowCardinality(fs_caption)                                      as FS_CAPTION,
    toLowCardinality(fs_line)                                         as FS_LINE,
    CAST(round(sum(opening_balance), 2) AS Decimal(38, 10))           as OpeningBalance,
    CAST(round(sum(opening_journal_amount), 2) AS Decimal(38, 10))    as forwarded_balance
from {{ ref('fact_gl_fs_monthly') }}
group by BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE
