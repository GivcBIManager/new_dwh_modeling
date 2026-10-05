select
    je_header_id,
    je_line_num,
    je_batch_id,
    {{ hnh_str('journal_name') }}           as journal_name,
    {{ hnh_str('doc_sequence_value') }}     as doc_sequence_value,
    ledger_id,
    code_combination_id,
    {{ hnh_str('period_name') }}            as period_name,
    toDate(accounting_date)                 as accounting_date,
    toDate(posted_date)                     as posted_date,
    {{ hnh_str('je_source') }}              as je_source,
    {{ hnh_str('je_category') }}            as je_category,
    {{ hnh_code('actual_flag') }}           as actual_flag,
    {{ hnh_code('header_status') }}         as header_status,
    toFloat64(ifNull(accounted_dr, 0))      as debit,
    toFloat64(ifNull(accounted_cr, 0))      as credit,
    {{ hnh_str('line_description') }}       as line_description
from {{ hnh_fusion_source('fact_gl_journal_line') }} final
