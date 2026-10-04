{% set null_s = "cast(null as Nullable(String))" %}
{% set null_i = "cast(null as Nullable(Int64))" %}

select 'charge status wrong' as failure
where {{ hnh_charge_status(null_s) }} != 'Live' or {{ hnh_charge_status("'C'") }} != 'Cancelled'
   or {{ hnh_charge_status("'R'") }} != 'Superseded' or {{ hnh_charge_status("'Q'") }} != 'Unknown'

union all
select 'recognised revenue wrong'
where {{ hnh_is_recognised_revenue(null_s, null_s) }} != 1
   or {{ hnh_is_recognised_revenue(null_s, "'N'") }} != 1
   or {{ hnh_is_recognised_revenue(null_s, "'Y'") }} != 0
   or {{ hnh_is_recognised_revenue("'C'", null_s) }} != 0
   or {{ hnh_is_recognised_revenue("'R'", null_s) }} != 0

union all
select 'medication flag wrong'
where {{ hnh_is_medication("'MD'", "'W'") }} != 1 or {{ hnh_is_medication("'RTL'", null_s) }} != 1
   or {{ hnh_is_medication("'LAB'", "'P'") }} != 1 or {{ hnh_is_medication("'LAB'", "'V'") }} != 0
   or {{ hnh_is_medication(null_s, null_s) }} != 0

union all
select 'billed purchaser wrong'
where {{ hnh_billed_purchaser("'1'", "toNullable(toInt64(300))", "toUInt8(1)") }} != 300
   or {{ hnh_billed_purchaser("'3'", "toNullable(toInt64(300))", "toUInt8(1)") }} != 8888
   or {{ hnh_billed_purchaser("'2'", null_i, "toUInt8(1)") }} != 8888
   or {{ hnh_billed_purchaser("'3'", null_i, "toUInt8(0)") }} != 9999
   or {{ hnh_billed_purchaser("'3'", "toNullable(toInt64(410))", "toUInt8(0)") }} != 410
   or {{ hnh_billed_purchaser("'1'", null_i, "toUInt8(1)") }} != 9999

union all
select 'charge care type wrong'
where {{ hnh_charge_care_type("'ER'", "'O'") }} != 'ER'
   or {{ hnh_charge_care_type("'Unknown'", "'I'") }} != 'IP'
   or {{ hnh_charge_care_type(null_s, "'O'") }} != 'OP'
   or {{ hnh_charge_care_type(null_s, null_s) }} != 'Unknown'

union all
select 'preauth outcome wrong'
where {{ hnh_preauth_outcome("'APPROVED'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'ALL LISTED SERVICES ARE APPROVED'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'ACCEPT.'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'APPROVED ONLY UP TO 30 DAYS'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'PARTIAL'", null_s, null_s) }} != 'Partially approved'
   or {{ hnh_preauth_outcome("'NOT-REQUIRED'", null_s, null_s) }} != 'Not required'
   or {{ hnh_preauth_outcome("'REJECTED'", "'Y'", "'S'") }} != 'Rejected'
   or {{ hnh_preauth_outcome("'PENDED'", null_s, null_s) }} != 'Pended'
   or {{ hnh_preauth_outcome("'QUEUED BY NPHIES'", null_s, null_s) }} != 'Pended'
   or {{ hnh_preauth_outcome("'ERROR BY NPHIES'", null_s, null_s) }} != 'Error'
   or {{ hnh_preauth_outcome("'SOMETHING ELSE'", null_s, null_s) }} != 'Unknown'
   or {{ hnh_preauth_outcome(null_s, "'Y'", "'S'") }} != 'Approved'
   or {{ hnh_preauth_outcome(null_s, "'R'", "'S'") }} != 'Rejected'
   or {{ hnh_preauth_outcome(null_s, "'Z'", "'S'") }} != 'Not required'
   or {{ hnh_preauth_outcome(null_s, "'C'", "'S'") }} != 'Cancelled'
   or {{ hnh_preauth_outcome(null_s, "'H'", "'S'") }} != 'Pended'
   or {{ hnh_preauth_outcome(null_s, "'N'", "'S'") }} != 'Pended'
   or {{ hnh_preauth_outcome(null_s, "'N'", "'P'") }} != 'Not sent'
   or {{ hnh_preauth_outcome(null_s, null_s, "'O'") }} != 'Not sent'
   or {{ hnh_preauth_outcome(null_s, "'Q'", "'S'") }} != 'Unknown'

union all
select 'preauth outcome key wrong'
where {{ hnh_preauth_outcome_key("'Approved'") }} != 1 or {{ hnh_preauth_outcome_key("'Not sent'") }} != 8
   or {{ hnh_preauth_outcome_key("'Unknown'") }} != -1
