select element_type_id, {{ hnh_str('element_name') }} as element_name, {{ hnh_str('classification_name') }} as classification_name
from {{ hnh_fusion_source('dim_payroll_element') }} final
where ifNull(is_current, '') = 'Y'
