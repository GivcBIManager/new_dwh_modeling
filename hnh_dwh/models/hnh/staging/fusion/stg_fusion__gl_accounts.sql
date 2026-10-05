select
    code_combination_id,
    segment1                                as branch_segment,
    toUInt32OrNull(toString(segment2))      as natural_account,
    {{ hnh_str('segment3') }}               as specialty_code,
    {{ hnh_str('segment4') }}               as service_location_code,
    {{ hnh_str('segment5') }}               as service_group_code,
    {{ hnh_str('segment6') }}               as intercompany_segment,
    {{ hnh_code('account_type') }}          as account_type,
    {{ hnh_flag('enabled_flag') }}          as is_enabled,
    {{ hnh_flag('summary_flag') }}          as is_summary
from {{ hnh_fusion_source('dim_gl_account') }} final
