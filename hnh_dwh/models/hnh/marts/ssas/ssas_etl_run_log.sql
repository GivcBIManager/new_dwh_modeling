-- Processing gate for SSAS (spec 9.4): process.ps1 reads the latest tag:hnh run through the ssas_reader grant.
select
    invocation_id,
    run_started_at,
    run_finished_at,
    cast(status as String)  as status,
    toInt64(models_built)   as models_built,
    toInt64(nodes_failed)   as nodes_failed,
    selected
from {{ source('hnh_log', 'etl_run_log') }}
