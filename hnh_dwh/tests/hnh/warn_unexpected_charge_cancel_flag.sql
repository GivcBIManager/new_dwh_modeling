{{ config(severity='warn') }}

-- Charge rows in the history window with a cancel flag other than C or R. They are kept in
-- fact_charge_line with status Unknown and no revenue; their meaning needs confirming.
select branch_id, cancel_flag, count() as charge_rows, sum(price_paid_purchaser) as price_paid_purchaser
from {{ ref('stg_oasis__charges') }}
where delivered_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
  and toDate(delivered_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
  and cancel_flag not in ('C', 'R')
group by branch_id, cancel_flag
