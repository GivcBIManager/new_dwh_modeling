{{ config(alias='vw_gl_transactions') }}

-- Old bsc.vw_gl_transactions (bsc spec 6.2): the month's movement (debit positive, so revenue is negative as before)
-- and the opening balance including brought-forward / go-live journals, from January two years back.
with ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_
select
    toUInt64(branch_key)                                                          as BranchId,
    toNullable(toDate32(month_start))                                             as Period,
    toLowCardinality(upper(fs_type))                                              as AccountType,
    toLowCardinality(fs_element)                                                  as FS_ELEMENT,
    toLowCardinality(fs_category)                                                 as FS_CATEGORY,
    toLowCardinality(fs_caption)                                                  as FS_CAPTION,
    toLowCardinality(fs_line)                                                     as FS_LINE,
    CAST(round(toDecimal128(sum(movement), 4), 2) AS Decimal(38, 10))                              as Transaction_Balance,
    CAST(round(toDecimal128(sum(opening_balance + opening_journal_amount), 4), 2) AS Decimal(38, 10)) as OpeningBalance
from {{ ref('fact_gl_fs_monthly') }}
where toYear(month_start) >= toYear(today_ - 1) - 2
  and month_start <= toStartOfMonth(today_)    -- Fusion periods not yet started stay out
group by BranchId, Period, AccountType, FS_ELEMENT, FS_CATEGORY, FS_CAPTION, FS_LINE
