-- Press Ganey services (spec 5.1).
select
    upper(trimBoth(service_code))                       as service_code,
    service_desc                                        as service_desc,
    toString(care_setting)                              as care_setting,
    toUInt8(is_enabled)                                 as is_enabled
from {{ source('press_ganey', 'dim_pg_service') }} final
