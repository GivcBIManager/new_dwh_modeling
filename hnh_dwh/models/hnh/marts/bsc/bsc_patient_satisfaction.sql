{{ config(alias='patient_satisfaction') }}

-- Old bsc.patient_satisfaction (bsc spec B7): the scorecard's hand-loaded satisfaction figures, copied from the old
-- server into default.bsc_patient_satisfaction with the old column types (scripts/load_bsc_reference.ps1).
select *
from {{ source('reference', 'bsc_patient_satisfaction') }}
