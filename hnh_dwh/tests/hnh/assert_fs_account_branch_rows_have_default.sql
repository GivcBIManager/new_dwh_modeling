-- A branch row in map_fs_account only overrides its account's row for all branches; an account without that row
-- would be Not mapped at every other branch.
select b.natural_account, b.branch_segment
from {{ ref('stg_ref__fs_account') }} as b
where b.branch_segment is not null
  and b.natural_account not in (select natural_account from {{ ref('stg_ref__fs_account') }} where branch_segment is null)
