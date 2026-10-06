{% set null_s = "cast(null as Nullable(String))" %}
{% set null_i = "cast(null as Nullable(Int64))" %}
{% set null_f = "cast(null as Nullable(Float64))" %}

select 'oasis movement type wrong' as failure
where not ({{ hnh_oasis_movement_type("'INVOICEAR'", "'OASIS'", 'toUInt8(1)') }} = 'Patient sale'
       and {{ hnh_oasis_movement_type("'INVOICEAR'", "'SALES'", 'toUInt8(0)') }} = 'Patient sale'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'CRD'", 'toUInt8(0)') }} = 'Patient return'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'SALES'", 'toUInt8(1)') }} = 'Patient return'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'ENTT'", 'toUInt8(0)') }} = 'Department issue'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'ENTT'", 'toUInt8(1)') }} = 'Transfer out'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'ENTT'", 'toUInt8(1)') }} = 'Transfer in'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'GRN'", 'toUInt8(1)') }} = 'Goods receipt'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'RFN'", 'toUInt8(0)') }} = 'Return to supplier'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'CNT'", 'toUInt8(0)') }} = 'Count adjustment'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'CNT'", 'toUInt8(0)') }} = 'Count adjustment'
       and {{ hnh_oasis_movement_type("'STOCKISS'", "'BATCH'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_oasis_movement_type("'STOCKRCPT'", "'BATCH'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_oasis_movement_type(null_s, null_s, 'toUInt8(0)') }} = 'Write-off / misc')

union all
select 'oasis direction wrong'
where not ({{ hnh_oasis_direction("'STOCKRCPT'") }} = 1 and {{ hnh_oasis_direction("'STOCKISS'") }} = -1
       and {{ hnh_oasis_direction("'INVOICEAR'") }} = -1 and {{ hnh_oasis_direction(null_s) }} = -1)

