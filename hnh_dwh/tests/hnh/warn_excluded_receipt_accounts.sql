{{ config(severity='warn') }}

-- Receipt documents in the history window left out of fact_cash_receipt because they are not
-- patient receipts (account CASHACC, none, or the patient's own account): insurer, contract and
-- other-account receipts (Phase 3, Fusion AR). Listed per branch and account prefix so the excluded
-- amount stays visible.
select branch_id,
       splitByChar('-', ifNull(account_code, ''))[1] as account_prefix,
       count()                                       as receipt_documents,
       sum(-total_doc_price)                         as receipt_amount
from {{ ref('stg_oasis__ar_documents') }}
where doc_type = 'RECEIPT'
  and doc_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
  and toDate(doc_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
  and {{ hnh_is_patient_receipt('account_code', 'ext_ref') }} = 0
group by branch_id, account_prefix
