select
    toUInt8(branch_id)                          as branch_id,
    toInt64(response_id)                        as response_id,
    {{ hnh_id('api_trans_id') }}                as api_trans_id,
    {{ hnh_id('about_api_trans_id') }}          as about_api_trans_id,
    lower(trimBoth(ifNull(response_type, ''))) as response_type,
    {{ hnh_code('res_status') }}                as res_status,
    {{ hnh_code('status') }}                    as status,
    {{ hnh_ksa_wall_clock('creation_date') }}   as responded_at,
    ifNull(response_bundle, '{}')               as response_bundle
from {{ hnh_oasis_source('api_pull_response_details') }} final
where lower(trimBoth(ifNull(response_type, ''))) in
      ('claim-response', 'priorauth-response', 'advanced-authorization', 'payment-reconciliation')
