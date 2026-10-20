-- fact_bsc_workforce_monthly summed per branch-month equals bsc.vw_work_force (bsc ssas spec 6.2): headcount,
-- part-time doctors, FTE, resignations, Saudi, doctor and medical heads, for every month of the view's window.
with f as (
    select branch_key, toStartOfMonth(toDate(toString(month_date_key))) as period,
           sum(headcount) as hc, sumIf(headcount, row_type = 'pt_doctor') as pt, sum(fte) as fte,
           sum(resignations) as rs, sum(is_saudi * headcount) as sa,
           sumIf(headcount, is_doctor = 1) as dc, sumIf(headcount, is_medical = 1) as md
    from {{ ref('fact_bsc_workforce_monthly') }}
    group by branch_key, period
)
select v.branch_id, v.period, v.headcount, f.hc, v.pt_doctors_headcount, f.pt, v.FTE, f.fte,
       v.resignations, f.rs, v.saudi_headcount, f.sa, v.doctors_headcount, f.dc, v.medical_headcount, f.md
from {{ ref('bsc_vw_work_force') }} as v
left join f on f.branch_key = v.branch_id and f.period = v.period
where v.headcount != f.hc or v.pt_doctors_headcount != f.pt or abs(v.FTE - f.fte) > 0.001 or v.resignations != f.rs
   or v.saudi_headcount != f.sa or v.doctors_headcount != f.dc or v.medical_headcount != f.md
settings join_use_nulls = 0
