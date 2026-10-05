-- One fact row per staged order line whose order time (own, else header) falls in the window.
select 'fact_order_line row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_order_line') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__order_lines') }} as l
    left join (select branch_id, master_order_no, ordered_at from {{ ref('stg_oasis__orders') }}) as o
        on o.branch_id = l.branch_id and o.master_order_no = l.master_order_no
    where coalesce(l.line_ordered_at, o.ordered_at) >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(coalesce(l.line_ordered_at, o.ordered_at)) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
    settings join_use_nulls = 1
) as s
where f.n != s.n
