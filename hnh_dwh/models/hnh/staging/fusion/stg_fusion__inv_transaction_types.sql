select
    transaction_type_id,
    {{ hnh_str('transaction_type_name') }}  as transaction_type_name,
    transaction_action_id,
    {{ hnh_str('transaction_source_type_name') }} as transaction_source_type_name
from {{ hnh_fusion_source('dim_inv_transaction_type') }} final
