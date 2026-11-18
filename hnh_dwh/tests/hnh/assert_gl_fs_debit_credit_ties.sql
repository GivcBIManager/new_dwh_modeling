-- debit - credit equals the movement of the row (within 0.01), and neither side is negative.
select branch_key, month_start, source_system, account_code, debit, credit, movement
from {{ ref('fact_gl_fs_monthly') }}
where abs(debit - credit - movement) > 0.01
   or debit < 0 or credit < 0
