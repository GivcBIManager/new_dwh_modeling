-- One row per key in every keyed bsc view (bsc spec 9.2).
select 'vw_customer' as view_name, concat(toString(branch_id), '|', toString(period)) as k
from {{ ref('bsc_vw_customer') }} group by k having count() > 1
union all
select 'vw_financial', concat(toString(branch_id), '|', toString(month_date))
from {{ ref('bsc_vw_financial') }} group by 2 having count() > 1
union all
select 'vw_hospital_beds_utilization', concat(toString(hospital_id), '|', toString(period))
from {{ ref('bsc_vw_hospital_beds_utilization') }} group by 2 having count() > 1
union all
select 'vw_rcm', concat(toString(hospital_id), '|', toString(period))
from {{ ref('bsc_vw_rcm') }} group by 2 having count() > 1
union all
select 'vw_work_force', concat(toString(branch_id), '|', toString(period))
from {{ ref('bsc_vw_work_force') }} group by 2 having count() > 1
union all
select 'vw_gl_transactions', concat(toString(BranchId), '|', toString(Period), '|', AccountType, '|', FS_ELEMENT, '|', FS_CATEGORY, '|', FS_CAPTION, '|', FS_LINE)
from {{ ref('bsc_vw_gl_transactions') }} group by 2 having count() > 1
union all
select 'vw_hospital', toString(Id)
from {{ ref('bsc_vw_hospital') }} group by 2 having count() > 1
union all
select 'vw_date_dim', toString(`Date`)
from {{ ref('bsc_vw_date_dim') }} group by 2 having count() > 1
