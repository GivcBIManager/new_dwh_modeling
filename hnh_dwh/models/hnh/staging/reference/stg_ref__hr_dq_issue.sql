-- HR data quality issue catalogue (HR dashboard design, data quality). default.map_hr_dq_issue is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    issue_code,
    latest.1 as issue_name,
    latest.2 as area,
    latest.3 as fix_in,
    latest.4 as owner,
    latest.5 as severity,
    latest.6 as how_to_fix,
    latest.7 as display_order,
    latest.8 as status,
    latest.10 as last_changed_at
from (
    select trimBoth(issue_code) as issue_code,
           argMax(tuple(trimBoth(issue_name), trimBoth(area), trimBoth(fix_in), trimBoth(owner), trimBoth(severity), trimBoth(how_to_fix), display_order, trimBoth(status), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_hr_dq_issue') }}
    group by issue_code
)
where latest.9 = 0
