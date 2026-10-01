{{ config(order_by='admission_source_key') }}

select toInt8(1) as admission_source_key, 'OP' as admission_source
union all select toInt8(2), 'ER'
union all select toInt8(3), 'Direct'
union all select toInt8(-1), 'Unknown'
