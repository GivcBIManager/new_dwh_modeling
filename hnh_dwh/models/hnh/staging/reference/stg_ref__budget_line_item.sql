-- Names and categories of the budget file's line items, as the old server's bsc.vw_income_statement_budget showed them.
select
    toString(code)      as code,
    toString(name)      as name,
    toString(category)  as category
from {{ source('reference', 'map_budget_line_item') }}
