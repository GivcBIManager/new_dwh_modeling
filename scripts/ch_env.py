r"""Resolve ClickHouse connection settings for local development.

Order of precedence: HNH_CH_* environment variables, then the env file
(HNH_CH_ENV_FILE, default C:\HNH\secrets\clickhouse.env: KEY=VALUE lines, # comments,
optional quotes), then the `clickhouse` entry of ~/.claude.json. Values are placed in
os.environ; nothing is printed. The env file holds a write password, so it lives in
C:\HNH\secrets (Administrators only), never in the checkout, which local users can read.
"""
import json
import os
from pathlib import Path

DEFAULT_ENV_FILE = r"C:\HNH\secrets\clickhouse.env"

KEYS = {
    "HNH_CH_HOST": "CLICKHOUSE_HOST",
    "HNH_CH_PORT": "CLICKHOUSE_PORT",
    "HNH_CH_USER": "CLICKHOUSE_USER",
    "HNH_CH_PASSWORD": "CLICKHOUSE_PASSWORD",
}


def _read_env_file(path):
    """KEY=VALUE pairs of an env file; blank lines and # comments are skipped, surrounding quotes removed."""
    values = {}
    for line in Path(path).read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def resolve_env():
    missing = [k for k in KEYS if not os.environ.get(k)]
    env_file = Path(os.environ.get("HNH_CH_ENV_FILE") or DEFAULT_ENV_FILE)
    if missing and env_file.exists():
        values = _read_env_file(env_file)
        for key in missing:
            if values.get(key):
                os.environ[key] = values[key]
    missing = [k for k in KEYS if not os.environ.get(k)]
    if missing:
        cfg_path = Path.home() / ".claude.json"
        if cfg_path.exists():
            cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
            env = cfg.get("mcpServers", {}).get("clickhouse", {}).get("env", {})
            for key in missing:
                value = env.get(KEYS[key])
                if value is not None:
                    os.environ[key] = str(value)
    still_missing = [k for k in KEYS if not os.environ.get(k)]
    if still_missing:
        raise SystemExit("Missing connection settings: " + ", ".join(still_missing))
    return {k: os.environ[k] for k in KEYS}


def client():
    import clickhouse_connect

    env = resolve_env()
    return clickhouse_connect.get_client(
        host=env["HNH_CH_HOST"],
        port=int(env["HNH_CH_PORT"]),
        username=env["HNH_CH_USER"],
        password=env["HNH_CH_PASSWORD"],
        send_receive_timeout=1800,
    )
