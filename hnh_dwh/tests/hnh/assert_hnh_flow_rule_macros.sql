select 'short stay wrong' as failure
where {{ hnh_is_short_stay("toDateTime('2026-09-01 10:00:00')", "toDateTime('2026-09-01 10:59:00')") }} != 1
   or {{ hnh_is_short_stay("toDateTime('2026-09-01 10:00:00')", "toDateTime('2026-09-01 11:00:00')") }} != 0
   or {{ hnh_is_short_stay("toDateTime('2026-09-01 10:00:00')", "cast(null as Nullable(DateTime))") }} != 0

union all
select 'ltc wrong'
where {{ hnh_is_ltc("toFloat64(30)", "'WALK IN'") }} != 0
   or {{ hnh_is_ltc("toFloat64(30.01)", "'WALK IN'") }} != 1
   or {{ hnh_is_ltc("toFloat64(2)", "'LTC'") }} != 1
   or {{ hnh_is_ltc("cast(null as Nullable(Float64))", "cast(null as Nullable(String))") }} != 0

union all
select 'admission source wrong'
where {{ hnh_admission_source("'OUTPATIENT CLINICS'", "'ER'") }} != 'OP'
   or {{ hnh_admission_source("'OPD'", "cast(null as Nullable(String))") }} != 'OP'
   or {{ hnh_admission_source("'ACCIDENT & EMERGENCY'", "'OP'") }} != 'ER'
   or {{ hnh_admission_source("'ER'", "cast(null as Nullable(String))") }} != 'ER'
   or {{ hnh_admission_source("cast(null as Nullable(String))", "'ER'") }} != 'ER'
   or {{ hnh_admission_source("'DELIVERY ROOM'", "'OP'") }} != 'OP'
   or {{ hnh_admission_source("cast(null as Nullable(String))", "'IP'") }} != 'Direct'
   or {{ hnh_admission_source("cast(null as Nullable(String))", "cast(null as Nullable(String))") }} != 'Direct'

union all
select 'admission source key wrong'
where {{ hnh_admission_source_key("'OP'") }} != 1 or {{ hnh_admission_source_key("'ER'") }} != 2
   or {{ hnh_admission_source_key("'Direct'") }} != 3 or {{ hnh_admission_source_key("'x'") }} != -1

union all
select 'visit type wrong'
where {{ hnh_visit_type("toUInt8(1)", "toUInt8(1)") }} != 'New patient'
   or {{ hnh_visit_type("toUInt8(0)", "toUInt8(1)") }} != 'Free follow-up'
   or {{ hnh_visit_type("toUInt8(0)", "toUInt8(0)") }} != 'Paid visit'

union all
select 'procedure type wrong'
where {{ hnh_procedure_type("'LOWER SEGMENT C.S. WITH TUBAL LIGATION'", "'D'") }} != 'Cesarean'
   or {{ hnh_procedure_type("'CESAREAN SECTION'", "'Z'") }} != 'Cesarean'
   or {{ hnh_procedure_type("'CORONARY ANGIOGRAPHY'", "'J'") }} != 'Cath Lab'
   or {{ hnh_procedure_type("'COLONOSCOPY'", "'F'") }} != 'Endoscopy'
   or {{ hnh_procedure_type("'NORMAL DELIVERY'", "'Z'") }} != 'L&D'
   or {{ hnh_procedure_type("'APPENDECTOMY'", "'D'") }} != 'Surgery'
   or {{ hnh_procedure_type("cast(null as Nullable(String))", "cast(null as Nullable(String))") }} != 'Surgery'

union all
select 'procedure type key wrong'
where {{ hnh_procedure_type_key("'Surgery'") }} != 1 or {{ hnh_procedure_type_key("'Cesarean'") }} != 2
   or {{ hnh_procedure_type_key("'Cath Lab'") }} != 3 or {{ hnh_procedure_type_key("'Endoscopy'") }} != 4
   or {{ hnh_procedure_type_key("'L&D'") }} != 5
