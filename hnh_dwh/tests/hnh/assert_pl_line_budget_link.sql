-- Every P&L line that links to a budget line names a code that exists in dim_budget_line, with a non-zero sign; an
-- unlinked line has sign 0; every non-subtotal budget line (except the revenue split, the rejection split and
-- UNBUDGETED) is the budget line of exactly one P&L line. One row per problem.
select 'linked code is not a budget line' as problem, pl_line_code as detail
from {{ ref('dim_pl_report_line') }}
where budget_line_code != '' and budget_line_code not in (select budget_line_code from {{ ref('dim_budget_line') }})

union all

select 'sign does not match the link', pl_line_code
from {{ ref('dim_pl_report_line') }}
where (budget_line_code = '' and budget_sign != 0) or (budget_line_code != '' and budget_sign not in (-1, 1))

union all

select 'budget line is not linked exactly once', b.budget_line_code
from {{ ref('dim_budget_line') }} as b
where b.is_subtotal = 0
  and b.budget_line_code not in ('REV_OP', 'REV_IP', 'REV_ER', 'REV_UNALLOCATED', 'DIS_REJECTION_INS', 'DIS_REJECTION_MOH', 'UNBUDGETED')
  and (select count() from {{ ref('dim_pl_report_line') }} as l where l.budget_line_code = b.budget_line_code) != 1
