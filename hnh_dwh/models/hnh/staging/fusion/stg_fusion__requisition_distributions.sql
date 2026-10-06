select
    distribution_id,
    requisition_header_id,
    {{ hnh_str('requisition_number') }}     as requisition_number,
    toDate32(approved_date)                 as approved_date
from {{ hnh_fusion_source('fact_requisition_distribution') }} final
