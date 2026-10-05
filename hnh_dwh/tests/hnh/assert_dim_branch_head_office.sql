-- Head Office is branch 100 on Fusion entity 101 and its ledger; it never replaces the Group row.
select 'head office member missing or wrong' as failure
where (select count() from {{ ref('hnh_dim_branch') }}
       where branch_key = 100 and branch_name = 'Head Office'
         and fusion_branch_code = {{ var('hnh_head_office_fusion_branch_code') }}
         and fusion_ledger_id = {{ var('hnh_head_office_ledger_id') }}) != 1
   or (select count() from {{ ref('hnh_dim_branch') }} where branch_key = 0) != 1
