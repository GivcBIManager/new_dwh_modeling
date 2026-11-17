-- Each branch-month of the P&L report takes its GL from one source: Oasis before the branch's first Fusion GL month,
-- Fusion from it, Head Office always Fusion.
select branch_key, month_start, arrayStringConcat(arraySort(groupUniqArray(toString(source_system))), ', ') as sources
from {{ ref('fact_pl_report_monthly') }}
group by branch_key, month_start
having uniqExact(source_system) > 1
