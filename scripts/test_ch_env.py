"""ch_env reads the ClickHouse login from an env file (default C:\HNH\secrets\clickhouse.env) when the HNH_CH_*
variables are not set."""
import ch_env

KEYS = ["HNH_CH_HOST", "HNH_CH_PORT", "HNH_CH_USER", "HNH_CH_PASSWORD"]


def _clean(monkeypatch, tmp_path):
    for k in KEYS:
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setattr(ch_env.Path, "home", lambda: tmp_path)   # no ~/.claude.json fallback


def test_reads_env_file(monkeypatch, tmp_path):
    _clean(monkeypatch, tmp_path)
    f = tmp_path / "clickhouse.env"
    f.write_text("# ClickHouse write login\nHNH_CH_HOST=172.22.25.214\nHNH_CH_PORT = 8123\n"
                 "HNH_CH_USER=\"loader\"\nHNH_CH_PASSWORD='p=a#ss'\n\n", encoding="utf-8")
    monkeypatch.setenv("HNH_CH_ENV_FILE", str(f))
    assert ch_env.resolve_env() == {"HNH_CH_HOST": "172.22.25.214", "HNH_CH_PORT": "8123",
                                    "HNH_CH_USER": "loader", "HNH_CH_PASSWORD": "p=a#ss"}


def test_environment_beats_env_file(monkeypatch, tmp_path):
    _clean(monkeypatch, tmp_path)
    f = tmp_path / "clickhouse.env"
    f.write_text("HNH_CH_HOST=file-host\nHNH_CH_PORT=8123\nHNH_CH_USER=u\nHNH_CH_PASSWORD=p\n", encoding="utf-8")
    monkeypatch.setenv("HNH_CH_ENV_FILE", str(f))
    monkeypatch.setenv("HNH_CH_HOST", "env-host")
    assert ch_env.resolve_env()["HNH_CH_HOST"] == "env-host"


def test_empty_value_in_file_is_missing(monkeypatch, tmp_path):
    _clean(monkeypatch, tmp_path)
    f = tmp_path / "clickhouse.env"
    f.write_text("HNH_CH_HOST=h\nHNH_CH_PORT=8123\nHNH_CH_USER=u\nHNH_CH_PASSWORD=\n", encoding="utf-8")
    monkeypatch.setenv("HNH_CH_ENV_FILE", str(f))
    try:
        ch_env.resolve_env()
    except SystemExit as e:
        assert "HNH_CH_PASSWORD" in str(e)
    else:
        raise AssertionError("missing password not reported")
