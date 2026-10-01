"""Run dbt against the hnh_dwh project with resolved connection settings.

Usage: python scripts/run_dbt.py build --select tag:hnh
"""
import subprocess
import sys
from pathlib import Path

from ch_env import resolve_env

PROJECT = Path(__file__).resolve().parent.parent / "hnh_dwh"


def main():
    resolve_env()
    cmd = ["dbt", *sys.argv[1:], "--project-dir", str(PROJECT), "--profiles-dir", str(PROJECT)]
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
