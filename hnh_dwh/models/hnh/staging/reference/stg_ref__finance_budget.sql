-- Finance budget overrides per hospital, month and statement line (finance report design). default.map_finance_budget is an insert-only
-- change log: the latest row per key wins and a latest row with is_deleted = 1 removes the key. statement is IS (income statement, line_code a
-- pl_line_code) or BS (balance sheet, line_code a lower-case FS caption). amount is entered positive; the marts apply the line's sign.
select
    branch_id,
    year,
    month,
    statement,
    line_code,
    latest.1 as amount,
    latest.3 as last_changed_at
from (
    select branch_id,
           year,
           month,
           upper(trimBoth(statement)) as statement,
           trimBoth(line_code) as line_code,
           argMax(tuple(amount, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_finance_budget') }}
    group by branch_id, year, month, statement, line_code
)
where latest.2 = 0
