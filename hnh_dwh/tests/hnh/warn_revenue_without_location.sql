{{ config(severity='warn') }}
-- Revenue lines without a service location (care type Unallocated), opening-balance journals excluded.
select j.branch_key as branch_key, j.period_key as period_key, count() as lines, round(-sum(j.amount), 2) as revenue
from {{ ref('hnh_fact_gl_journal_line') }} as j
inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = j.gl_account_key
inner join {{ ref('dim_fs_line') }} as f on f.fs_line_key = a.fs_line_key
where f.statement_group = 'Revenue' and a.revenue_care_type = 'Unallocated' and j.is_opening_balance_journal = 0
group by j.branch_key, j.period_key
