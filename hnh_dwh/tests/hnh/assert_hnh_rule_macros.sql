select 'care type mapping wrong' as failure
where {{ hnh_care_type("'O'") }} != 'OP' or {{ hnh_care_type("'E'") }} != 'ER'
   or {{ hnh_care_type("'I'") }} != 'IP' or {{ hnh_care_type("'D'") }} != 'DAYCASE'
   or {{ hnh_care_type("'S'") }} != 'Unknown'
   or {{ hnh_care_type("cast(null as Nullable(String))") }} != 'Unknown'

union all
select 'care type key wrong'
where {{ hnh_care_type_key("'OP'") }} != 1 or {{ hnh_care_type_key("'ER'") }} != 2
   or {{ hnh_care_type_key("'IP'") }} != 3 or {{ hnh_care_type_key("'DAYCASE'") }} != 4
   or {{ hnh_care_type_key("'Unknown'") }} != -1

union all
select 'outcome group wrong'
where {{ hnh_outcome_group("'CANCELLED BY HOSPITAL\\DOCTOR'") }} != 'Cancelled'
   or {{ hnh_outcome_group("'CANCELLED BY PATIENT'") }} != 'Cancelled'
   or {{ hnh_outcome_group("'RESCHEDULED BY HOSPITAL'") }} != 'Rescheduled'
   or {{ hnh_outcome_group("'DNA'") }} != 'No-show recorded'
   or {{ hnh_outcome_group("'NOSHOW'") }} != 'No-show recorded'
   or {{ hnh_outcome_group("'LEFT WITHOUT BEING SEEN'") }} != 'Left without being seen'
   or {{ hnh_outcome_group("'ADMISSION TO ICU (CRITICAL)'") }} != 'Admitted'
   or {{ hnh_outcome_group("'PATIENT ADMITTED (DON''T USE)'") }} != 'Admitted'
   or {{ hnh_outcome_group("'REFERRED TO OPD (CARDIOLOGY)'") }} != 'Referred'
   or {{ hnh_outcome_group("'TRANSFERRED TO ANOTHER HOSPITAL'") }} != 'Referred'
   or {{ hnh_outcome_group("'LAMA'") }} != 'Left against advice'
   or {{ hnh_outcome_group("'DIED'") }} != 'Died'
   or {{ hnh_outcome_group("'FOLLOW-UP BOOKED'") }} != 'Attended'
   or {{ hnh_outcome_group("'CONDITION CURED'") }} != 'Attended'
   or {{ hnh_outcome_group("'EPISODE CLOSED-CANCELED'") }} != 'Other'
   or {{ hnh_outcome_group("'TEST OUTCOME 1'") }} != 'Other'
   or {{ hnh_outcome_group("cast(null as Nullable(String))") }} != 'Other'

union all
select 'discharge outcome group wrong'
where {{ hnh_discharge_outcome_group("'NORMAL DISCHARGE'") }} != 'Normal discharge'
   or {{ hnh_discharge_outcome_group("'DAMA'") }} != 'Left against advice'
   or {{ hnh_discharge_outcome_group("'LAMA'") }} != 'Left against advice'
   or {{ hnh_discharge_outcome_group("'DIED'") }} != 'Died'
   or {{ hnh_discharge_outcome_group("'TRANSFEFRED TO ANOTHER HOSPITAL'") }} != 'Transferred out'
   or {{ hnh_discharge_outcome_group("'TRANSFERRED TO ANOTHER EPISODE'") }} != 'Transferred to another episode'
   or {{ hnh_discharge_outcome_group("'WRONG ADMISSION'") }} != 'Wrong admission'
   or {{ hnh_discharge_outcome_group("'ESCAPED'") }} != 'Absconded'
   or {{ hnh_discharge_outcome_group("'STATISTICAL DISCHARGE FROM LEAVE'") }} != 'Other'

union all
select 'care setting wrong'
where {{ hnh_care_setting("'C'") }} != 'OP' or {{ hnh_care_setting("'W'") }} != 'IP'
   or {{ hnh_care_setting("'E'") }} != 'ER' or {{ hnh_care_setting("'D'") }} != 'Theatre'
   or {{ hnh_care_setting("'Z'") }} != 'Theatre' or {{ hnh_care_setting("'X'") }} != 'Ancillary'
   or {{ hnh_care_setting("'A'") }} != 'Support'
   or {{ hnh_care_setting("cast(null as Nullable(String))") }} != 'Support'

union all
select 'person identifier wrong'
where {{ hnh_person_identifier("' 0010-123 456 '", "'A1'", "'B1'", "toUInt8(1)", "toInt64(7)") }} != 'N:10123456'
   or {{ hnh_person_identifier("cast(null as Nullable(String))", "'a 99-1'", "'B1'", "toUInt8(1)", "toInt64(7)") }} != 'P:A991'
   or {{ hnh_person_identifier("''", "''", "'0042'", "toUInt8(1)", "toInt64(7)") }} != 'B:42'
   or {{ hnh_person_identifier("''", "cast(null as Nullable(String))", "''", "toUInt8(3)", "toInt64(7)") }} != 'L:3|7'

union all
select 'person identifier source wrong'
where {{ hnh_person_identifier_source("'1'", "'A1'", "'B1'") }} != 'National id or iqama'
   or {{ hnh_person_identifier_source("''", "'A1'", "'B1'") }} != 'Passport'
   or {{ hnh_person_identifier_source("''", "''", "'B1'") }} != 'Border number'
   or {{ hnh_person_identifier_source("''", "''", "''") }} != 'Local'

union all
select 'shift wrong'
where {{ hnh_shift("toDateTime('2026-10-01 07:59:00')") }} != '00:00-08:00'
   or {{ hnh_shift("toDateTime('2026-10-01 08:00:00')") }} != '08:00-12:00'
   or {{ hnh_shift("toDateTime('2026-10-01 16:29:00')") }} != '12:00-16:30'
   or {{ hnh_shift("toDateTime('2026-10-01 16:30:00')") }} != '16:30-24:00'
