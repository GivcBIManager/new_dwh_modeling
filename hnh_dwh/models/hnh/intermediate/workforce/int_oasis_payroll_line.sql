{{ config(order_by='(branch_id, payroll_month, account_transaction_no)') }}

-- Oasis payroll lines kept for the payroll fact, closed (status C) and open (status P), by the latest-run rule of
-- Phase 4 spec 12.2. The ClickHouse copy keeps every payroll calculation as status P lines, also after the close; the
-- close writes the final run again as status C lines. Per branch, staff and payroll month:
--   calculation date = a date with a positive BASIC line in status P;
--   last full run    = the branch's latest date on which at least 20% of its staff with a positive BASIC were calculated or closed;
--   staff closed     = no calculation date, or a positive closed BASIC dated on or after the latest calculation date.
-- Closed lines are always kept. Open lines are kept when the staff is not closed and its latest calculation is on or after the
-- branch's last full run (else the staff is a leftover of a trial run), and only from the latest calculation date or from
-- dates that are not calculation dates (one-off entries: loans, bank charges, adjustments).

{% set first_month = "toInt32(toYYYYMM(toDate('" ~ var('hnh_history_start_date') ~ "')))" %}

with raw as (
    select branch_id, account_transaction_no, staff_id, ifNull(staff_id, '') as staff_join_id, payroll_month, trx_type,
           payable_type, status, amount, ifNull(transaction_date, toDate('1970-01-01')) as txn_date,
           toUInt8(trx_type = 'BASIC' and amount > 0) as is_basic
    from {{ ref('stg_oasis__payroll_transactions') }}
    where status in ('C', 'P') and payroll_month >= {{ first_month }} and payroll_month % 100 between 1 and 12
),

staff_runs as (
    select branch_id, staff_join_id, payroll_month,
           groupUniqArrayIf(txn_date, status = 'P' and is_basic = 1) as calc_dates,
           maxIf(txn_date, status = 'P' and is_basic = 1)            as last_calc_date,
           countIf(status = 'P' and is_basic = 1)                    as open_calc_lines,
           maxIf(txn_date, status = 'C' and is_basic = 1)            as last_close_date,
           countIf(status = 'C' and is_basic = 1)                    as closed_basic_lines
    from raw
    group by branch_id, staff_join_id, payroll_month
),

branch_runs as (
    select d.branch_id as branch_id, d.payroll_month as payroll_month, max(d.txn_date) as last_full_run_date
    from (select branch_id, payroll_month, txn_date, uniqExactIf(staff_id, is_basic = 1) as n_staff
          from raw group by branch_id, payroll_month, txn_date) as d
    inner join (select branch_id, payroll_month, uniqExactIf(staff_id, is_basic = 1) as n_staff
                from raw group by branch_id, payroll_month) as b
        on b.branch_id = d.branch_id and b.payroll_month = d.payroll_month
    where d.n_staff >= 0.2 * b.n_staff
    group by d.branch_id, d.payroll_month
)

select
    r.branch_id                                                         as branch_id,
    r.account_transaction_no                                            as account_transaction_no,
    r.staff_id                                                          as staff_id,
    r.payroll_month                                                     as payroll_month,
    r.trx_type                                                          as trx_type,
    r.payable_type                                                      as payable_type,
    r.amount                                                            as amount,
    r.txn_date                                                          as transaction_date,
    toUInt8(r.status = 'C')                                             as is_closed_payroll,
    if(r.status = 'P', toNullable(s.last_calc_date), cast(null as Nullable(Date))) as open_run_date
from raw as r
inner join staff_runs as s
    on s.branch_id = r.branch_id and s.staff_join_id = r.staff_join_id and s.payroll_month = r.payroll_month
left join branch_runs as br on br.branch_id = r.branch_id and br.payroll_month = r.payroll_month
where r.status = 'C'
   or (    s.open_calc_lines > 0
       and not (s.closed_basic_lines > 0 and s.last_close_date >= s.last_calc_date)
       and s.last_calc_date >= ifNull(br.last_full_run_date, toDate('1970-01-01'))
       and (r.txn_date = s.last_calc_date or not has(s.calc_dates, r.txn_date)))
{{ hnh_settings() }}
