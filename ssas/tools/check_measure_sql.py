"""Run the `sql` of every measure check read-only through the ODBC DSN HNH_Gold and classify the outcome.

    python ssas/tools/check_measure_sql.py [--file ssas/tests/measures/finance.json] [--dsn HNH_Gold]

OK                  the statement ran (the value is shown)
UNKNOWN             unknown table or column (ClickHouse codes 47, 60, 16, 81): acceptable before the dbt build that creates it
SYNTAX/ERROR        anything else (e.g. code 62, a syntax error): fix the check
Only SELECT statements are sent (Invoke-HnhSelect refuses anything else). Exit code 1 when any check is SYNTAX/ERROR.
There is no Python ClickHouse driver on the server, so the statements go through PowerShell (scripts/HnhCh.psm1).
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PS = r"""
param([string]$In, [string]$Out, [string]$Dsn)
Import-Module (Join-Path $env:HNH_ROOT 'scripts\HnhCh.psm1') -Force
$checks = Get-Content -Raw -Encoding UTF8 $In | ConvertFrom-Json
$res = @()
foreach ($c in $checks) {
    try { $r = Invoke-HnhSelect -Dsn $Dsn -Sql $c.sql; $v = if ($r.Count -gt 0) { $r[0].PSObject.Properties | Select-Object -First 1 -ExpandProperty Value } else { $null }
          $res += [pscustomobject]@{ name = $c.name; ok = $true; value = "$v"; error = '' } }
    catch { $res += [pscustomobject]@{ name = $c.name; ok = $false; value = ''; error = ($_.Exception.Message -replace '\s+', ' ') } }
}
ConvertTo-Json -InputObject @($res) -Depth 3 | Set-Content -Encoding UTF8 $Out
"""
UNKNOWN = re.compile(r"Code: ?(47|60|16|81)\b|UNKNOWN_(TABLE|IDENTIFIER)|Unknown (table|identifier|expression)|Missing columns|doesn't exist|does not exist", re.I)


def classify(item: dict) -> str:
    if item["ok"]:
        return "OK"
    return "UNKNOWN" if UNKNOWN.search(item["error"]) else "SYNTAX/ERROR"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default=str(ROOT / "ssas" / "tests" / "measures" / "finance.json"))
    ap.add_argument("--dsn", default="HNH_Gold")
    args = ap.parse_args()
    checks = json.loads(Path(args.file).read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "in.json").write_text(json.dumps([{"name": c["name"], "sql": c["sql"]} for c in checks]), encoding="utf-8")
        (tmp / "run.ps1").write_text(PS, encoding="utf-8-sig")
        env = {**__import__("os").environ, "HNH_ROOT": str(ROOT)}
        proc = subprocess.run(["powershell", "-NoProfile", "-File", str(tmp / "run.ps1"), "-In", str(tmp / "in.json"),
                               "-Out", str(tmp / "out.json"), "-Dsn", args.dsn], capture_output=True, text=True, env=env)
        if not (tmp / "out.json").exists():
            print(proc.stdout, proc.stderr)
            return 2
        results = json.loads((tmp / "out.json").read_text(encoding="utf-8-sig"))
    counts = {}
    for item in results:
        kind = classify(item)
        counts[kind] = counts.get(kind, 0) + 1
        detail = item["value"] if kind == "OK" else item["error"][:420]
        print(f"{kind:12} {item['name'][:90]} | {detail}")
    print(counts)
    return 1 if counts.get("SYNTAX/ERROR") else 0


if __name__ == "__main__":
    sys.exit(main())
