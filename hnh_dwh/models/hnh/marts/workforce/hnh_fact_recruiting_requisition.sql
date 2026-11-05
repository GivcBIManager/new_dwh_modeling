{{ config(alias='fact_recruiting_requisition', order_by='requisition_id') }}

-- Oracle Recruiting requisitions (bsc ssas spec 6.2, KPIs 47 and 48; HR dashboard): approved, not deleted, with a
-- department of a hospital (branches 1-8) or of Head Office (100; ruling R32, 2026-11-03: the HR report covers Head
-- Office). The scorecard keeps hospitals only: BSC Actual and the scorecard payload measures read this fact under
-- Branch[Is Hospital] = "Yes", and bsc.vw_work_force reads the staging model with its own branch filter. The
-- standalone measures BSC Time to Fill (days), BSC Vacancy Rate and Open Openings have no branch filter, so used on
-- their own at network level they include Head Office. days_to_fill is approval to fill, NULL
-- when not filled or when the fill is before the approval. Only some branches use Oracle Recruiting (mostly Abha and
-- Head Office). requisition_phase and requisition_state: the current Oracle Recruiting phase and state (HR report
-- status filter).
select
    q.requisition_id                                                        as requisition_id,
    d.branch_key                                                            as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(q.approved_date)))                     as approved_date_key,
    if(q.filled_date is null, null, toInt32(toYYYYMMDD(assumeNotNull(q.filled_date)))) as filled_date_key,
    q.number_to_hire                                                        as number_to_hire,
    if(q.filled_date is null or q.filled_date < q.approved_date, null,
       toInt32(dateDiff('day', assumeNotNull(q.approved_date), assumeNotNull(q.filled_date)))) as days_to_fill,
    ifNull({{ hnh_title('q.phase_name') }}, 'Unknown')                    as requisition_phase,
    ifNull({{ hnh_title('q.state_name') }}, 'Unknown')                    as requisition_state
from {{ ref('stg_fusion__recruiting_requisitions') }} as q
inner join {{ ref('hnh_dim_hr_department') }} as d on d.organization_id = q.department_id
where q.is_deleted = 0 and q.approved_date is not null and (d.branch_key between 1 and 8 or d.branch_key = 100)
