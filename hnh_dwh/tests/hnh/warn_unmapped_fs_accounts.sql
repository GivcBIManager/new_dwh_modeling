{{ config(severity='warn') }}
-- Posted accounts without an FS line (shown on a Not mapped line), by branch and natural account.
select j.branch_key as branch_key, a.natural_account as natural_account, any(a.natural_account_name) as account_name,
       count() as lines, round(sum(j.debit) + sum(j.credit), 2) as gross_value
from {{ ref('hnh_fact_gl_journal_line') }} as j
inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = j.gl_account_key
where a.fs_mapping_source = 'not mapped' and j.is_posted = 1
group by j.branch_key, a.natural_account
