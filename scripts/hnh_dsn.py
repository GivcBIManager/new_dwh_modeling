"""Read-only ClickHouse SELECT from Python through a system ODBC DSN (default HNH_Gold).

HNHANALYTICSSRV has no Python ClickHouse driver (no clickhouse_connect, no pyodbc), so the query runs through
Invoke-HnhSelect of scripts/HnhCh.psm1 in Windows PowerShell, which refuses anything but one SELECT / WITH / DESCRIBE /
SHOW. The DSN holds the credential; nothing here sees a password. Values come back as text ('' for NULL).
"""
import csv
import subprocess
import tempfile
from pathlib import Path

MODULE = Path(__file__).resolve().parent / "HnhCh.psm1"
RUNNER = r"""param([string]$Module, [string]$Dsn, [string]$SqlFile, [string]$OutFile)
$ErrorActionPreference = 'Stop'
Import-Module $Module -Force
$rows = Invoke-HnhSelect -Dsn $Dsn -Sql ([IO.File]::ReadAllText($SqlFile))
$rows | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
"""


def select(sql: str, dsn: str = "HNH_Gold") -> list[dict]:
    """Rows of one read-only query, as dicts of strings in column order."""
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "q.sql").write_text(sql, encoding="utf-8")
        (tmp / "run.ps1").write_text(RUNNER, encoding="utf-8")
        out = tmp / "out.csv"
        done = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(tmp / "run.ps1"),
             "-Module", str(MODULE), "-Dsn", dsn, "-SqlFile", str(tmp / "q.sql"), "-OutFile", str(out)],
            capture_output=True, text=True)
        if done.returncode != 0:
            raise SystemExit(f"query through DSN {dsn} failed:\n{done.stderr or done.stdout}")
        if not out.exists():
            return []
        with out.open(encoding="utf-8-sig", newline="") as f:
            return list(csv.DictReader(f))
