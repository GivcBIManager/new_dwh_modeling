-- Every staged actual line reaches the fact once, with the same debits and credits, on a real branch and period.
select 'fact_gl_journal_line differs from staging' as failure
from (select count() as n, round(sum(debit), 2) as dr, round(sum(credit), 2) as cr,
             countIf(branch_key = 0) as no_branch, countIf(period_key = 0) as no_period
      from {{ ref('hnh_fact_gl_journal_line') }}) as f
cross join (select count() as n, round(sum(debit), 2) as dr, round(sum(credit), 2) as cr
            from {{ ref('stg_fusion__gl_journal_lines') }} where actual_flag = 'A') as s
where f.n != s.n or abs(f.dr - s.dr) > 0.01 or abs(f.cr - s.cr) > 0.01 or f.no_branch > 0 or f.no_period > 0
