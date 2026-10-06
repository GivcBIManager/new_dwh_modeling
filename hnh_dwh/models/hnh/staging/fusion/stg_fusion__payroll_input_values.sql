select input_value_id, element_type_id, {{ hnh_str('input_value_base_name') }} as input_value_base_name, {{ hnh_code('uom') }} as uom
from {{ hnh_fusion_source('dim_payroll_input_value') }} final
where ifNull(is_current, '') = 'Y'
