select
    ledger_id,
    code_combination_id,
    period_name,
    {{ hnh_code('actual_flag') }}               as actual_flag,
    {{ hnh_code('currency_balance_type') }}     as currency_balance_type,
    toFloat64(ifNull(accounted_dr, 0))          as period_debit,
    toFloat64(ifNull(accounted_cr, 0))          as period_credit,
    toFloat64(ifNull(accounted_begin_dr, 0))    as begin_debit,
    toFloat64(ifNull(accounted_begin_cr, 0))    as begin_credit
from {{ hnh_fusion_source('fact_gl_balance') }} final
