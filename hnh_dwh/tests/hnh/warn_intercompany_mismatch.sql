{{ config(severity='warn') }}
-- Branch pairs whose intercompany amounts do not offset: every unordered pair is evaluated once, summing the lines
-- of either branch that name the other (net_a_to_b: lines of the lower branch; net_b_to_a: lines of the higher one).
select least(branch_key, assumeNotNull(intercompany_branch_key)) as branch_a,
       greatest(branch_key, assumeNotNull(intercompany_branch_key)) as branch_b,
       round(sumIf(amount, branch_key = branch_a), 2) as net_a_to_b,
       round(sumIf(amount, branch_key = branch_b), 2) as net_b_to_a,
       round(sum(amount), 2) as mismatch
from {{ ref('hnh_fact_gl_journal_line') }}
where intercompany_branch_key is not null and intercompany_branch_key != branch_key
group by branch_a, branch_b
having abs(sum(amount)) > 1
