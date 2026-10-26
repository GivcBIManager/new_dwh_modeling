import json

import pytest

from clickhouse import ClickHouse, ClickHouseError, ForbiddenStatement
from stub_clickhouse import StubClickHouse

PASSWORD = "s3cret-pw"


@pytest.fixture
def stub():
    s = StubClickHouse()
    yield s
    s.close()


@pytest.fixture
def ch(stub):
    return ClickHouse(stub.url, "bi_user", PASSWORD)


def test_guard(stub, ch):
    for bad in ("UPDATE default.map_bsc_parameter SET value = 1", "SELECT 1; DROP TABLE x"):
        with pytest.raises(ForbiddenStatement):
            ch.select(bad)
    with pytest.raises(ForbiddenStatement):
        ch.insert("map_bsc_foo", [{"a": 1}])
    with pytest.raises(ForbiddenStatement):
        ch.insert("bsc_targets", [{"a": 1}])
    with pytest.raises(ForbiddenStatement):
        ch.insert("map_bsc_parameter FORMAT JSONEachRow\n{}\nINSERT INTO x", [{"a": 1}])
    assert stub.requests == []
    assert ch.select("  select 1") == [{"1": 1}]
    assert ch.select("SELECT 1;") == [{"1": 1}]


def test_auth_in_headers_only(stub, ch):
    ch.select("SELECT 1")
    ch.insert("map_bsc_parameter", [{"name": "a"}])
    assert len(stub.requests) == 2
    for r in stub.requests:
        assert r["headers"]["X-ClickHouse-User"] == "bi_user"
        assert r["headers"]["X-ClickHouse-Key"] == PASSWORD
        assert PASSWORD not in r["path"]
        assert PASSWORD not in r["text"]
    assert "output_format_json_quote_64bit_integers=0" in stub.requests[0]["path"]


def test_insert_body(stub, ch):
    row = {"name": "x", "value": "1"}
    assert ch.insert("map_bsc_parameter", [row]) == 1
    assert stub.requests[0]["text"] == (
        "INSERT INTO default.map_bsc_parameter FORMAT JSONEachRow\n" + json.dumps(row, ensure_ascii=False)
    )
    assert stub.tables["map_bsc_parameter"] == [row]


def test_utf8_round_trip(stub, ch):
    note = "تقرير مكافحة العدوى – سبتمبر"
    ch.insert("map_bsc_parameter", [{"name": "n", "change_note": note}])
    assert note.encode("utf-8") in stub.requests[0]["body"]
    rows = ch.select("SELECT * FROM default.map_bsc_parameter")
    assert rows[0]["change_note"] == note


def test_errors_scrub_the_password(stub):
    stub.reject_user("bi_user", echo_password=True)
    ch = ClickHouse(stub.url, "bi_user", PASSWORD)
    with pytest.raises(ClickHouseError) as e:
        ch.select("SELECT 1")
    assert "516" in str(e.value)
    assert PASSWORD not in str(e.value)


def test_unreachable_server_error_has_no_password():
    ch = ClickHouse("http://127.0.0.1:1/", "u", PASSWORD, timeout=2)
    with pytest.raises(ClickHouseError) as e:
        ch.select("SELECT 1")
    assert PASSWORD not in str(e.value)


def test_stub_controls(stub, ch):
    assert ch.server_now() == "2026-10-25 09:30:00.123"
    stub.set_now("2026-11-01 00:00:00.000")
    assert ch.server_now() == "2026-11-01 00:00:00.000"
    stub.branches = [{"branch_key": 1, "branch_name": "Riyadh"}]
    assert ch.select("SELECT branch_key, branch_name FROM gold.ssas_dim_branch") == stub.branches
    stub.fail_select("ssas_dim_branch")
    with pytest.raises(ClickHouseError):
        ch.select("SELECT branch_key, branch_name FROM gold.ssas_dim_branch")
    stub.fail_next_insert()
    with pytest.raises(ClickHouseError):
        ch.insert("map_bsc_parameter", [{"name": "a"}])
    assert ch.insert("map_bsc_parameter", [{"name": "a"}]) == 1
