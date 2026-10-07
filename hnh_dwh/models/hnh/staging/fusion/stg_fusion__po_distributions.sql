select
    po_distribution_id,
    line_location_id,
    req_distribution_id,
    destination_organization_id,
    toFloat64(ifNull(quantity_ordered, 0))  as quantity_ordered,
    toFloat64(ifNull(quantity_delivered, 0)) as quantity_delivered,
    toFloat64(ifNull(quantity_billed, 0))   as quantity_billed,
    toFloat64(ifNull(quantity_cancelled, 0)) as quantity_cancelled
from {{ hnh_fusion_source('fact_po_distribution') }} final
