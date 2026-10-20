-- Scorecard objectives and their pillar (weight, question) (bsc ssas spec 6.2). default.map_bsc_objective is an insert-only change log: the latest row per key
-- wins and a latest row with is_deleted = 1 removes the key.
select
    objective_code,
    latest.1 as pillar,
    latest.2 as pillar_order,
    latest.3 as pillar_weight,
    latest.4 as pillar_question,
    latest.5 as objective_title,
    latest.6 as objective_question,
    latest.7 as objective_order,
    latest.9 as last_changed_at
from (
    select trimBoth(objective_code) as objective_code,
           argMax(tuple(trimBoth(pillar), pillar_order, pillar_weight, trimBoth(pillar_question), trimBoth(objective_title), trimBoth(objective_question), objective_order, is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_objective') }}
    group by objective_code
)
where latest.8 = 0
