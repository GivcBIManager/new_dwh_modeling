-- Oracle Recruiting requisitions for bsc.vw_work_force (open requisitions, vacant and filled positions, time to
-- fill; decision of 2026-10-13). Dates are stored in UTC and taken as KSA dates. A requisition without approval is
-- not yet a vacancy; deleted requisitions are flagged. Phase and state: the requisition's current phase and state
-- names in Oracle Recruiting (Open / Posted, Job formatting / In Progress, Open / Filled; HR report status filter).
select
    q.requisition_id                                          as requisition_id,
    q.department_id                                           as department_id,
    toUInt8(ifNull(q.object_status, '') = 'ORA_DELETED')      as is_deleted,
    toDate(q.approved_date, 'Asia/Riyadh')                    as approved_date,
    toDate(q.filled_date, 'Asia/Riyadh')                      as filled_date,
    toUInt32(ifNull(q.number_to_hire, 1))                     as number_to_hire,
    p.phase_name                                              as phase_name,
    s.state_name                                              as state_name
from {{ hnh_fusion_source('fact_recruiting_requisition') }} as q final
left join (select phase_id, phase_name from {{ hnh_fusion_source('dim_recruiting_phase') }} final) as p on p.phase_id = q.current_phase_id
left join (select state_id, state_name from {{ hnh_fusion_source('dim_recruiting_state') }} final) as s on s.state_id = q.current_state_id
{{ hnh_settings() }}
