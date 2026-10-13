{{ config(alias='vw_gl_openning_balance') }}

-- Old bsc.vw_gl_openning_balance (bsc spec 6.1) on fact_gl_fs_monthly: opening balance and the month's
-- brought-forward (Oasis) or go-live (Fusion) journals per branch, month and FS level; one GL source per branch-month.
with ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_
select
    toUInt64(branch_key)                                              as BranchId,
    toNullable(toDate32(month_start))                                 as Period,
    toLowCardinality(upper(fs_type))                                  as AccountType,
    toLowCardinality(fs_element)                                      as FS_ELEMENT,
    toLowCardinality(fs_category)                                     as FS_CATEGORY,
    toLowCardinality(fs_caption)                                      as FS_CAPTION,
    toLowCardinality(fs_line)                                         as FS_LINE,
    CAST(round(toDecimal128(sum(opening_balance), 4), 2) AS Decimal(38, 10))           as OpeningBalance,
    CAST(round(toDecimal128(sum(opening_journal_amount), 4), 2) AS Decimal(38, 10))    as forwarded_balance,
    toLowCardinality(toString(source_system))                                    as data_source   -- added 2026-10-13
from {{ ref('fact_gl_fs_monthly') }}
where month_start <= toStartOfMonth(today_)    -- Fusion periods not yet started stay out
group by BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE, data_source
