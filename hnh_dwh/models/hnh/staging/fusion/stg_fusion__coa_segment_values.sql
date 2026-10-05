select
    {{ hnh_code('segment_column_name') }}       as segment_column_name,
    trimBoth(segment_value)                     as segment_value,
    {{ hnh_str('segment_value_description') }}  as segment_value_name
from {{ hnh_fusion_source('dim_coa_segment_value') }} final
