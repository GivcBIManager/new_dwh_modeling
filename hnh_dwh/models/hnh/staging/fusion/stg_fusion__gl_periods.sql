select
    period_name,
    period_year,
    period_num,
    quarter_num,
    toDate(start_date)                          as start_date,
    toDate(end_date)                            as end_date,
    {{ hnh_flag('adjustment_period_flag') }}    as is_adjustment
from {{ hnh_fusion_source('dim_gl_period') }} final
