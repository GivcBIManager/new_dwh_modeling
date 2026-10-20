{{ config(order_by='requisition_id') }}

-- Oracle Recruiting requisitions for the scorecard (bsc ssas spec 6.2, KPIs 47 and 48): approved, not deleted, with a
-- branch 1-8 department, as in bsc.vw_work_force. days_to_fill is approval to fill, NULL when not filled or when the
-- fill is before the approval. Only some branches use Oracle Recruiting (mostly Abha and Head Office).
select
    q.requisition_id                                                        as requisition_id,
    d.branch_key                                                            as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(q.approved_date)))                     as approved_date_key,
    if(q.filled_date is null, null, toInt32(toYYYYMMDD(assumeNotNull(q.filled_date)))) as filled_date_key,
    q.number_to_hire                                                        as number_to_hire,
    if(q.filled_date is null or q.filled_date < q.approved_date, null,
       toInt32(dateDiff('day', assumeNotNull(q.approved_date), assumeNotNull(q.filled_date)))) as days_to_fill
from {{ ref('stg_fusion__recruiting_requisitions') }} as q
inner join {{ ref('hnh_dim_hr_department') }} as d on d.organization_id = q.department_id
where q.is_deleted = 0 and q.approved_date is not null and d.branch_key between 1 and 8
