-- Branch columns for the role-playing copy From Branch: the branch a worker movement left (previous_branch_key; HR
-- report transfers matrix, user request 2026-11-05). No row filter applies to the copy; the movements are secured
-- through their own branch (Branch).
select
    toInt64(branch_key) as branch_key,
    branch_name
from {{ ref('hnh_dim_branch') }}
