"""Runs the page in jsdom against the stub ClickHouse and the real server.py (skipped without node or jsdom)."""
import os
import shutil
import subprocess
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
JSDOM = Path(__file__).resolve().parents[3] / "powerbi_tmdl" / "hnh_bsc_visual" / "node_modules" / "jsdom"


def test_page_in_jsdom():
    node = shutil.which("node") or r"C:\Program Files\nodejs\node.exe"
    if not Path(node).exists():
        pytest.skip("node is not installed")
    if not JSDOM.exists():
        pytest.skip("jsdom is not installed")
    r = subprocess.run([node, str(HERE / "dom_smoke.js")], capture_output=True, text=True, timeout=90,
                       env={**os.environ, "JSDOM_PATH": str(JSDOM)})
    assert r.returncode == 0, r.stdout + r.stderr
    assert "PASS" in r.stdout and "FAIL" not in r.stdout, r.stdout
