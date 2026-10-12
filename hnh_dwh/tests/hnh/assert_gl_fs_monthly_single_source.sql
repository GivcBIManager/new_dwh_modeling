-- Each branch-month takes its GL from one source (bsc spec B5), and the grain is one row per branch, month, source
-- and account.
select 'two sources' as problem, branch_key, month_start, '' as account_code
from {{ ref('fact_gl_fs_monthly') }}
group by branch_key, month_start
having uniqExact(source_system) > 1
union all
select 'duplicate account row', branch_key, month_start, account_code
from {{ ref('fact_gl_fs_monthly') }}
group by branch_key, month_start, source_system, account_code
having count() > 1
