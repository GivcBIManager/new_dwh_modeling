{{ config(severity='warn') }}
-- About 98% of outpatient and 100% of inpatient and ER charges resolve to an encounter (spec R18).
select branch_key, care_type_key, count() as live_rows, countIf(encounter_key = -1) as unresolved,
       round(unresolved / live_rows, 4) as unresolved_share
from {{ ref('fact_charge_line') }}
where charge_status = 'Live' and delivery_date_key >= toInt32(toYYYYMMDD(today() - 90))
  and delivery_date_key < toInt32(toYYYYMMDD(today()))
group by branch_key, care_type_key
having unresolved_share > 0.02
