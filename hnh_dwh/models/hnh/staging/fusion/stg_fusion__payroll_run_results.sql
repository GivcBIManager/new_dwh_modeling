select
    run_result_id,
    input_value_id,
    element_type_id,
    person_id,
    legal_employer_id,
    {{ hnh_code('payroll_action_status') }}     as payroll_action_status,
    toDate32(payroll_effective_date)            as effective_date,
    toFloat64OrNull(trimBoth(ifNull(result_value, ''))) as result_value
from {{ hnh_fusion_source('fact_payroll_run_result') }} final
