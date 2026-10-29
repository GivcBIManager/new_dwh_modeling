{{ config(order_by='(branch_key, month_start)') }}

-- Credit-patient AR collections and the credit AR balance per hospital and month: KPI 7, Net Collection Rate =
-- collected in the period / credit AR closing balance at its end. Each branch-month takes one source, as fact_gl_fs_monthly does (map_gl_cutover):
-- - before the branch's first Fusion GL month, the Oasis AR sub-ledger receipts of insurers, contracts and other
--   non-patient accounts. The Oasis GL posts AR in consolidated batches that mix receipts with credit notes, so its
--   documents are read instead;
-- - from that month, the Fusion Receivables receipts on the trade receivables accounts, credits net of debits. The
--   unapplied and unidentified receipts controls are trade receivables accounts, so a receipt counts once whether or
--   not it has been applied to an invoice.
-- Cash patients are left out: patient receipts (hnh_is_patient_receipt) and the cash-patient AR accounts (Oasis
-- 11200007 Account Receivables Inpatient Cash, Fusion 11303101 Claimed (Trade) A/R - Cash). The AR balance is the net
-- trade receivables of fact_gl_fs_monthly (as KPI 6, Days in AR) without those accounts. Amounts are positive for money
-- collected and for a debit (receivable) balance. Branches 1-8.

{% set cash_ar_accounts = "('11200007', '11303101')" %}
{% set journal_month = 'makeDate(intDiv(assumeNotNull(j.accounting_date_key), 10000), intDiv(assumeNotNull(j.accounting_date_key), 100) % 100, 1)' %}
{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}

with cutover as (
    select branch_id, first_fusion_gl_month_start
    from {{ ref('stg_ref__gl_cutover') }}
),

oasis_receipts as (
    select
        r.branch_id                   as branch_key,
        toStartOfMonth(r.doc_at)      as month_start,
        sum(-r.total_doc_price)       as collected
    from {{ ref('stg_oasis__ar_documents') }} as r
    left join cutover as c on c.branch_id = r.branch_id
    where r.doc_type = 'RECEIPT'
      and {{ hnh_is_patient_receipt('r.account_code', 'r.ext_ref') }} = 0
      and r.branch_id between 1 and 8
      and r.doc_at >= {{ first_at }}
      and (c.first_fusion_gl_month_start is null or toStartOfMonth(r.doc_at) < c.first_fusion_gl_month_start)
    group by branch_key, month_start
),

fusion_receipts as (
    select
        j.branch_key                                                                 as branch_key,
        {{ journal_month }}                                                          as month_start,
        sum(j.credit - j.debit)                                                      as collected
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = j.gl_account_key
    inner join {{ ref('dim_fs_line') }} as d on d.fs_line_key = a.fs_line_key
    inner join cutover as c on c.branch_id = j.branch_key
    where j.je_source = 'Receivables' and j.je_category = 'Receipts'
      and lower(d.fs_caption) = 'trade receivables, net' and lower(d.fs_line) = 'trade receivables'
      and toString(a.natural_account) not in {{ cash_ar_accounts }}
      and j.branch_key between 1 and 8
      and j.accounting_date_key is not null
      and {{ journal_month }} >= c.first_fusion_gl_month_start
    group by branch_key, month_start
),

balances as (
    select
        branch_key,
        month_start,
        any(source_system)                               as source_system,
        sum(opening_balance + opening_journal_amount)    as ar_opening,
        sum(closing_balance)                             as ar_closing
    from {{ ref('fact_gl_fs_monthly') }}
    where lower(fs_caption) = 'trade receivables, net'
      and account_code not in {{ cash_ar_accounts }}
    group by branch_key, month_start
),

receipts as (
    select branch_key, month_start, 'oasis' as source_system, collected from oasis_receipts
    union all
    select branch_key, month_start, 'fusion' as source_system, collected from fusion_receipts
),

keys as (
    select branch_key, month_start, source_system from balances
    union distinct
    select branch_key, month_start, source_system from receipts
)

select
    toUInt8(k.branch_key)                         as branch_key,
    k.month_start                                 as month_start,
    toLowCardinality(k.source_system)             as source_system,
    ifNull(r.collected, 0)                        as collected_amount,
    ifNull(b.ar_opening, 0)                       as credit_ar_opening,
    ifNull(b.ar_closing, 0)                       as credit_ar_closing,
    now()                                         as _loaded_at
from keys as k
left join receipts as r
    on r.branch_key = k.branch_key and r.month_start = k.month_start and r.source_system = k.source_system
left join balances as b
    on b.branch_key = k.branch_key and b.month_start = k.month_start and b.source_system = k.source_system
{{ hnh_settings() }}
