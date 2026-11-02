{{ config(order_by='hr_dq_issue_key') }}

-- HR data quality issue catalogue: the latest config rows of map_hr_dq_issue.
select
    toInt64(bitShiftRight(cityHash64(concat(i.issue_code, '|')), 1))  as hr_dq_issue_key,
    i.issue_code                                                      as issue_code,
    i.issue_name                                                      as issue_name,
    i.area                                                            as area,
    i.fix_in                                                          as fix_in,
    i.owner                                                           as owner,
    i.severity                                                        as severity,
    i.how_to_fix                                                      as how_to_fix,
    i.display_order                                                   as display_order,
    i.status                                                          as status,
    i.last_changed_at                                                 as last_changed_at
from {{ ref('stg_ref__hr_dq_issue') }} as i
{{ hnh_settings() }}
