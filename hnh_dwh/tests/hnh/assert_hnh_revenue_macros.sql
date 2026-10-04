{% set null_s = "cast(null as Nullable(String))" %}
{% set null_i = "cast(null as Nullable(Int64))" %}
{% set null_u8 = "cast(null as Nullable(UInt8))" %}

select 'charge status wrong' as failure
where not ifNull({{ hnh_charge_status(null_s) }} = 'Live', 0)
   or not ifNull({{ hnh_charge_status("'C'") }} = 'Cancelled', 0)
   or not ifNull({{ hnh_charge_status("'R'") }} = 'Superseded', 0)
   or not ifNull({{ hnh_charge_status("'Q'") }} = 'Unknown', 0)

union all
select 'recognised revenue wrong'
where not ifNull({{ hnh_is_recognised_revenue(null_s, null_s) }} = 1, 0)
   or not ifNull({{ hnh_is_recognised_revenue(null_s, "'N'") }} = 1, 0)
   or not ifNull({{ hnh_is_recognised_revenue(null_s, "'Y'") }} = 0, 0)
   or not ifNull({{ hnh_is_recognised_revenue("'C'", null_s) }} = 0, 0)
   or not ifNull({{ hnh_is_recognised_revenue("'R'", null_s) }} = 0, 0)

union all
select 'medication flag wrong'
where not ifNull({{ hnh_is_medication("'MD'", "'W'") }} = 1, 0)
   or not ifNull({{ hnh_is_medication("'RTL'", null_s) }} = 1, 0)
   or not ifNull({{ hnh_is_medication("'LAB'", "'P'") }} = 1, 0)
   or not ifNull({{ hnh_is_medication("'LAB'", "'V'") }} = 0, 0)
   or not ifNull({{ hnh_is_medication(null_s, null_s) }} = 0, 0)

union all
select 'billed purchaser wrong'
where not ifNull({{ hnh_billed_purchaser("'1'", "toNullable(toInt64(300))", "toUInt8(1)") }} = 300, 0)
   or not ifNull({{ hnh_billed_purchaser("'3'", "toNullable(toInt64(300))", "toUInt8(1)") }} = 8888, 0)
   or not ifNull({{ hnh_billed_purchaser("'2'", null_i, "toUInt8(1)") }} = 8888, 0)
   or not ifNull({{ hnh_billed_purchaser("'3'", null_i, "toUInt8(0)") }} = 9999, 0)
   or not ifNull({{ hnh_billed_purchaser("'3'", "toNullable(toInt64(410))", "toUInt8(0)") }} = 410, 0)
   or not ifNull({{ hnh_billed_purchaser("'1'", null_i, "toUInt8(1)") }} = 9999, 0)
   or not ifNull({{ hnh_billed_purchaser(null_s, "toNullable(toInt64(300))", "toUInt8(1)") }} = 8888, 0)
   or not ifNull({{ hnh_billed_purchaser(null_s, "toNullable(toInt64(300))", null_u8) }} = 300, 0)

union all
select 'charge care type wrong'
where not ifNull({{ hnh_charge_care_type("'ER'", "'O'") }} = 'ER', 0)
   or not ifNull({{ hnh_charge_care_type("'Unknown'", "'I'") }} = 'IP', 0)
   or not ifNull({{ hnh_charge_care_type(null_s, "'O'") }} = 'OP', 0)
   or not ifNull({{ hnh_charge_care_type(null_s, null_s) }} = 'Unknown', 0)

union all
select 'preauth outcome wrong'
where not ifNull({{ hnh_preauth_outcome("'APPROVED'", null_s, null_s) }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome("'ALL LISTED SERVICES ARE APPROVED'", null_s, null_s) }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome("'ACCEPT.'", null_s, null_s) }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome("'APPROVED ONLY UP TO 30 DAYS'", null_s, null_s) }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome("'PARTIAL'", null_s, null_s) }} = 'Partially approved', 0)
   or not ifNull({{ hnh_preauth_outcome("'NOT-REQUIRED'", null_s, null_s) }} = 'Not required', 0)
   or not ifNull({{ hnh_preauth_outcome("'REJECTED'", "'Y'", "'S'") }} = 'Rejected', 0)
   or not ifNull({{ hnh_preauth_outcome("'PENDED'", null_s, null_s) }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome("'QUEUED BY NPHIES'", null_s, null_s) }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome("'QUEUED'", null_s, null_s) }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome("'ERROR BY NPHIES'", null_s, null_s) }} = 'Error', 0)
   or not ifNull({{ hnh_preauth_outcome("'SOMETHING ELSE'", null_s, null_s) }} = 'Unknown', 0)
   or not ifNull({{ hnh_preauth_outcome("'SOMETHING ELSE'", "'Y'", "'S'") }} = 'Unknown', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'Y'", "'S'") }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'Y'", "'P'") }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'Y'", "'O'") }} = 'Not sent', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'R'", "'S'") }} = 'Rejected', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'R'", "'P'") }} = 'Rejected', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'Z'", "'S'") }} = 'Not required', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'Z'", "'O'") }} = 'Not required', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'C'", "'S'") }} = 'Cancelled', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'C'", null_s) }} = 'Cancelled', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'H'", "'S'") }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'H'", "'O'") }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'N'", "'S'") }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, "'N'", "'P'") }} = 'Not sent', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, null_s, "'S'") }} = 'Pended', 0)
   or not ifNull({{ hnh_preauth_outcome(null_s, null_s, "'O'") }} = 'Not sent', 0)
   or not ifNull({{ hnh_preauth_outcome("'SENT'", "'Y'", "'S'") }} = 'Approved', 0)
   or not ifNull({{ hnh_preauth_outcome("'COMPLETE'", null_s, "'O'") }} = 'Not sent', 0)
   or not ifNull({{ hnh_preauth_outcome("'SENT'", null_s, null_s) }} = 'Not sent', 0)

union all
select 'preauth outcome key wrong'
where not ifNull({{ hnh_preauth_outcome_key("'Approved'") }} = 1, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Partially approved'") }} = 2, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Not required'") }} = 3, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Rejected'") }} = 4, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Pended'") }} = 5, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Error'") }} = 6, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Cancelled'") }} = 7, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Not sent'") }} = 8, 0)
   or not ifNull({{ hnh_preauth_outcome_key("'Unknown'") }} = -1, 0)
   or not ifNull({{ hnh_preauth_outcome_key(null_s) }} = -1, 0)

union all
select 'patient receipt wrong'
where not ifNull({{ hnh_is_patient_receipt("'CASHACC'", "'100'") }} = 1, 0)
   or not ifNull({{ hnh_is_patient_receipt(null_s, null_s) }} = 1, 0)
   or not ifNull({{ hnh_is_patient_receipt("' 102 '", "'102'") }} = 1, 0)
   or not ifNull({{ hnh_is_patient_receipt("'INS-1001-0001'", null_s) }} = 0, 0)
   or not ifNull({{ hnh_is_patient_receipt("'DIR-0006-004'", "'DIR-0006-004'") }} = 0, 0)
   or not ifNull({{ hnh_is_patient_receipt("'102'", "'103'") }} = 0, 0)
   or not ifNull({{ hnh_is_patient_receipt("'102'", null_s) }} = 0, 0)
