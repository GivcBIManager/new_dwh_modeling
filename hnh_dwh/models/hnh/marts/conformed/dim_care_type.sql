{{ config(order_by='care_type_key') }}

select toInt8(1) as care_type_key, 'OP' as care_type, 'Outpatient' as care_type_name
union all select toInt8(2), 'ER', 'Emergency'
union all select toInt8(3), 'IP', 'Inpatient'
union all select toInt8(4), 'DAYCASE', 'Day case'
union all select toInt8(-1), 'Unknown', 'Unknown'
