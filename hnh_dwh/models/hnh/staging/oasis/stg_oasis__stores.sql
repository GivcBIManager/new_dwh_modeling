-- Oasis store master (control contexts). The name is the description, else the control context, else the heading.
select
    toUInt8(branch_id)                      as branch_id,
    toInt64(c_id)                           as store_id,
    coalesce(nullIf({{ hnh_str('description') }}, '0'), nullIf({{ hnh_str('control_context') }}, '0'),
             nullIf({{ hnh_str('heading') }}, '0'), concat('Store ', toString(toInt64(c_id)))) as store_name
from {{ hnh_oasis_source('control_contexts_data') }} final
