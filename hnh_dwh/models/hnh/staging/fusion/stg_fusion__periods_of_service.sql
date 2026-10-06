select
    period_of_service_id,
    person_id,
    legal_employer_id,
    {{ hnh_code('worker_number') }}                         as worker_number,
    toDate32(start_date)                                    as start_date,
    toDate32OrNull(substring(ifNull(original_date_of_hire, ''), 1, 10)) as original_hire_date,
    toDate32(actual_termination_date)                       as termination_date,
    {{ hnh_flag('terminated_flag') }}                       as is_terminated
from {{ hnh_fusion_source('fact_period_of_service') }} final
