import http.client
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from server import make_server
import threading

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / "static"
FILES = [STATIC / "index.html", STATIC / "app.js", STATIC / "app.css"]


def get(port, path):
    c = http.client.HTTPConnection("127.0.0.1", port)
    c.request("GET", path, headers={"Host": "127.0.0.1:%d" % port})
    r = c.getresponse()
    return r.status, r.read().decode("utf-8")


@pytest.fixture
def port():
    s = make_server(0, "http://127.0.0.1:1/")
    t = threading.Thread(target=s.serve_forever, daemon=True)
    t.start()
    yield s.server_address[1]
    s.shutdown()
    s.server_close()


def test_root_serves_index_with_app_files(port):
    status, body = get(port, "/")
    assert status == 200
    assert "/static/app.js" in body and "/static/app.css" in body
    for name in ("app.js", "app.css"):
        assert get(port, "/static/" + name)[0] == 200


def test_no_external_urls():
    for f in FILES:
        text = f.read_text(encoding="utf-8")
        assert not re.search(r"https?://", text), f.name


def test_app_js_parses():
    node = shutil.which("node") or r"C:\Program Files\nodejs\node.exe"
    if not Path(node).exists() and not shutil.which("node"):
        pytest.skip("node is not installed")
    r = subprocess.run([node, "--check", str(STATIC / "app.js")], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


def test_launcher_runs_server():
    text = (ROOT / "start_bsc_settings.cmd").read_text(encoding="utf-8")
    assert 'python "%~dp0server.py"' in text


def test_app_js_never_stores_the_token_or_uses_inner_html():
    js = (STATIC / "app.js").read_text(encoding="utf-8")
    for bad in ("localStorage", "sessionStorage", "document.cookie", "innerHTML"):
        assert bad not in js


def test_manual_value_and_weight_views_are_registered():
    js = (STATIC / "app.js").read_text(encoding="utf-8")
    assert 'registerView("map_bsc_manual_value"' in js
    assert 'registerView("map_bsc_weight"' in js


def test_manual_value_and_weight_views_are_registered():
    js = (STATIC / "app.js").read_text(encoding="utf-8")
    assert 'registerView("map_bsc_manual_value"' in js
    assert 'registerView("map_bsc_weight"' in js