union all
select 'opening balance wrong'
where not ({{ hnh_is_opening_balance('toInt64(42)', "'OB-JA-139'") }} = 1 and {{ hnh_is_opening_balance('toInt64(42)', "'OB'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(42)', "'Abha-651'") }} = 1 and {{ hnh_is_opening_balance('toInt64(42)', "'M-JA-407'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(42)', "'RF-40'") }} = 1 and {{ hnh_is_opening_balance('toInt64(32)', "'cp'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(32)', "'CP-2956'") }} = 1 and {{ hnh_is_opening_balance('toInt64(32)', "'ppc-588'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(32)', "'ccp-6'") }} = 1 and {{ hnh_is_opening_balance('toInt64(32)', "'pc-218'") }} = 1
       and {{ hnh_is_opening_balance('toInt64(42)', "'INV-ADJ-166'") }} = 0 and {{ hnh_is_opening_balance('toInt64(42)', "'BAT0000000349'") }} = 0
       and {{ hnh_is_opening_balance('toInt64(32)', "'OB-JA-1'") }} = 0 and {{ hnh_is_opening_balance('toInt64(42)', "'CP-1'") }} = 0
       and {{ hnh_is_opening_balance('toInt64(42)', null_s) }} = 0 and {{ hnh_is_opening_balance(null_i, "'OB'") }} = 0)

union all
select 'fusion movement type wrong'
where not ({{ hnh_fusion_movement_type('toInt64(42)', 'toFloat64(5)', "'01'", 'toUInt8(1)') }} = 'Opening balance'
       and {{ hnh_fusion_movement_type('toInt64(300000012981827)', 'toFloat64(-1)', "'04'", 'toUInt8(0)') }} = 'Patient sale'
       and {{ hnh_fusion_movement_type('toInt64(300000012981826)', 'toFloat64(1)', "'04'", 'toUInt8(0)') }} = 'Patient return'
       and {{ hnh_fusion_movement_type('toInt64(300000012981824)', 'toFloat64(-1)', "'02'", 'toUInt8(0)') }} = 'Transfer out'
       and {{ hnh_fusion_movement_type('toInt64(300000012981825)', 'toFloat64(1)', "'04'", 'toUInt8(0)') }} = 'Transfer in'
       and {{ hnh_fusion_movement_type('toInt64(18)', 'toFloat64(10)', "'02'", 'toUInt8(0)') }} = 'Goods receipt'
       and {{ hnh_fusion_movement_type('toInt64(71)', 'toFloat64(-1)', "'02'", 'toUInt8(0)') }} = 'Goods receipt'
       and {{ hnh_fusion_movement_type('toInt64(36)', 'toFloat64(-2)', "'02'", 'toUInt8(0)') }} = 'Return to supplier'
       and {{ hnh_fusion_movement_type('toInt64(8)', 'toFloat64(-3)', "'06'", 'toUInt8(0)') }} = 'Count adjustment'
       and {{ hnh_fusion_movement_type('toInt64(21)', 'toFloat64(-4)', "'01'", 'toUInt8(0)') }} = 'Transfer out'
       and {{ hnh_fusion_movement_type('toInt64(12)', 'toFloat64(4)', "'04'", 'toUInt8(0)') }} = 'Transfer in'
       and {{ hnh_fusion_movement_type('toInt64(1)', 'toFloat64(-1)', "'01'", 'toUInt8(0)') }} = 'Department issue'
       and {{ hnh_fusion_movement_type('toInt64(32)', 'toFloat64(-1)', "'06'", 'toUInt8(0)') }} = 'Department issue'
       and {{ hnh_fusion_movement_type('toInt64(32)', 'toFloat64(-1)', "'02'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_fusion_movement_type('toInt64(42)', 'toFloat64(1)', "'02'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_fusion_movement_type('toInt64(300000009320013)', 'toFloat64(1)', "'02'", 'toUInt8(0)') }} = 'Write-off / misc'
       and {{ hnh_fusion_movement_type(null_i, null_f, null_s, 'toUInt8(0)') }} = 'Write-off / misc')

union all
select 'consumption flag wrong'
where not ({{ hnh_is_consumption("'Patient sale'") }} = 1 and {{ hnh_is_consumption("'Patient return'") }} = 1
       and {{ hnh_is_consumption("'Department issue'") }} = 1 and {{ hnh_is_consumption("'Transfer out'") }} = 0
       and {{ hnh_is_consumption("'Transfer in'") }} = 0 and {{ hnh_is_consumption("'Opening balance'") }} = 0
       and {{ hnh_is_consumption("'Goods receipt'") }} = 0 and {{ hnh_is_consumption(null_s) }} = 0)

union all
select 'movement direction wrong'
where not ({{ hnh_movement_direction("'Patient sale'") }} = -1 and {{ hnh_movement_direction("'Patient return'") }} = 1
       and {{ hnh_movement_direction("'Department issue'") }} = -1 and {{ hnh_movement_direction("'Transfer out'") }} = -1
       and {{ hnh_movement_direction("'Transfer in'") }} = 1 and {{ hnh_movement_direction("'Goods receipt'") }} = 1
       and {{ hnh_movement_direction("'Return to supplier'") }} = -1 and {{ hnh_movement_direction("'Count adjustment'") }} = 0
       and {{ hnh_movement_direction("'Write-off / misc'") }} = 0 and {{ hnh_movement_direction("'Opening balance'") }} = 0)

union all
select 'oasis line reference wrong'
where not (ifNull({{ hnh_oasis_line_ref("'GN-7606861'") }} = 7606861, 0) and ifNull({{ hnh_oasis_line_ref("'AB-9411507'") }} = 9411507, 0)
       and ifNull({{ hnh_oasis_line_ref("'GN--7460641'") }} = 7460641, 0) and ifNull({{ hnh_oasis_line_ref("'MA-12'") }} = 12, 0)
       and {{ hnh_oasis_line_ref("'OB-JA-139'") }} is null and {{ hnh_oasis_line_ref("'cp'") }} is null
       and {{ hnh_oasis_line_ref("'10313'") }} is null and {{ hnh_oasis_line_ref("''") }} is null
       and {{ hnh_oasis_line_ref(null_s) }} is null)

union all
select 'primary quantity wrong'
where not ({{ hnh_primary_qty('toFloat64(30)', 'toFloat64(30)') }} = 1 and {{ hnh_primary_qty('toFloat64(90)', 'toFloat64(30)') }} = 3
       and {{ hnh_primary_qty('toFloat64(5)', 'toFloat64(0)') }} = 5 and {{ hnh_primary_qty('toFloat64(5)', null_f) }} = 5
       and {{ hnh_primary_qty(null_f, 'toFloat64(2)') }} = 0)

union all
select 'abc class wrong'
where not ({{ hnh_abc_class('toFloat64(0.5)') }} = 'A' and {{ hnh_abc_class('toFloat64(0.80)') }} = 'A'
       and {{ hnh_abc_class('toFloat64(0.81)') }} = 'B' and {{ hnh_abc_class('toFloat64(0.95)') }} = 'B'
       and {{ hnh_abc_class('toFloat64(0.96)') }} = 'C' and {{ hnh_abc_class(null_f) }} = 'C')

union all
select 'org type wrong'
where not ({{ hnh_org_type_code("'J04'") }} = '04' and {{ hnh_org_type_code("'MH12'") }} = '12'
       and {{ hnh_org_type_code("'RF01'") }} = '01' and {{ hnh_org_type_code("'N01'") }} = '04'
       and {{ hnh_org_type_code("'N02'") }} = '06' and {{ hnh_org_type_code("'N03'") }} = '07'
       and {{ hnh_org_type_code("'N04'") }} = '09' and {{ hnh_org_type_code("'HQ01'") }} = '10'
       and {{ hnh_org_type_code("'IT_HQ'") }} = '10' and {{ hnh_org_type_code("'MST'") }} = '00'
       and {{ hnh_org_type_code(null_s) }} = '00')

union all
select 'oasis po status wrong'
where not ({{ hnh_oasis_po_status("'R'", "'R'") }} = 'RELEASED' and {{ hnh_oasis_po_status("'C'", "'P'") }} = 'CLOSED'
       and {{ hnh_oasis_po_status("'O'", null_s) }} = 'OPEN' and {{ hnh_oasis_po_status("'R'", "'C'") }} = 'CANCELED'
       and {{ hnh_oasis_po_status(null_s, null_s) }} = 'UNKNOWN')

union all
select 'stock item key wrong'
where not ({{ hnh_stock_item_key('toInt64(123)', "'B1'", "'P1'") }} = {{ hnh_surrogate_key(['toInt64(123)']) }}
       and {{ hnh_stock_item_key(null_i, "'B1'", "'P1'") }} = {{ hnh_surrogate_key(["'B1'", "'P1'"]) }}
       and {{ hnh_stock_item_key(null_i, "'B1'", "'P1'") }} != {{ hnh_stock_item_key('toInt64(123)', "'B1'", "'P1'") }}
       and {{ hnh_stock_item_key(null_i, null_s, null_s) }} = -1)

union all
select 'fusion store key wrong'
where not ({{ hnh_fusion_store_key('toInt64(77)', "'SUB1'") }} = {{ hnh_surrogate_key(["'fusion'", 'toInt64(77)', "'SUB1'"]) }}
       and {{ hnh_fusion_store_key('toInt64(77)', null_s) }} = {{ hnh_surrogate_key(["'fusion'", 'toInt64(77)', "'*'"]) }}
       and {{ hnh_fusion_store_key('toInt64(77)', null_s) }} != {{ hnh_fusion_store_key('toInt64(77)', "'SUB1'") }}
       and {{ hnh_fusion_store_key('toInt64(77)', "''") }} = {{ hnh_surrogate_key(["'fusion'", 'toInt64(77)', "'*'"]) }}
       and {{ hnh_fusion_store_key(null_i, "'SUB1'") }} = -1
       and {{ hnh_fusion_store_key(null_i, null_s) }} = -1)
