{{ config(severity='warn') }}
-- Branches that have activity but no target rows for the current year.
select b.branch_key, b.branch_name
from {{ ref('hnh_dim_branch') }} as b
left join (
    select distinct branch_key
    from {{ ref('fact_target_daily') }}
    where intDiv(date_key, 10000) = toYear(today())
) as t on t.branch_key = b.branch_key
where b.branch_key between 1 and 8 and t.branch_key is null
{{ hnh_settings() }}
