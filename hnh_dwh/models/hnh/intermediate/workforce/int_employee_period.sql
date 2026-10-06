-- The latest period of service of each person (by start date, then period id) with its legal employer's branch.
with latest as (
    select *
    from {{ ref('stg_fusion__periods_of_service') }}
    where person_id is not null
    order by person_id, start_date desc, period_of_service_id desc
    limit 1 by person_id
)

select
    assumeNotNull(l.person_id)              as person_id,
    l.period_of_service_id                  as period_of_service_id,
    l.worker_number                         as worker_number,
    l.start_date                            as start_date,
    l.original_hire_date                    as original_hire_date,
    l.termination_date                      as termination_date,
    l.is_terminated                         as is_terminated,
    l.legal_employer_id                     as legal_employer_id,
    ifNull(b.branch_key, toUInt8(0))        as branch_key
from latest as l
left join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = l.legal_employer_id
{{ hnh_settings() }}
