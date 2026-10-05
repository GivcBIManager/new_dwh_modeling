{% set null_s = "cast(null as Nullable(String))" %}

select 'nphies outcome wrong' as failure
where not ifNull({{ hnh_nphies_outcome("'approved'") }} = 'Approved', 0)
   or not ifNull({{ hnh_nphies_outcome("'PARTIAL'") }} = 'Partially approved', 0)
   or not ifNull({{ hnh_nphies_outcome("'not-required'") }} = 'Not required', 0)
   or not ifNull({{ hnh_nphies_outcome("'rejected'") }} = 'Rejected', 0)
   or not ifNull({{ hnh_nphies_outcome("'pended'") }} = 'Pended', 0)
   or not ifNull({{ hnh_nphies_outcome("'queued'") }} = 'Pended', 0)
   or not ifNull({{ hnh_nphies_outcome("'odd'") }} = 'Unknown', 0)
   or not ifNull({{ hnh_nphies_outcome(null_s) }} = 'Unknown', 0)

union all
select 'decision status wrong'
where not ifNull({{ hnh_is_decision_status("'APPROVED'") }} = 1, 0)
   or not ifNull({{ hnh_is_decision_status("'PARTIAL'") }} = 1, 0)
   or not ifNull({{ hnh_is_decision_status("'REJECTED'") }} = 1, 0)
   or not ifNull({{ hnh_is_decision_status("'PENDED'") }} = 0, 0)
   or not ifNull({{ hnh_is_decision_status("'ERROR'") }} = 0, 0)
   or not ifNull({{ hnh_is_decision_status(null_s) }} = 0, 0)

union all
select 'claim adjudication status wrong'
where not ifNull({{ hnh_claim_adjudication_status("toUInt8(0)", "toUInt8(0)", null_s) }} = 'Not sent', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(0)", null_s) }} = 'No response', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'PARTIAL'") }} = 'Adjudicated', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'PENDED'") }} = 'Pended', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'QUEUED'") }} = 'Pended', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'ERROR'") }} = 'Error', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", null_s) }} = 'Error', 0)

union all
select 'reason from notes wrong'
where not ifNull({{ hnh_reason_from_notes("'  BE-1-3Submission not compliant'") }} = 'BE-1-3', 0)
   or not ifNull({{ hnh_reason_from_notes("'- MN-1-1  '") }} = 'MN-1-1', 0)
   or not ifNull({{ hnh_reason_from_notes("'Approved'") }} is null, 0)
   or not ifNull({{ hnh_reason_from_notes(null_s) }} is null, 0)

union all
select 'adjudication amount wrong'
where not ifNull({{ hnh_adjudication_amount("['eligible','benefit']", "['{\"amount\":{\"value\":19}}','{\"amount\":{\"value\":15.2}}']", "'benefit'") }} = 15.2, 0)
   or not ifNull({{ hnh_adjudication_amount("['eligible']", "['{\"amount\":{\"value\":19}}']", "'benefit'") }} is null, 0)
