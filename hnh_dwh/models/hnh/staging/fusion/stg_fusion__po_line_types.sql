select line_type_id, {{ hnh_str('line_type_name') }} as line_type_name
from {{ hnh_fusion_source('dim_po_line_type') }} final
