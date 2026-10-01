{{ config(order_by='procedure_type_key') }}

select toInt8(1) as procedure_type_key, 'Surgery' as procedure_type
union all select toInt8(2), 'Cesarean'
union all select toInt8(3), 'Cath Lab'
union all select toInt8(4), 'Endoscopy'
union all select toInt8(5), 'L&D'
union all select toInt8(-1), 'Unknown'
