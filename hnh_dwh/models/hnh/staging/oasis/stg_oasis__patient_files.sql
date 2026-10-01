select
    toUInt8(branch_id)                as branch_id,
    toInt64(pat_file_id)              as pat_file_id,
    {{ hnh_id('patient_id') }}        as patient_id,
    {{ hnh_str('user_file_id') }}     as user_file_id
from {{ source('oasis', 'patient_file_master') }} final
