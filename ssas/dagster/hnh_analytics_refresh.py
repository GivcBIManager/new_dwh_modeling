"""Dagster definitions that refresh the SSAS model HNH_Analytics after a dbt build (ssas/README.md, "Trigger from Dagster").

Copy this module into the Dagster project on the dbt server (172.22.25.214) and merge ``defs`` into its Definitions.
It runs ``ssas\scripts\process.ps1`` on HNHANALYTICSSRV over SSH as ``svc_dagster`` (key-only login). The script
processes the database only when ``gold.ssas_etl_run_log`` holds a newer successful dbt run for ``selected`` than the
one it processed last, so running it after every dbt job is safe: exit code 2 means "nothing new", not a failure.

Environment on the Dagster host:
  HNH_SSAS_SSH      ssh target, default svc_dagster@hnhanalyticssrv (use the IP when the name does not resolve)
  HNH_SSAS_SSH_KEY  private key, default ~/.ssh/svc_dagster_id_ed25519 (copied from C:\HNH\secrets on the server)
"""
import os
import re
import subprocess

from dagster import (
    AssetExecutionContext,
    AssetKey,
    Config,
    Definitions,
    MaterializeResult,
    RunConfig,
    ScheduleDefinition,
    asset,
    define_asset_job,
)

SSH_TARGET = os.environ.get("HNH_SSAS_SSH", "svc_dagster@hnhanalyticssrv")
SSH_KEY = os.path.expanduser(os.environ.get("HNH_SSAS_SSH_KEY", "~/.ssh/svc_dagster_id_ed25519"))
SCRIPT = r"D:\new_dwh_modeling\ssas\scripts\process.ps1"
PROCESS_TIMEOUT_S = 4 * 3600   # a Weekly full refresh takes well under this

# The dbt assets the refresh follows. With dagster-dbt an hnh model's asset key is its model name; adjust when the
# project prefixes keys. ssas_etl_run_log is built by every tag:hnh run and is what the gate reads.
HNH_DBT_DEPS = [AssetKey("ssas_etl_run_log")]

# Run config is typed into Dagster by anyone who can launch a run and ends up on a remote command line, so each field is
# limited to the characters it needs (a dbt selector: names, tags, paths, + * @ , and spaces; no quotes or shell metacharacters).
DATABASE_PATTERN = re.compile(r"[A-Za-z0-9_]+")
SELECTOR_PATTERN = re.compile(r"[A-Za-z0-9_:+.*@,/ \-]+")


class RefreshConfig(Config):
    mode: str = "Daily"          # Daily (dimensions + last 3 months of the big facts) or Weekly (full refresh)
    database: str = "HNH_Analytics"
    selected: str = "tag:hnh"    # the dbt selector of the run the gate looks for (what the dbt job ran)


@asset(name="hnh_analytics_refresh", group_name="ssas", deps=HNH_DBT_DEPS,
       description="Processes the SSAS model HNH_Analytics on HNHANALYTICSSRV after the dbt build (process.ps1 over SSH).")
def hnh_analytics_refresh(context: AssetExecutionContext, config: RefreshConfig) -> MaterializeResult:
    if config.mode not in ("Daily", "Weekly"):
        raise ValueError(f"mode must be Daily or Weekly, not {config.mode!r}")
    if not DATABASE_PATTERN.fullmatch(config.database):
        raise ValueError(f"database must be a plain name, not {config.database!r}")
    if not SELECTOR_PATTERN.fullmatch(config.selected):
        raise ValueError(f"selected must be a dbt selector without quotes or shell characters, not {config.selected!r}")
    remote = (f'powershell -NoProfile -ExecutionPolicy Bypass -File "{SCRIPT}" '
              f'-Mode {config.mode} -Database {config.database} -Selected "{config.selected}"')
    cmd = ["ssh", "-i", SSH_KEY, "-o", "BatchMode=yes", "-o", "ConnectTimeout=30",
           "-o", "StrictHostKeyChecking=accept-new", SSH_TARGET, remote]
    context.log.info("ssh %s: %s", SSH_TARGET, remote)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=PROCESS_TIMEOUT_S)
    if result.stdout:
        context.log.info(result.stdout)
    if result.returncode == 2:
        context.log.warning("Gate closed: no new successful dbt run for %r since the last processing; nothing processed",
                            config.selected)
        return MaterializeResult(metadata={"processed": False, "mode": config.mode, "database": config.database})
    if result.returncode != 0:
        raise RuntimeError(f"process.ps1 exited {result.returncode}\n{result.stdout}\n{result.stderr}")
    return MaterializeResult(metadata={"processed": True, "mode": config.mode, "database": config.database})


# Either add hnh_analytics_refresh to the selection of the job that runs dbt (it then runs right after the build), or
# keep these schedules: Daily every morning after the dbt job, Weekly (full refresh) on Friday.
_job = define_asset_job("hnh_analytics_refresh_job", selection=[hnh_analytics_refresh])


def _schedule(name: str, cron: str, mode: str) -> ScheduleDefinition:
    return ScheduleDefinition(
        name=name, job=_job, cron_schedule=cron, execution_timezone="Asia/Riyadh",
        run_config=RunConfig(ops={"hnh_analytics_refresh": RefreshConfig(mode=mode)}),
    )


defs = Definitions(
    assets=[hnh_analytics_refresh],
    jobs=[_job],
    schedules=[
        _schedule("hnh_analytics_daily", "0 3 * * 0-4,6", "Daily"),
        _schedule("hnh_analytics_weekly", "0 3 * * 5", "Weekly"),
    ],
)
