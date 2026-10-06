-- The primary assignment valid at each month-end of the snapshot window, one per person. Ties (two primary
-- assignments): ACTIVE before SUSPENDED before other statuses, then the latest valid_from, then the highest id.
with months as ({{ hnh_hr_month_ends() }}),

candidates as (
    select a.person_id as person_id, m.month_end as month_end, a.assignment_id as assignment_id,
           a.valid_from as valid_from, a.assignment_type as assignment_type, a.assignment_status as assignment_status,
           a.organization_id as organization_id, a.job_id as job_id, a.position_id as position_id,
           a.grade_id as grade_id, a.location_id as location_id, a.legal_employer_id as legal_employer_id
    from {{ ref('stg_fusion__assignments') }} as a
    cross join months as m
    where a.is_primary = 1 and a.person_id is not null
      and a.valid_from <= m.month_end and a.valid_to >= m.month_end
),

picked as (
    select *
    from candidates
    order by person_id, month_end,
             multiIf(ifNull(assignment_status, '') = 'ACTIVE', 1, ifNull(assignment_status, '') = 'SUSPENDED', 2, 3),
             valid_from desc, assignment_id desc
    limit 1 by person_id, month_end
),

fte_at_month_end as (
    select p.assignment_id as assignment_id, p.month_end as month_end, argMax(w.value, w.effective_start_date) as fte_value
    from picked as p
    inner join (select assignment_id, value, effective_start_date, effective_end_date
                from {{ ref('stg_fusion__work_measures') }} where unit = 'FTE') as w
        on w.assignment_id = p.assignment_id
    where w.effective_start_date <= p.month_end and w.effective_end_date >= p.month_end
    group by p.assignment_id, p.month_end
)

select
    assumeNotNull(p.person_id)              as person_id,
    p.month_end                             as month_end,
    p.assignment_id                         as assignment_id,
    p.assignment_type                       as assignment_type,
    p.assignment_status                     as assignment_status,
    p.organization_id                       as organization_id,
    p.job_id                                as job_id,
    p.position_id                           as position_id,
    p.grade_id                              as grade_id,
    p.location_id                           as location_id,
    p.legal_employer_id                     as legal_employer_id,
    ifNull(b.branch_key, toUInt8(0))        as branch_key,
    {{ hnh_fte('f.fte_value') }}            as fte
from picked as p
left join fte_at_month_end as f on f.assignment_id = p.assignment_id and f.month_end = p.month_end
left join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = p.legal_employer_id
{{ hnh_settings() }}
