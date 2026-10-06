select
    assign_work_measure_id,
    assignment_id,
    {{ hnh_code('unit') }}                          as unit,
    toFloat64(ifNull(work_measure_value, 0))        as value,
    toDate32(effective_start_date)                  as effective_start_date,
    toDate32(ifNull(effective_end_date, toDateTime64('2299-12-31 00:00:00', 6, 'UTC'))) as effective_end_date
from {{ hnh_fusion_source('fact_assignment_work_measure') }} final
