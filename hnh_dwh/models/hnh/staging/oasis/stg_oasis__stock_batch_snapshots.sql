-- Daily stock by batch from 2026-08-20 (spec F10). A date loaded twice keeps its latest version. quantity is
-- qty_outstanding, the batch's on-hand quantity in base units (cnt is a row count, not a quantity).
with latest as (
    select branch_id, version_date, max(version) as latest_version
    from {{ hnh_oasis_source('docl_by_serial') }} final
    where version_date is not null and version is not null
    group by branch_id, version_date
)

select
    toUInt8(s.branch_id)                    as branch_id,
    assumeNotNull(s.version_date)           as snapshot_date,
    toInt64(s.c_id)                         as store_id,
    trimBoth(s.product_code)                as product_code,
    {{ hnh_str('s.serial_no_1') }}          as batch_number,
    toDate32(s.adj_date)                    as expiry_date,
    toFloat64(s.qty_outstanding)            as quantity
from {{ hnh_oasis_source('docl_by_serial') }} as s final
inner join latest as l
    on l.branch_id = s.branch_id and l.version_date = s.version_date and l.latest_version = s.version
