select
    toUInt32(id)                    as id,
    toUInt8(branch_id)              as branch_id,
    toUInt16(fiscal_year)           as fiscal_year,
    toString(scenario)              as scenario,
    upper(toString(line_item_code)) as line_item_code,
    {% for m in range(1, 13) %}toFloat64(month_{{ m }}) as month_{{ m }},
    {% endfor %}toUInt8(is_latest)  as is_latest
from {{ source('reference', 'income_statement_budget') }}
