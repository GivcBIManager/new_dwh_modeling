-- Finance facts never fall back to the Group member (branch 0).
select 'fact_gl_journal_line' as fact, count() as rows_without_branch from {{ ref('hnh_fact_gl_journal_line') }} where branch_key = 0 having count() > 0
union all
select 'fact_gl_balance_monthly', count() from {{ ref('fact_gl_balance_monthly') }} where branch_key = 0 having count() > 0
union all
select 'fact_ap_invoice_line', count() from {{ ref('fact_ap_invoice_line') }} where branch_key = 0 having count() > 0
union all
select 'fact_ap_payment', count() from {{ ref('hnh_fact_ap_payment') }} where branch_key = 0 having count() > 0
union all
select 'fact_ap_open_item', count() from {{ ref('fact_ap_open_item') }} where branch_key = 0 having count() > 0
