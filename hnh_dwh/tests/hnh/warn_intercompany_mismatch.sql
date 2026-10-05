{{ config(severity='warn') }}
-- Branch pairs whose intercompany amounts do not offset (lines of A naming B plus lines of B naming A).
with pairs as (
    select branch_key as from_branch, assumeNotNull(intercompany_branch_key) as to_branch, sum(amount) as net
    from {{ ref('hnh_fact_gl_journal_line') }}
    where intercompany_branch_key is not null and intercompany_branch_key != branch_key
    group by from_branch, to_branch
)
select a.from_branch, a.to_branch, round(a.net, 2) as net_from, round(ifNull(b.net, 0), 2) as net_back,
       round(a.net + ifNull(b.net, 0), 2) as mismatch
from pairs as a
left join pairs as b on b.from_branch = a.to_branch and b.to_branch = a.from_branch
where a.from_branch < a.to_branch and abs(a.net + ifNull(b.net, 0)) > 1
{{ hnh_settings() }}
