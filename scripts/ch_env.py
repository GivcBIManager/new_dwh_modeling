"""Resolve ClickHouse connection settings for local development.

Order of precedence: HNH_CH_* environment variables, then the `clickhouse`
entry of ~/.claude.json. Values are placed in os.environ; nothing is printed.
"""
import json
import os
from pathlib import Path

KEYS = {
    "HNH_CH_HOST": "CLICKHOUSE_HOST",
    "HNH_CH_PORT": "CLICKHOUSE_PORT",
    "HNH_CH_USER": "CLICKHOUSE_USER",
    "HNH_CH_PASSWORD": "CLICKHOUSE_PASSWORD",
}


def resolve_env():
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
