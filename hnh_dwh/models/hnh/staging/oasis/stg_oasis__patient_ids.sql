select
    toUInt8(branch_id)              as branch_id,
    toInt64(patient_id_seq)         as patient_id_seq,
    {{ hnh_id('patient_id') }}      as patient_id,
    {{ hnh_id('id_type_code') }}    as id_type_code,
    {{ hnh_str('id_number') }}      as id_number
from {{ hnh_oasis_source('patient_ids') }} final
