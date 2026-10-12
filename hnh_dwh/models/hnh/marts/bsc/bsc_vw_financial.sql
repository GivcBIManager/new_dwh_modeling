{{ config(alias='vw_financial') }}

-- Old bsc.vw_financial (bsc spec 6.3). Actuals from fact_gl_fs_monthly (Oasis or Fusion per branch-month) with FS
-- value lists that hold in both vocabularies: Oasis keeps depreciation under direct cost and books medicines as
-- cost of goods sold; Fusion has a depreciation category and cost of medicines. EBITDA = net revenue - operating
-- expenses, as before. Budget: fact_income_statement_monthly, most likely; NULL when the branch-month has none.
-- Months from January two years back; budget-only months are kept.
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_,
    makeDate(toYear(today_ - 1) - 2, 1, 1) as from_month_,
actual as (
    select
        branch_key,
        month_start,
        -sumIf(movement, fs_element = 'revenue')                                                     as net_rev,
        -sumIf(movement, fs_element = 'revenue' and fs_caption != 'revenue - settlement discount')   as sub_rev,
        sumIf(movement, fs_element = 'expenses'
                        and fs_category not in ('finance cost', 'zakat', 'depreciation and amortization')
                        and fs_caption not in ('depreciation', 'depreciation on rou', 'amortization of intangible assets',
                                               'depreciation expense', 'amortization expense'))      as opex,
        sumIf(movement, fs_category = 'general and administrative expenses')                         as ga,
        sumIf(movement, fs_caption in ('medical consumables', 'cost of medicines', 'cost of goods sold')) as consumables,
        -sumIf(movement, fs_type = 'is')                                                             as income,
        sumIf(closing_balance, fs_caption = 'trade receivables, net')                                as ar_close,
        sumIf(opening_balance + opening_journal_amount, fs_caption = 'trade receivables, net')       as ar_open,
        sumIf(closing_balance, fs_element = 'assets')                                                as assets_close,
        sumIf(opening_balance + opening_journal_amount, fs_element = 'assets')                       as assets_open
    from {{ ref('fact_gl_fs_monthly') }}
    where month_start >= from_month_
    group by branch_key, month_start
),
budget as (
    select
        branch_key,
        month_start,
        sumIf(budget_most_likely, budget_line_code = 'REV_NET')                                      as net_rev_b,
        sumIf(budget_most_likely, budget_line_code = 'REV_SUB')                                      as sub_rev_b,
        sumIf(budget_most_likely, budget_line_code in ('TOTAL_DC', 'TOTAL_GA'))                      as opex_b,
        sumIf(budget_most_likely, budget_line_code = 'EBITDA')                                       as ebitda_b,
        sumIf(budget_most_likely, budget_line_code = 'TOTAL_GA')
            - sumIf(budget_most_likely, budget_line_code = 'GA_MARKETING')                           as ga_b,
        sumIf(budget_most_likely, budget_line_code in ('DC_MEDICINES', 'DC_CONSUMABLES'))            as consumables_b
    from {{ ref('fact_income_statement_monthly') }}
    where branch_key between 1 and 8 and month_start >= from_month_
    group by branch_key, month_start
    having countIf(budget_most_likely != 0) > 0
),
keys as (
    select branch_key, month_start from actual
    union distinct
    select branch_key, month_start from budget
)
select
    toUInt64(k.branch_key)                                                 as branch_id,
    toNullable(toDate32(k.month_start))                                    as month_date,
    CAST(round(ifNull(a.net_rev, 0), 2) AS Decimal(38, 10))                as net_revenue_actual,
    CAST(round(ifNull(a.sub_rev, 0), 2) AS Decimal(38, 10))                as sub_revenue_actual,
    CAST(round(ifNull(a.opex, 0), 2) AS Decimal(38, 10))                   as operating_expenses,
    CAST(round(ifNull(a.net_rev, 0) - ifNull(a.opex, 0), 2) AS Decimal(38, 10)) as ebitda_actual,
    CAST(round(ifNull(a.ar_close, 0), 2) AS Decimal(38, 10))               as account_receivable_actual,
    CAST(round(ifNull(a.ar_open, 0), 2) AS Decimal(38, 10))                as account_receivable_actual_opening_balance,
    CAST(round(ifNull(a.ga, 0), 2) AS Decimal(38, 10))                     as ga_expenses_actual,
    CAST(round(ifNull(a.consumables, 0), 2) AS Decimal(38, 10))            as consumables_actual,
    CAST(round(ifNull(a.assets_close, 0), 2) AS Decimal(38, 10))           as assets,
    CAST(round(ifNull(a.assets_open, 0), 2) AS Decimal(38, 10))            as assets_opening_balance,
    CAST(round(ifNull(a.income, 0), 2) AS Decimal(38, 10))                 as income,
    CAST(round(b.net_rev_b, 2) AS Nullable(Decimal(38, 2)))                as net_revenue_budget,
    CAST(round(b.sub_rev_b, 2) AS Nullable(Decimal(38, 2)))                as sub_revenue_budget,
    CAST(round(b.opex_b, 2) AS Nullable(Decimal(38, 2)))                   as operating_expenses_budget,
    CAST(round(b.ebitda_b, 2) AS Nullable(Decimal(38, 2)))                 as ebitda_budget,
    CAST(round(b.ga_b, 2) AS Nullable(Decimal(38, 2)))                     as ga_expenses_budget,
    CAST(round(b.consumables_b, 2) AS Nullable(Decimal(38, 2)))            as consumables_budget
from keys as k
left join actual as a on a.branch_key = k.branch_key and a.month_start = k.month_start
left join budget as b on b.branch_key = k.branch_key and b.month_start = k.month_start
settings join_use_nulls = 1
