{{ config(alias='targets') }}

-- Old bsc.targets (bsc spec B7): the scorecard's hand-loaded KPI targets, copied from the old server into
-- default.bsc_targets with the old column types (scripts/load_bsc_reference.ps1).
select *
from {{ source('reference', 'bsc_targets') }}
