-- Oracle Recruiting requisitions for bsc.vw_work_force (open requisitions, vacant and filled positions, time to
-- fill; decision of 2026-10-13). Dates are stored in UTC and taken as KSA dates. A requisition without approval is
-- not yet a vacancy; deleted requisitions are flagged.
select
    requisition_id,
    department_id,
    toUInt8(ifNull(object_status, '') = 'ORA_DELETED')        as is_deleted,
    toDate(approved_date, 'Asia/Riyadh')                      as approved_date,
    toDate(filled_date, 'Asia/Riyadh')                        as filled_date,
    toUInt32(ifNull(number_to_hire, 1))                       as number_to_hire
from {{ hnh_fusion_source('fact_recruiting_requisition') }} final
