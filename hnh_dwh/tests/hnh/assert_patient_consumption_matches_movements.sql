-- The patient-consumption row count equals the patient sale and return rows of fact_stock_movement (spec 8).
select m.n as movement_rows, c.n as consumption_rows
from (select count() as n from {{ ref('fact_stock_movement') }} where movement_type in ('Patient sale', 'Patient return')) as m
cross join (select count() as n from {{ ref('fact_patient_consumption') }}) as c
where m.n != c.n
